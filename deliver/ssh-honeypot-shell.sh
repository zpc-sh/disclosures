#!/bin/bash
# SSH Honeypot Shell - Logs Everything Attackers Do
# Replace user's shell with this to capture their actions

LOG_DIR="/var/log/ssh-honeypot"
SESSION_ID="$(date +%Y%m%d-%H%M%S)-$$"
LOG_FILE="$LOG_DIR/session-$SESSION_ID.log"
EVIDENCE_FILE="$LOG_DIR/evidence-$SESSION_ID.txt"

# Create log directory
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

# Log session start
{
    echo "=================================="
    echo "SSH HONEYPOT SESSION"
    echo "=================================="
    echo "Session ID: $SESSION_ID"
    echo "Date: $(date)"
    echo "User: $USER"
    echo "From: $SSH_CLIENT"
    echo "TTY: $SSH_TTY"
    echo "Connection: $SSH_CONNECTION"
    echo "=================================="
    echo ""
} | tee -a "$LOG_FILE" "$EVIDENCE_FILE"

# Function to log commands
log_cmd() {
    local cmd="$1"
    echo "[$(date +%H:%M:%S)] COMMAND: $cmd" | tee -a "$LOG_FILE"
}

# Function to log output
log_output() {
    while IFS= read -r line; do
        echo "[$(date +%H:%M:%S)] OUTPUT: $line" | tee -a "$LOG_FILE"
    done
}

# Send alert
send_alert() {
    local msg="$1"
    echo "$msg" >> "$LOG_DIR/ALERTS.txt"
    # macOS notification if on Mac
    osascript -e "display notification \"$msg\" with title \"SSH Honeypot Alert\"" 2>/dev/null || true
}

# Initial alert
send_alert "SSH login detected: $USER from $SSH_CLIENT"

# Fake shell banner (looks like real system)
cat << 'EOF'
Last login: Sun Oct 13 18:42:11 2025 from 192.168.1.100
[udm-pro-max ~]$
EOF

# Main honeypot loop
while true; do
    # Show fake prompt
    echo -n "[udm-pro-max ~]$ " | tee -a "$LOG_FILE"

    # Read attacker's command
    read -r CMD || break

    # Log it
    log_cmd "$CMD"

    # Parse command
    case "$CMD" in
        "")
            # Empty command
            continue
            ;;
        exit|logout|quit)
            echo "logout" | log_output
            echo "Connection to udm-pro-max closed." | log_output
            send_alert "Attacker logged out gracefully"
            break
            ;;
        whoami)
            echo "root" | log_output
            send_alert "Attacker checked user: whoami"
            ;;
        id)
            echo "uid=0(root) gid=0(root) groups=0(root)" | log_output
            send_alert "Attacker checked permissions: id"
            ;;
        pwd)
            echo "/root" | log_output
            ;;
        hostname)
            echo "udm-pro-max" | log_output
            ;;
        uname*|cat\ /etc/os-release)
            echo "Linux udm-pro-max 4.19.152-ui-alpine #1 SMP Thu Jul 28 03:00:00 UTC 2022 aarch64 GNU/Linux" | log_output
            send_alert "Attacker reconnaissance: $CMD"
            ;;
        ls*)
            # Fake directory listing
            echo "bin   dev   etc   home   lib   media   mnt   opt   proc   root   run   sbin   srv   sys   tmp   usr   var" | log_output
            ;;
        cat\ /etc/passwd|cat\ /etc/shadow)
            echo "cat: /etc/shadow: Permission denied" | log_output
            send_alert "Attacker tried to read: $CMD"
            ;;
        ps*|top)
            echo "PID   USER     TIME   COMMAND" | log_output
            echo "1     root     0:01   /sbin/init" | log_output
            echo "42    root     0:00   sshd" | log_output
            send_alert "Attacker checking processes: $CMD"
            ;;
        netstat*|ss*)
            echo "Active Internet connections" | log_output
            echo "Proto Recv-Q Send-Q Local Address           Foreign Address         State" | log_output
            echo "tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN" | log_output
            echo "tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN" | log_output
            send_alert "Attacker checking network: $CMD"
            ;;
        wget*|curl*|fetch*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "CRITICAL: Attacker attempting download: $CMD"
            ;;
        chmod*|chown*)
            echo "chmod: cannot access '$CMD': Operation not permitted" | log_output
            send_alert "Attacker trying privilege escalation: $CMD"
            ;;
        rm*|del*)
            echo "rm: cannot remove: Permission denied" | log_output
            send_alert "CRITICAL: Attacker attempting deletion: $CMD"
            ;;
        iptables*|firewall-cmd*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "CRITICAL: Attacker targeting firewall: $CMD"
            ;;
        systemctl*|service*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "Attacker trying service manipulation: $CMD"
            ;;
        find*|locate*)
            echo "find: Permission denied" | log_output
            send_alert "Attacker searching filesystem: $CMD"
            ;;
        crontab*|at*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "CRITICAL: Attacker attempting persistence via cron: $CMD"
            ;;
        vi*|vim*|nano*|emacs*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "Attacker trying to edit files: $CMD"
            ;;
        *password*|*passwd*)
            echo "-bash: $CMD: command not found" | log_output
            send_alert "CRITICAL: Attacker targeting passwords: $CMD"
            ;;
        *)
            # Generic response for unknown commands
            echo "-bash: $CMD: command not found" | log_output
            send_alert "Unknown attacker command: $CMD"
            ;;
    esac
done

# Session end logging
{
    echo ""
    echo "=================================="
    echo "SESSION ENDED"
    echo "Duration: $SECONDS seconds"
    echo "Date: $(date)"
    echo "=================================="
} | tee -a "$LOG_FILE" "$EVIDENCE_FILE"

send_alert "SSH session ended: $SESSION_ID"

# Exit with normal code
exit 0
