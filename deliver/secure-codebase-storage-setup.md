# Secure Codebase Storage on ZFS/Samba
**Context**: Mac low on space, need remote storage with security isolation

## Threat Model
- Old UDM Pro completely compromised (UI redressed = kernel-level)
- Attackers may try to compromise new UDM Pro Max
- Cannot trust old devices on network
- Need secure storage for codebases that won't get infected

---

## Architecture

```
Mac (10.0.10.x)
  ↓ [Authenticated, Encrypted SMB3]
NAS (10.0.1.50 Management + 10.0.10.50 Data)
  ↓ [ZFS with snapshots]
Local ZFS Pool → Encrypted Dataset → Samba Share
                      ↓
                [Hourly Snapshots]
                [Daily Replication to Backup Pool]
```

---

## ZFS Dataset Strategy

### Create Isolated Datasets for Different Trust Levels

```bash
# SSH to your NAS
ssh admin@10.0.1.50

# Create main codebase pool structure
sudo zfs create tank/codebases
sudo zfs create tank/codebases/trusted      # Clean, verified code
sudo zfs create tank/codebases/work         # Active development
sudo zfs create tank/codebases/quarantine   # Code from compromised systems

# Enable compression (helps with text files)
sudo zfs set compression=lz4 tank/codebases

# Enable deduplication (lots of similar code)
# WARNING: Only if you have >32GB RAM on NAS
# sudo zfs set dedup=on tank/codebases

# Set quotas to prevent runaway usage
sudo zfs set quota=500G tank/codebases/trusted
sudo zfs set quota=1T tank/codebases/work
sudo zfs set quota=100G tank/codebases/quarantine

# Enable snapshot automation
sudo zfs set com.sun:auto-snapshot=true tank/codebases/trusted
sudo zfs set com.sun:auto-snapshot=true tank/codebases/work
# Don't auto-snapshot quarantine (waste of space for infected code)
sudo zfs set com.sun:auto-snapshot=false tank/codebases/quarantine
```

### Optional: Encryption for Sensitive Code

```bash
# If your code is sensitive, encrypt it
# WARNING: If you lose the key, data is GONE forever

# Create encrypted dataset
sudo zfs create -o encryption=on -o keyformat=passphrase tank/codebases/secrets

# Or use key file (better for automation)
echo "your-very-long-random-key" > /root/.zfs-key
chmod 600 /root/.zfs-key
sudo zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///root/.zfs-key tank/codebases/secrets
```

---

## Snapshot Strategy

### Automated Snapshots

```bash
# Install zfs-auto-snapshot if not already
# Ubuntu/Debian:
sudo apt install zfs-auto-snapshot

# Or manually with cron
cat > /usr/local/bin/zfs-snapshot-codebases.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
zfs snapshot tank/codebases/trusted@auto-${DATE}
zfs snapshot tank/codebases/work@auto-${DATE}

# Keep only last 24 hourly, 7 daily, 4 weekly
# Clean up old snapshots older than 30 days
zfs list -H -t snapshot -o name | grep "tank/codebases.*@auto-" | \
  sort | head -n -168 | xargs -n 1 zfs destroy
EOF

chmod +x /usr/local/bin/zfs-snapshot-codebases.sh

# Run every hour
echo "0 * * * * /usr/local/bin/zfs-snapshot-codebases.sh" | sudo crontab -
```

### Manual Snapshot Before Risky Operations

```bash
# Before pulling code from potentially compromised source
sudo zfs snapshot tank/codebases/work@before-pull-$(date +%Y%m%d-%H%M%S)

# If something bad happens, rollback
sudo zfs rollback tank/codebases/work@before-pull-20251013-123456
```

---

## Samba Configuration (Secure)

### Install and Configure Samba

```bash
# On NAS
sudo apt update
sudo apt install samba samba-vfs-modules

# Backup original config
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

### Secure smb.conf Configuration

```bash
sudo nano /etc/samba/smb.conf
```

```ini
[global]
   workgroup = WORKGROUP
   server string = Secure Code Storage

   # Security settings
   security = user
   encrypt passwords = yes

   # SMB3 only (encrypted by default)
   server min protocol = SMB3_00
   client min protocol = SMB3_00

   # Disable SMB1 (WannaCry vector)
   server max protocol = SMB3_11

   # Enable encryption
   smb encrypt = required

   # Restrict to specific interfaces (management + trusted VLAN)
   interfaces = 10.0.1.50/24 10.0.10.50/24
   bind interfaces only = yes

   # Only allow specific hosts (your Mac)
   hosts allow = 10.0.10.0/24 10.0.1.0/24 127.0.0.1
   hosts deny = ALL

   # Logging for security
   log file = /var/log/samba/log.%m
   max log size = 5000
   log level = 2

   # Performance tuning
   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes

   # Disable printers (not needed for code storage)
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

