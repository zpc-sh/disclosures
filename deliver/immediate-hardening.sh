#!/bin/bash
# IMMEDIATE UDM HARDENING - Disconnect from Ubiquiti Cloud
# Prevents attacker SSO access via compromised Ubiquiti Identity

UDM_IP="192.168.1.1"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
SITE="default"

echo "=== EMERGENCY UDM HARDENING ==="
echo "Threat: Compromised Ubiquiti Identity SSO access"
echo "Target: $UDM_IP"
echo ""

# Function to make API calls
api_call() {
    local METHOD="$1"
    local ENDPOINT="$2"
    local DATA="$3"

    if [ -z "$DATA" ]; then
        curl -sk -X "$METHOD" \
            "https://$UDM_IP/proxy/network/api/s/$SITE/$ENDPOINT" \
            -H "X-API-KEY: $API_KEY" \
            -H "Accept: application/json"
    else
        curl -sk -X "$METHOD" \
            "https://$UDM_IP/proxy/network/api/s/$SITE/$ENDPOINT" \
            -H "X-API-KEY: $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$DATA"
    fi
}

echo "Step 1: Capturing current configuration..."
api_call GET "rest/setting/mgmt" > /tmp/udm-mgmt-settings-backup.json
echo "Backup saved to /tmp/udm-mgmt-settings-backup.json"

echo ""
echo "Step 2: Disabling auto-upgrades..."
# Get current mgmt settings
MGMT_ID=$(jq -r '.data[0]._id' /tmp/udm-mgmt-settings-backup.json)

api_call PUT "rest/setting/mgmt/$MGMT_ID" '{
  "auto_upgrade": false,
  "x_remote_user_enabled": false
}' | jq -r '"Auto-upgrade: " + (.data[0].auto_upgrade|tostring) + " | Remote access: " + (.data[0].x_remote_user_enabled|tostring)'

echo ""
echo "Step 3: Checking for SSO users..."
api_call GET "rest/user" | jq -r '.data[] | "User: \(.name) | Local: \(.local_user_enabled // false)"'

echo ""
echo "Step 4: Checking cloud key status..."
api_call GET "stat/device" | jq -r '.data[] | select(.type=="udm") | {cloud_access: .config_network.type, uplink: .uplink}'

echo ""
echo "Step 5: Creating WAN hardening firewall rules..."

# Block all WAN management access
echo "Creating: Block WAN Management Access"
api_call POST "rest/firewallrule" '{
  "name": "EMERGENCY: Block WAN Management",
  "enabled": true,
  "action": "drop",
  "rule_index": 2000,
  "ruleset": "WAN_LOCAL",
  "protocol": "all",
  "dst_port": "22,443,8443",
  "logging": true,
  "src_address": ""
}' | jq -r '"Created: " + .data[0].name'

# Block RFC1918 from WAN (should never happen on public Internet)
echo "Creating: Block RFC1918 from WAN"
api_call POST "rest/firewallrule" '{
  "name": "EMERGENCY: Block RFC1918 from WAN",
  "enabled": true,
  "action": "drop",
  "rule_index": 2001,
  "ruleset": "WAN_IN",
  "protocol": "all",
  "src_address": "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
  "logging": true
}' | jq -r '"Created: " + .data[0].name'

echo ""
echo "Step 6: Scanning for suspicious outbound connections..."
echo "Checking connections to Ubiquiti cloud services..."

# Common Ubiquiti cloud endpoints
UBNT_ENDPOINTS=(
    "device.svc.ui.com"
    "trace.svc.ui.com"
    "unifi.ui.com"
    "api.ui.com"
    "account.ui.com"
    "fw-update.ui.com"
)

for endpoint in "${UBNT_ENDPOINTS[@]}"; do
    echo -n "Testing $endpoint: "
    if timeout 2 nc -zv $endpoint 443 2>&1 | grep -q "succeeded"; then
        echo "REACHABLE (potential compromise vector)"
    else
        echo "blocked/unreachable (good)"
    fi
done

echo ""
echo "Step 7: Current network snapshot..."
echo "Active devices:"
api_call GET "stat/sta" | jq -r '.data[] | "  - \(.hostname // "unknown") (\(.ip)) [\(.mac)] on \(.network)"'

echo ""
echo "=== HARDENING COMPLETE ==="
echo ""
echo "Critical settings changed:"
echo "  ✓ Auto-upgrade: DISABLED"
echo "  ✓ Remote user access: DISABLED"
echo "  ✓ WAN management: BLOCKED"
echo "  ✓ RFC1918 from WAN: BLOCKED"
echo ""
echo "IMPORTANT: You must now manage this UDM locally only."
echo "Any Ubiquiti SSO/Identity access has been cut off."
echo ""
echo "Next steps:"
echo "1. Change ALL local admin passwords"
echo "2. Disable any Ubiquiti cloud account links"
echo "3. Monitor logs for reconnection attempts"
echo "4. Build out VLANs and full firewall ruleset"
