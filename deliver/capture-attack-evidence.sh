#!/bin/bash
# Real-time Attack Monitoring and Evidence Collection
# Captures Ubiquiti Identity SSO compromise in action

UDM_IP="192.168.1.1"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
EVIDENCE_DIR="$HOME/workwork/attack-evidence-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$EVIDENCE_DIR"
cd "$EVIDENCE_DIR"

echo "=== ATTACK EVIDENCE COLLECTION ==="
echo "Evidence directory: $EVIDENCE_DIR"
echo "Monitoring UDM: $UDM_IP"
echo "Timestamp: $(date)"
echo ""

# Start packet capture on UDM management interface
echo "[+] Starting packet capture..."
sudo tcpdump -i any host $UDM_IP -w udm-traffic.pcap -v &
TCPDUMP_PID=$!
echo "    tcpdump PID: $TCPDUMP_PID"

# Monitor UDM logs in real-time
echo "[+] Starting log monitoring..."
while true; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Check for new user sessions
    SESSIONS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/session" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    echo "$TIMESTAMP | SESSIONS" >> session-log.txt
    echo "$SESSIONS" | jq '.' >> session-log.txt

    # Check for authentication events
    AUTH=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/event?_limit=10" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    if echo "$AUTH" | jq -r '.data[] | select(.key=="EVT_AD_Login" or .key=="EVT_AD_User_Added")' | grep -q "key"; then
        echo "$TIMESTAMP | !!! AUTH EVENT DETECTED !!!" | tee -a auth-events.txt
        echo "$AUTH" | jq '.' >> auth-events.txt

        # Alert
        osascript -e 'display notification "SSO Login Detected!" with title "Attack in Progress"'
    fi

    # Check for config changes
    curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/setting/mgmt" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null | \
        jq '{timestamp: "'$TIMESTAMP'", config: .data[0]}' >> config-snapshots.jsonl

    # Check for new users
    USERS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/user" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    echo "$TIMESTAMP | USERS" >> user-log.txt
    echo "$USERS" | jq '.' >> user-log.txt

    # Check for new firewall rules
    RULES=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/firewallrule" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    echo "$TIMESTAMP | FIREWALL_RULES" >> firewall-log.txt
    echo "$RULES" | jq '.data | length' >> firewall-log.txt

    # Check for port forwards
    FORWARDS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/portforward" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    if echo "$FORWARDS" | jq -r '.data[]' | grep -q "enabled"; then
        echo "$TIMESTAMP | !!! PORT FORWARD DETECTED !!!" | tee -a port-forward-alerts.txt
        echo "$FORWARDS" | jq '.' >> port-forward-alerts.txt

        osascript -e 'display notification "Port Forward Created!" with title "Attack Action"'
    fi

    # Monitor connections from upstream network
    netstat -an | grep "192.168.12" | grep "$UDM_IP" >> netstat-upstream.txt

    # Check for suspicious API calls
    lsof -i :443 | grep "$UDM_IP" >> api-connections.txt

    sleep 5
done