[codebases-trusted]
   comment = Clean Verified Code
   path = /tank/codebases/trusted
   browseable = yes
   writable = yes
   valid users = @coders
   force user = coder
   force group = coders
   create mask = 0644
   directory mask = 0755
   # Prevent execution
   veto files = /*.exe/*.dll/*.bat/*.cmd/*.vbs/*.ps1/
   delete veto files = no
   # Enable shadow copies (access snapshots)
   vfs objects = shadow_copy2
   shadow:format = auto-%Y%m%d-%H%M%S
   shadow:sort = desc
   shadow:snapdir = .zfs/snapshot
   shadow:basedir = /tank/codebases/trusted

[codebases-work]
   comment = Active Development Code
   path = /tank/codebases/work
   browseable = yes
   writable = yes
   valid users = @coders
   force user = coder
   force group = coders
   create mask = 0644
   directory mask = 0755
   veto files = /*.exe/*.dll/*.bat/*.cmd/*.vbs/*.ps1/
   delete veto files = no
   vfs objects = shadow_copy2 recycle
   shadow:format = auto-%Y%m%d-%H%M%S
   shadow:sort = desc
   shadow:basedir = /tank/codebases/work
   # Recycle bin (prevent accidental deletes)
   recycle:repository = .recycle
   recycle:keeptree = yes
   recycle:versions = yes

[codebases-quarantine]
   comment = Code from Compromised Systems (READ-ONLY)
   path = /tank/codebases/quarantine
   browseable = yes
   writable = no
   read only = yes
   valid users = @coders
   # Extra paranoid - no execution, no writing
   veto files = /*.exe/*.dll/*.bat/*.cmd/*.vbs/*.ps1/*.sh/*.py/*.js/*.bin/
```

### Create Users and Permissions

```bash
# Create dedicated user for code access
sudo groupadd coders
sudo useradd -m -g coders -s /bin/bash coder

# Set Samba password (different from system password)
sudo smbpasswd -a coder
# Enter a STRONG password - save in password manager

# Set filesystem permissions
sudo chown -R coder:coders /tank/codebases/trusted
sudo chown -R coder:coders /tank/codebases/work
sudo chown -R coder:coders /tank/codebases/quarantine
sudo chmod -R 755 /tank/codebases

# Restart Samba
sudo systemctl restart smbd
sudo systemctl enable smbd
```

### Test Samba Configuration

```bash
# Check for syntax errors
testparm

# Check what shares are available
smbclient -L localhost -U coder
```

---

## Mac Client Setup (Secure Mount)

### Option 1: Manual Mount (Recommended for Testing)

```bash
# Create mount point
mkdir -p ~/Code/trusted
mkdir -p ~/Code/work
mkdir -p ~/Code/quarantine

# Mount trusted codebase
mount_smbfs //coder@10.0.10.50/codebases-trusted ~/Code/trusted

# Mount work codebase
mount_smbfs //coder@10.0.10.50/codebases-work ~/Code/work

# Mount quarantine (read-only)
mount_smbfs //coder@10.0.10.50/codebases-quarantine ~/Code/quarantine
```

### Option 2: Automatic Mount via /etc/fstab (Persistent)

**Don't use fstab on Mac, use autofs instead:**

```bash
sudo nano /etc/auto_master
```

Add line:
```
/- auto_smb -nosuid,noowners,nodev
```

Create auto_smb:
```bash
sudo nano /etc/auto_smb
```

```
/Users/locnguyen/Code/trusted -fstype=smbfs,soft ://coder:password@10.0.10.50/codebases-trusted
/Users/locnguyen/Code/work -fstype=smbfs,soft ://coder:password@10.0.10.50/codebases-work
/Users/locnguyen/Code/quarantine -fstype=smbfs,soft,ro ://coder:password@10.0.10.50/codebases-quarantine
```

**WARNING**: Storing password in plaintext is risky. Better option below.

### Option 3: Keychain-Backed Mount (Most Secure)

```bash
# Store password in keychain
security add-generic-password -a coder -s nas-codebases -w

# Create mount script
cat > ~/mount-codebases.sh << 'EOF'
#!/bin/bash

# Get password from keychain
PASSWORD=$(security find-generic-password -a coder -s nas-codebases -w)

# Create mount points
mkdir -p ~/Code/trusted
mkdir -p ~/Code/work
mkdir -p ~/Code/quarantine

# Mount shares
echo "$PASSWORD" | mount_smbfs //coder@10.0.10.50/codebases-trusted ~/Code/trusted
echo "$PASSWORD" | mount_smbfs //coder@10.0.10.50/codebases-work ~/Code/work
echo "$PASSWORD" | mount_smbfs //coder@10.0.10.50/codebases-quarantine ~/Code/quarantine

echo "Code shares mounted:"
df -h | grep codebases
EOF

chmod +x ~/mount-codebases.sh

# Run on login
# System Settings → Users & Groups → Login Items → Add ~/mount-codebases.sh
```

---

## Git Configuration for Remote Storage

### Option 1: Git Repos Directly on SMB (Simple)

```bash
# Mount work share
~/mount-codebases.sh

# Clone/create repos directly on share
cd ~/Code/work
git clone https://github.com/yourusername/repo.git
cd repo
# Work normally

# Git will work but may be slower over SMB
# Recommend: Use sparse-checkout for large repos
```

### Option 2: Local Git with Remote Backup (Faster)

```bash
# Work locally for speed
cd ~/Projects/myrepo
git init

# Push to NAS for backup
cd ~/Code/work
git clone --bare ~/Projects/myrepo myrepo.git

# Configure local to push to NAS
cd ~/Projects/myrepo
git remote add nas ~/Code/work/myrepo.git

# After commits, push to NAS
git push nas main
```

### Option 3: Hybrid - Local Cache with NAS Master (Best)

```bash
# Create bare repo on NAS (source of truth)
cd ~/Code/work
git init --bare myproject.git

# Clone locally for speed
cd ~/Projects
git clone ~/Code/work/myproject.git

# Work locally
cd ~/Projects/myproject
# ... code code code ...
git add .
git commit -m "changes"

# Push to NAS (backed by ZFS snapshots)
git push origin main

# Benefit: Local speed + NAS backup + ZFS snapshots
```

---

## Performance Optimization

### Tune Mac SMB Client

```bash
# Increase SMB signing performance
sudo sysctl -w net.smb.client.signing_required=0  # WARNING: Less secure
# Only use if on trusted network behind firewall

# Increase buffer sizes
sudo sysctl -w net.inet.tcp.sendspace=262144
sudo sysctl -w net.inet.tcp.recvspace=262144
```

### Tune NAS Samba Performance

```bash
# On NAS, edit /etc/samba/smb.conf
sudo nano /etc/samba/smb.conf
```

Add to `[global]`:
```ini
# Performance tuning
socket options = TCP_NODELAY SO_RCVBUF=262144 SO_SNDBUF=262144
use sendfile = yes
min receivefile size = 16384
aio read size = 16384
aio write size = 16384

# Caching
strict allocate = yes
allocation roundup size = 4096
```

Restart:
```bash
sudo systemctl restart smbd
```

---

## Accessing ZFS Snapshots from Mac

### Via Samba Shadow Copies

```bash
# In Finder, right-click a file → "Restore Previous Versions"
# Or via Terminal:

cd ~/Code/work/myproject

# List available snapshots
ls .zfs/snapshot/

# Access file from snapshot
cat .zfs/snapshot/auto-20251013-120000/file.py

# Restore file from snapshot
cp .zfs/snapshot/auto-20251013-120000/file.py file.py
```

### Via Command Line (SSH to NAS)

```bash
# SSH to NAS
ssh admin@10.0.1.50

# List snapshots
zfs list -t snapshot | grep codebases

# Mount snapshot temporarily
mkdir /mnt/snapshot-temp
mount -t zfs tank/codebases/work@auto-20251013-120000 /mnt/snapshot-temp

# Copy files out
cp -a /mnt/snapshot-temp/myproject ~/restored/

# Unmount
umount /mnt/snapshot-temp
```

---

## Monitoring & Alerts

### Monitor for Suspicious Activity

```bash
# On NAS, check Samba logs
tail -f /var/log/samba/log.coder

# Look for:
# - Failed authentication attempts
# - Access from unexpected IPs
# - Mass file deletions
# - Unusual file patterns (.encrypted, ransom notes, etc.)
```

### Alert on Ransomware Patterns

```bash
# Create monitoring script on NAS
cat > /usr/local/bin/monitor-codebases.sh << 'EOF'
#!/bin/bash

# Check for ransomware indicators
find /tank/codebases -type f \( -name "*.encrypted" -o -name "*.locked" -o -name "*DECRYPT*" -o -name "*RANSOM*" \) -mmin -5 | while read file; do
  echo "WARNING: Potential ransomware activity detected: $file"
  logger -t codebase-monitor "ALERT: Suspicious file detected: $file"
  # Send notification (configure your method)
  # curl -X POST https://your-alerting-system/alert ...
done

# Check for mass deletions (>100 files in 5 min)
DELETIONS=$(find /tank/codebases -type f -name ".recycle*" -mmin -5 | wc -l)
if [ $DELETIONS -gt 100 ]; then
  echo "WARNING: Mass deletion detected: $DELETIONS files"
  logger -t codebase-monitor "ALERT: Mass deletion: $DELETIONS files"
fi
EOF

chmod +x /usr/local/bin/monitor-codebases.sh

# Run every 5 minutes
echo "*/5 * * * * /usr/local/bin/monitor-codebases.sh" | sudo crontab -
```

---

## Disaster Recovery

### Scenario 1: Ransomware Hits Your Codebase

```bash
# If files get encrypted, immediately:

