#!/bin/bash

# Monitor iCloud Drive for suspicious access patterns
# Log everything that touches iCloud-related files

EVIDENCE_DIR="$HOME/workwork/evidence/icloud-attacks"
mkdir -p "$EVIDENCE_DIR"

LOG_FILE="$EVIDENCE_DIR/access-log-$(date +%Y%m%d-%H%M%S).txt"

echo "🔍 Starting iCloud attacker monitor..."
echo "   Evidence: $LOG_FILE"
echo ""

# Monitor bird process
echo "=== iCloud Attack Monitor Started at $(date) ===" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 1. Check for network connections from bird
    BIRD_PID=$(pgrep -x bird)
    if [ -n "$BIRD_PID" ]; then
        # Log active connections
        CONNECTIONS=$(lsof -i -n -P -p "$BIRD_PID" 2>/dev/null | grep ESTABLISHED)
        if [ -n "$CONNECTIONS" ]; then
            echo "[$TIMESTAMP] BIRD CONNECTIONS:" >> "$LOG_FILE"
            echo "$CONNECTIONS" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
            
            # Extract IP addresses
            IPS=$(echo "$CONNECTIONS" | awk '{print $9}' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)
            if [ -n "$IPS" ]; then
                echo "[$TIMESTAMP] CONNECTED IPs:" >> "$LOG_FILE"
                echo "$IPS" | while read ip; do
                    echo "  $ip" >> "$LOG_FILE"
                    # Log to console for real-time monitoring
                    echo "  🌐 Connection: $ip"
                done
                echo "" >> "$LOG_FILE"
            fi
        fi
        
        # 2. Monitor files being accessed by bird
        FILES=$(lsof -p "$BIRD_PID" 2>/dev/null | grep -E "CloudDocs|iCloud|Mobile Documents" | head -20)
        if [ -n "$FILES" ]; then
            echo "[$TIMESTAMP] FILES ACCESSED:" >> "$LOG_FILE"
            echo "$FILES" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        fi
        
        # 3. Check for debugger attachment
        if lsof -p "$BIRD_PID" 2>/dev/null | grep -iE "debug|lldb" > /dev/null; then
            echo "[$TIMESTAMP] ⚠️  DEBUGGER DETECTED ON BIRD!" >> "$LOG_FILE"
            echo "  🚨 DEBUGGER DETECTED ON BIRD (PID $BIRD_PID)!"
            
            # Log what process is debugging
            DEBUGGER=$(lsof -p "$BIRD_PID" 2>/dev/null | grep -iE "debug|lldb")
            echo "$DEBUGGER" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        fi
        
        # 4. Check bird process state
        STATE=$(ps -o state= -p "$BIRD_PID" 2>/dev/null | tr -d ' ')
        if [ "$STATE" = "T" ]; then
            echo "[$TIMESTAMP] ⚠️  BIRD STOPPED (breakpoint?)" >> "$LOG_FILE"
            echo "  🚨 BIRD IS STOPPED (BREAKPOINT?)"
        fi
    else
        echo "[$TIMESTAMP] Bird not running" >> "$LOG_FILE"
    fi
    
    # 5. Check for suspicious CloudDocs changes
    if [ -d "$HOME/Library/Application Support/CloudDocs" ]; then
        # Look for recently modified files
        RECENT=$(find "$HOME/Library/Application Support/CloudDocs" -type f -mmin -1 2>/dev/null | head -10)
        if [ -n "$RECENT" ]; then
            echo "[$TIMESTAMP] RECENT CLOUDDOCS CHANGES:" >> "$LOG_FILE"
            echo "$RECENT" | while read file; do
                SIZE=$(stat -f%z "$file" 2>/dev/null)
                echo "  $(basename "$file") ($SIZE bytes)" >> "$LOG_FILE"
            done
            echo "" >> "$LOG_FILE"
        fi
    fi
    
    sleep 5
done
