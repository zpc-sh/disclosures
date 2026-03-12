#!/bin/bash
# Simple attack monitor - checks every 10 seconds
UDM_IP="192.168.1.1"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
EVIDENCE_DIR="$HOME/workwork/attack-evidence-baseline-20251013-220555"

cd "$EVIDENCE_DIR" || exit 1

echo "=== Attack Monitor Started ==="
echo "Evidence: $EVIDENCE_DIR"
echo "Watching for: new users, config changes, auth events"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    TS=$(date +"%Y-%m-%d %H:%M:%S")

    # Check for new users
    NEW_USERS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/user" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    USER_COUNT=$(echo "$NEW_USERS" | jq '.data | length')
    BASELINE_COUNT=$(jq '.data | length' baseline-users.json)

    if [ "$USER_COUNT" != "$BASELINE_COUNT" ]; then
        echo "$TS | !!! NEW USER DETECTED !!! Count: $BASELINE_COUNT -> $USER_COUNT"
        echo "$TS | NEW USER ALERT" >> ATTACK-DETECTED.txt
        echo "$NEW_USERS" | jq '.' > "attack-users-$TS.json"
        osascript -e 'display notification "New user created on UDM!" with title "ATTACK DETECTED"' 2>/dev/null
    fi

    # Check auto_upgrade status
    CONFIG=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/rest/setting/mgmt" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    AUTO_UPGRADE=$(echo "$CONFIG" | jq -r '.data[0].auto_upgrade')
    BASELINE_UPGRADE=$(jq -r '.data[0].auto_upgrade' baseline-config.json)

    if [ "$AUTO_UPGRADE" != "$BASELINE_UPGRADE" ]; then
        echo "$TS | !!! CONFIG CHANGED !!! auto_upgrade: $BASELINE_UPGRADE -> $AUTO_UPGRADE"
        echo "$TS | CONFIG CHANGE" >> ATTACK-DETECTED.txt
        echo "$CONFIG" | jq '.' > "attack-config-$TS.json"
        osascript -e 'display notification "UDM config changed!" with title "ATTACK DETECTED"' 2>/dev/null
    fi

    # Check for auth events
    EVENTS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/event?_limit=5" \
        -H "X-API-KEY: $API_KEY" 2>/dev/null)

    if echo "$EVENTS" | jq -r '.data[] | .key' | grep -q "EVT_AD_Login"; then
        echo "$TS | !!! LOGIN EVENT DETECTED !!!"
        echo "$TS | LOGIN EVENT" >> ATTACK-DETECTED.txt
        echo "$EVENTS" | jq '.' > "attack-event-$TS.json"
    fi

    # Simple status
    echo -n "."

    sleep 10
done