# 1. Disconnect Mac from share
umount ~/Code/work

# 2. SSH to NAS
ssh admin@10.0.1.50

# 3. List snapshots (find one before infection)
zfs list -t snapshot | grep codebases/work

# 4. Rollback to clean snapshot
sudo zfs rollback tank/codebases/work@auto-20251013-120000

# 5. Verify files are restored
ls /tank/codebases/work

# 6. Remount on Mac
~/mount-codebases.sh
```

### Scenario 2: Entire NAS Compromised

```bash
# If you have replication to backup pool/system:

# On backup system:
zfs list -t snapshot | grep backup/codebases

# Restore from backup
zfs send backup/codebases/work@latest | ssh admin@10.0.1.50 "zfs receive tank/codebases/work"
```

### Scenario 3: Need to Restore Single File

```bash
# Access snapshot without rollback
cd ~/Code/work
ls .zfs/snapshot/
cp .zfs/snapshot/auto-20251013-120000/path/to/file.py ./file.py
```

---

## Security Hardening Checklist

- [ ] NAS on isolated Management VLAN (10.0.1.x)
- [ ] Firewall rules blocking IoT/Guest from NAS
- [ ] SMB3 encryption required
- [ ] Strong Samba password in Mac Keychain
- [ ] ZFS snapshots enabled (hourly)
- [ ] ZFS compression enabled
- [ ] Samba restricted to trusted networks only
- [ ] Samba logging enabled
- [ ] Monitoring script for ransomware patterns
- [ ] Test restore from snapshot monthly
- [ ] Backup NAS to external system/cloud
- [ ] No SMB1/SMB2 (WannaCry protection)
- [ ] .exe/.dll files blocked by Samba
- [ ] Quarantine share is read-only
- [ ] Shadow copies enabled for Previous Versions

---

## Quick Reference Commands

### Mac Side
```bash
# Mount all shares
~/mount-codebases.sh

