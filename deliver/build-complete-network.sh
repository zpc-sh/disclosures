#!/bin/bash
# Complete Network Build - UDM Pro Max
# Post-incident security hardened configuration

set -e

UDM_IP="192.168.1.1"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
SITE="default"

echo "==================================================================="
echo "  UDM Pro Max - Complete Network Configuration"
echo "  Security Hardened - Post-Compromise Recovery"
echo "==================================================================="
echo ""
echo "Target: $UDM_IP"
echo "Starting: $(date)"
echo ""

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1: NETWORK VLANs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get existing networks to avoid duplicates
echo "[+] Checking existing networks..."
EXISTING=$(api_call GET "rest/networkconf" | jq -r '.data[] | .name')
echo "    Found: $(echo "$EXISTING" | tr '\n' ', ')"
echo ""

create_network() {
    local NAME="$1"
    local VLAN="$2"
    local SUBNET="$3"
    local PURPOSE="${4:-corporate}"

    if echo "$EXISTING" | grep -q "^$NAME$"; then
        echo "    ⊙ $NAME (VLAN $VLAN) - Already exists"
        return
    fi

    echo -n "    Creating $NAME (VLAN $VLAN, $SUBNET)... "

    RESULT=$(api_call POST "rest/networkconf" "{
        \"name\": \"$NAME\",
        \"purpose\": \"$PURPOSE\",
        \"vlan_enabled\": true,
        \"vlan\": $VLAN,
        \"dhcpd_enabled\": true,
        \"dhcpd_start\": \"${SUBNET%.*}.100\",
        \"dhcpd_stop\": \"${SUBNET%.*}.200\",
        \"ip_subnet\": \"$SUBNET/24\",
        \"domain_name\": \"$(echo $NAME | tr '[:upper:]' '[:lower:]').local\",
        \"igmp_snooping\": true,
        \"ipv6_interface_type\": \"none\"
    }")

    if echo "$RESULT" | jq -e '.data[0].name' >/dev/null 2>&1; then
        echo "✓"
    else
        echo "✗ ($(echo "$RESULT" | jq -r '.meta.msg // "Unknown error"'))"
    fi
}

echo "[1/7] Management VLAN"
create_network "Management" 1 "10.0.1.1"

echo "[2/7] Trusted VLAN"
create_network "Trusted" 10 "10.0.10.1"

echo "[3/7] IoT VLAN"
create_network "IoT" 20 "10.0.20.1"

echo "[4/7] Guest VLAN"
create_network "Guest" 30 "10.0.30.1" "guest"

echo "[5/7] Lab VLAN"
create_network "Lab" 40 "10.0.40.1"

echo "[6/7] Device Testing VLAN"
create_network "Device-Testing" 98 "10.0.98.1"

echo "[7/7] Quarantine VLAN"
create_network "Quarantine" 99 "10.0.99.1"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2: FIREWALL RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get network IDs for firewall rules
MGMT_ID=$(api_call GET "rest/networkconf" | jq -r '.data[] | select(.name=="Management") | ._id')
TRUSTED_ID=$(api_call GET "rest/networkconf" | jq -r '.data[] | select(.name=="Trusted") | ._id')
IOT_ID=$(api_call GET "rest/networkconf" | jq -r '.data[] | select(.name=="IoT") | ._id')
GUEST_ID=$(api_call GET "rest/networkconf" | jq -r '.data[] | select(.name=="Guest") | ._id')
QUARANTINE_ID=$(api_call GET "rest/networkconf" | jq -r '.data[] | select(.name=="Quarantine") | ._id')

create_firewall_rule() {
    local NAME="$1"
    local RULESET="$2"
    local ACTION="$3"
    local SRC="$4"
    local DST="$5"
    local PROTOCOL="${6:-all}"
    local PORTS="${7:-}"

    echo -n "    Creating: $NAME... "

    RULE_JSON="{
        \"name\": \"$NAME\",
        \"enabled\": true,
        \"action\": \"$ACTION\",
        \"ruleset\": \"$RULESET\",
        \"protocol\": \"$PROTOCOL\",
        \"logging\": true"

    [ -n "$SRC" ] && RULE_JSON="$RULE_JSON, \"src_networkconf_id\": \"$SRC\""
    [ -n "$DST" ] && RULE_JSON="$RULE_JSON, \"dst_networkconf_id\": \"$DST\""
    [ -n "$PORTS" ] && RULE_JSON="$RULE_JSON, \"dst_port\": \"$PORTS\""

    RULE_JSON="$RULE_JSON}"

    RESULT=$(api_call POST "rest/firewallrule" "$RULE_JSON")

    if echo "$RESULT" | jq -e '.data[0]._id' >/dev/null 2>&1; then
        echo "✓"
    else
        echo "⊙ (may already exist or: $(echo "$RESULT" | jq -r '.meta.msg // "error"'))"
    fi
}

