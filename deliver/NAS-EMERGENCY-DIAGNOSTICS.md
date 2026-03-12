# NAS Emergency Diagnostics - Gemini Activity Check

**Date:** October 14, 2025
**NAS IP:** 169.254.1.2 (Thunderbolt)
**Issue:** Disk churning nonstop (suspected Gemini remnant)
**Access Method:** Physical console (ZKVM/KVM) until SSH working

---

## URGENT: Get SSH Working First

### At NAS Console (Physical Access):

```bash
# 1. Login as locnguyen or root

# 2. Start SSH server
sudo systemctl start sshd
sudo systemctl enable sshd

# 3. Configure SSH to listen on Thunderbolt interface
sudo nano /etc/ssh/sshd_config

# Add/uncomment:
ListenAddress 169.254.1.2
PermitRootLogin yes  # Temporary, for emergency access
PubkeyAuthentication yes

# Save and restart SSH
sudo systemctl restart sshd

# 4. Verify SSH is listening
sudo ss -tlnp | grep :22

# 5. Test from local
ssh localhost

# If that works, test from Mac Mini will work too
```

---

## Once SSH Working: Immediate Diagnostics

### From Mac Mini:

```bash
ssh -i ~/.ssh/nah root@169.254.1.2
```

### Commands to Run (Copy/Paste Block):

```bash
echo "=== DISK ACTIVITY CHECK ==="
echo "[1] Current I/O operations:"
iotop -o -n 3 -d 2 | head -30

echo ""
echo "[2] Top processes by disk I/O:"
ps aux --sort=-%mem | head -20

echo ""
echo "[3] Recently modified files (last 30 minutes):"
find /tank -type f -mmin -30 2>/dev/null | head -50

echo ""
echo "[4] Active network connections:"
netstat -tunap | grep ESTABLISHED

echo ""
echo "[5] Listening services:"
ss -tlnp

echo ""
echo "[6] Recently accessed files (potential exfiltration targets):"
find /tank/forensics -type f -amin -60 2>/dev/null | head -30

echo ""
echo "[7] Processes NOT from standard packages (potential malware):"
ps aux | grep -v '\[' | awk '{print $11}' | sort -u | while read proc; do
    if ! dpkg -S "$proc" 2>/dev/null; then
        echo "Unknown process: $proc"
    fi
done | head -20

echo ""
echo "[8] Check for search patterns (semantic crystals, research files):"
lsof | grep -iE "(semantic|crystal|research|mcp|claude)" | head -20

echo ""
echo "[9] Disk usage and ZFS status:"
zpool status tank
df -h /tank

echo ""
echo "[10] System load:"
uptime