# Unmount all
umount ~/Code/trusted ~/Code/work ~/Code/quarantine

# Check what's mounted
df -h | grep codebases

# Test connection
smbutil statshares -a //coder@10.0.10.50/codebases-work
```

### NAS Side
```bash
# Check Samba status
sudo systemctl status smbd

# List active connections
sudo smbstatus

# List snapshots
zfs list -t snapshot | grep codebases

# Create manual snapshot
sudo zfs snapshot tank/codebases/work@manual-$(date +%Y%m%d-%H%M%S)

# Check disk usage
zfs list -o space tank/codebases

# Rollback to snapshot
sudo zfs rollback tank/codebases/work@snapshot-name
```

---

## Integration with Your Forensics Work

Since you're doing incident response, here's how to use this for evidence:

### Store Evidence Separately
```bash
# Create forensics dataset
sudo zfs create tank/forensics
sudo zfs set readonly=on tank/forensics/evidence
sudo zfs set compression=gzip-9 tank/forensics/evidence  # Max compression
```

### Hash and Timestamp Evidence
```bash
# Before storing evidence
cd /tank/forensics/evidence
sha256sum evidence.dmg > evidence.dmg.sha256
sudo zfs snapshot tank/forensics/evidence@$(date +%Y%m%d-%H%M%S)
```

### Chain of Custody via ZFS Properties
```bash
sudo zfs set forensics:case="incident-20251013" tank/forensics/evidence@snapshot
sudo zfs set forensics:investigator="Loc Nguyen" tank/forensics/evidence@snapshot
sudo zfs get -t snapshot forensics:case,forensics:investigator tank/forensics/evidence
```

---

**You now have a secure, snapshot-protected, encrypted-in-transit codebase storage system that's isolated from potentially compromised devices.**

**Last Updated**: 2025-10-13
**Related Docs**:
- `~/workwork/udm-manual-config-guide.md` - Network isolation
- `~/workwork/device-adoption-security-protocol.md` - Safe device adoption