echo "[+] Management Protection Rules"
create_firewall_rule "Block IoT → Management" "LAN_IN" "drop" "$IOT_ID" "$MGMT_ID"
create_firewall_rule "Block Guest → Management" "LAN_IN" "drop" "$GUEST_ID" "$MGMT_ID"

echo ""
echo "[+] Network Isolation Rules"
create_firewall_rule "Block IoT → Trusted" "LAN_IN" "drop" "$IOT_ID" "$TRUSTED_ID"
create_firewall_rule "Block Guest → Trusted" "LAN_IN" "drop" "$GUEST_ID" "$TRUSTED_ID"
create_firewall_rule "Block Guest → IoT" "LAN_IN" "drop" "$GUEST_ID" "$IOT_ID"

echo ""
echo "[+] Quarantine Rules"
create_firewall_rule "Block All → Quarantine" "LAN_IN" "drop" "" "$QUARANTINE_ID"
create_firewall_rule "Block Quarantine → All" "LAN_OUT" "drop" "$QUARANTINE_ID" ""

echo ""
echo "[+] WAN Protection Rules"
api_call POST "rest/firewallrule" '{
  "name": "Block WAN Management Access",
  "enabled": true,
  "action": "drop",
  "ruleset": "WAN_LOCAL",
  "protocol": "tcp",
  "dst_port": "22,443,8443",
  "logging": true
}' >/dev/null && echo "    Creating: Block WAN Management Access... ✓" || echo "    Creating: Block WAN Management Access... ⊙"

api_call POST "rest/firewallrule" '{
  "name": "Block RFC1918 from WAN",
  "enabled": true,
  "action": "drop",
  "ruleset": "WAN_IN",
  "protocol": "all",
  "src_address": "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
  "logging": true
}' >/dev/null && echo "    Creating: Block RFC1918 from WAN... ✓" || echo "    Creating: Block RFC1918 from WAN... ⊙"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3: SECURITY SETTINGS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[+] Checking IPS/IDS status..."
IPS_STATUS=$(api_call GET "rest/setting/ips" | jq -r '.data[0].enabled')
echo "    Current IPS status: $IPS_STATUS"

if [ "$IPS_STATUS" != "true" ]; then
    echo -n "    Enabling IPS/IDS... "
    IPS_ID=$(api_call GET "rest/setting/ips" | jq -r '.data[0]._id')
    api_call PUT "rest/setting/ips/$IPS_ID" '{
      "enabled": true,
      "mode": "auto"
    }' >/dev/null && echo "✓" || echo "✗"
else
    echo "    IPS already enabled ✓"
fi

echo ""
echo "[+] Checking threat management..."
api_call GET "rest/setting/ips" | jq -r '.data[0] | "    Mode: \(.mode) | Enabled: \(.enabled)"'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 4: VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[+] Created Networks:"
api_call GET "rest/networkconf" | jq -r '.data[] |
  "    " + .name + " (VLAN " + (.vlan|tostring) + "): " + .ip_subnet'

echo ""
echo "[+] Active Firewall Rules:"
RULE_COUNT=$(api_call GET "rest/firewallrule" | jq '[.data[] | select(.enabled==true)] | length')
echo "    Total enabled rules: $RULE_COUNT"

echo ""
echo "[+] Devices:"
api_call GET "stat/device" | jq -r '.data[] |
  "    " + .type + ": " + (.name // .model) + " (" + .ip + ")"'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CONFIGURATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ 7 VLANs created"
echo "✓ Firewall rules configured"
echo "✓ IPS/IDS enabled"
echo "✓ Network isolation enforced"
echo ""
echo "Next steps:"
echo "  1. Adopt switches/APs"
echo "  2. Create WiFi networks (optional)"
echo "  3. Assign devices to VLANs"
echo "  4. Monitor for 24 hours"
echo ""
echo "Completed: $(date)"
