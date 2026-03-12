# Permanent Thunderbolt Setup: Mac Mini ↔ NAS
## Direct High-Speed Connection to ZFS tank/*

**Purpose:** Keep Mac Mini permanently attached to NAS via Thunderbolt
**Benefit:** Work directly from tank/* - no local storage needed
**Speed:** 20-40 Gbps sustained

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Mac Mini (Infected)                                        │
│  IP: 169.254.1.1                                            │
│  Mount: /Volumes/tank → NFS → 169.254.1.2:/tank            │
└─────────────────────────────────────────────────────────────┘
                            │
                    Thunderbolt Cable
                            │
┌─────────────────────────────────────────────────────────────┐
│  NAS Server                                                 │
│  IP: 169.254.1.2                                            │
│  Export: /tank via NFS                                      │
│  Storage: ZFS tank/* (large capacity)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Setup

### Step 1: NAS Configuration (run FIRST)

```bash
# On NAS:
cd ~/workwork
bash permanent-thunderbolt-setup.sh
# Answer: n (this is NOT the Mac Mini)

# Manual commands if script fails:
sudo ifconfig bridge0 inet 169.254.1.2 netmask 255.255.0.0
sudo zfs set sharenfs=on tank
echo "/tank -alldirs -maproot=root:wheel -network 169.254.1.1 -mask 255.255.0.0" | sudo tee -a /etc/exports
sudo nfsd restart
```

### Step 2: Mac Mini Configuration (run SECOND)

```bash
# On Mac Mini:
cd ~/workwork
bash permanent-thunderbolt-setup.sh
# Answer: y (this IS the Mac Mini)

# This will:
# - Configure Thunderbolt network (169.254.1.1)
# - Create /Volumes/tank mount point
# - Setup auto-mount LaunchDaemon
# - Make it persistent across reboots
```

### Step 3: Mount and Verify

```bash
# On Mac Mini:
# Load the auto-mount daemon
sudo launchctl load /Library/LaunchDaemons/com.local.mount-tank.plist

# Verify mount
mount | grep tank
# Should show: 169.254.1.2:/tank on /Volumes/tank (nfs)

# Test access
ls -la /Volumes/tank/

# Check speed
dd if=/dev/zero of=/Volumes/tank/speedtest bs=1m count=1000
# Should see ~2-4 GB/s
rm /Volumes/tank/speedtest
```

---

## Working Directly from tank/*

### Create Forensics Workspace

```bash
# On Mac Mini (or via NAS):
sudo zfs create tank/forensics
sudo zfs create tank/forensics/macmini-infected
sudo zfs set compression=lz4 tank/forensics
sudo chown -R locnguyen:staff /tank/forensics  # Update username

# Now work directly:
cd /Volumes/tank/forensics/macmini-infected/

# Transfer archives directly to ZFS
mv ~/macmini-home-*.tar.gz /Volumes/tank/forensics/macmini-infected/

# Extract directly on ZFS (no local storage used)
tar -xzf macmini-home-*.tar.gz

# All analysis happens on NAS
```

### Benefits of Direct ZFS Work

✅ **No local storage limits** - 256GB Mac Mini doesn't matter
✅ **ZFS snapshots** - Instant rollback if you make mistakes
✅ **Compression** - LZ4 transparent compression
✅ **Checksums** - Automatic data integrity
✅ **Deduplication** - Optional (if enabled on tank)
✅ **Concurrent access** - Other machines can mount tank too

---

## Auto-Mount Configuration

### LaunchDaemon Created

**File:** `/Library/LaunchDaemons/com.local.mount-tank.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.mount-tank</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/mount_nfs</string>
        <string>-o</string>
        <string>resvport</string>
        <string>169.254.1.2:/tank</string>
        <string>/Volumes/tank</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

### Mount Management

```bash
# Load (mount now):
sudo launchctl load /Library/LaunchDaemons/com.local.mount-tank.plist

# Unload (unmount):
sudo launchctl unload /Library/LaunchDaemons/com.local.mount-tank.plist

# Check status:
launchctl list | grep mount-tank

# Check logs:
tail -f /tmp/mount-tank.log
tail -f /tmp/mount-tank.err
```

---

## Workflow Examples

### Example 1: Transfer and Extract

```bash
# Mac Mini home archive is ready
cd ~

# Move directly to NAS (instant, just metadata)
mv ~/macmini-home-20251013.tar.gz /Volumes/tank/forensics/macmini-infected/

# Extract on NAS (uses NAS CPU/storage, not local)
cd /Volumes/tank/forensics/macmini-infected/
tar -xzf macmini-home-20251013.tar.gz

# Work from extracted data
cd Users/locnguyen/work/
ls -la | grep -E "(-exec|;|\{\})"

# Check xattrs
xattr -l \;
```

### Example 2: Run Crystal Analyzer on NAS Data

```bash
# Analyzer can work on NAS-stored images
cd ~/workwork/apfs-analyzer

# Analyze image stored on tank
./bin/apfs-analyzer /Volumes/tank/forensics/images/infected.dmg \
  -o /Volumes/tank/forensics/reports/analyzer-report.md

# Results written directly to ZFS
```

### Example 3: Share Access with Other Machines

```bash
# Your workstation can mount same share
# On main workstation:
sudo mount -t nfs 192.168.x.x:/tank/forensics /Volumes/forensics

# Now both Mac Mini and workstation see same data
# Mac Mini via Thunderbolt: /Volumes/tank/forensics/
# Workstation via network: /Volumes/forensics/
```

---

## Performance Tuning

### Optimize NFS for Thunderbolt Speed

**On Mac Mini:**
```bash
# Increase NFS read/write sizes
sudo mount -u -o rsize=131072,wsize=131072 /Volumes/tank

# Or edit LaunchDaemon to include these options permanently
```

**On NAS:**
```bash
# Increase NFS threads (Linux)
sudo systemctl edit nfs-server.service
# Add:
# [Service]
# Environment="RPCNFSDCOUNT=16"

# macOS - already optimized by default
```

### Monitor Performance

```bash
# Real-time network stats
nettop -n -t thunderbolt

# NFS stats
nfsstat -c  # Client side (Mac Mini)
nfsstat -s  # Server side (NAS)

# ZFS stats
zpool iostat -v tank 1  # 1 second updates
```

---

## Troubleshooting

### Mount Fails on Boot

```bash
# Check Thunderbolt connectivity first
ifconfig bridge0
ping 169.254.1.2

# Check NFS exports on NAS
showmount -e 169.254.1.2

# Manual mount to test
sudo mount -t nfs -o resvport 169.254.1.2:/tank /Volumes/tank

# Check logs
tail /tmp/mount-tank.err
```

### Slow Performance

```bash
# Check for errors on Thunderbolt interface
netstat -I bridge0

# Check NFS mount options
mount | grep tank

# Should include: rsize=131072,wsize=131072

# Remount with optimal settings
sudo umount /Volumes/tank
sudo mount -t nfs -o resvport,rsize=131072,wsize=131072 169.254.1.2:/tank /Volumes/tank
```

### Can't Write to tank/*

```bash
# Check permissions
ls -la /Volumes/tank/

# Fix ownership (on NAS):
sudo chown -R locnguyen:staff /tank/forensics

# Check NFS export allows writes (on NAS):
cat /etc/exports
# Should have 'rw' not 'ro'
```

---

## Security Considerations

### Infected Mac Mini Access

⚠️ **The Mac Mini is infected** - limit what it can access:

```bash
# On NAS: Create restricted dataset for Mac Mini
sudo zfs create tank/forensics/macmini-quarantine
sudo chown locnguyen:staff /tank/forensics/macmini-quarantine

# Export ONLY this dataset to Mac Mini
# Edit /etc/exports:
/tank/forensics/macmini-quarantine -maproot=locnguyen -network 169.254.1.1

# Mac Mini can't access rest of tank/*
```

### Read-Only Mount Option

```bash
# Mount tank as read-only on Mac Mini (prevents malware writes)
sudo mount -t nfs -o ro,resvport 169.254.1.2:/tank /Volumes/tank

# Update LaunchDaemon to make persistent:
# Add 'ro,' to mount options
```

### Network Isolation

✅ **Already isolated:**
- Thunderbolt network is point-to-point
- No routing to other networks
- Mac Mini can't reach anything except NAS via 169.254.1.2
- NAS can firewall the Thunderbolt interface

```bash
# On NAS - block everything except NFS from Mac Mini
sudo iptables -A INPUT -s 169.254.1.1 -p tcp --dport 2049 -j ACCEPT  # NFS
sudo iptables -A INPUT -s 169.254.1.1 -j DROP  # Block everything else
```

---

## Maintenance

### Daily Checks

```bash
# Verify mount still active
mount | grep tank

# Check ZFS health
zpool status tank

# Check available space
zfs list tank/forensics
```

### Weekly Snapshots

```bash
# Create weekly snapshot of forensics data
sudo zfs snapshot tank/forensics@$(date +%Y%m%d)

# List snapshots
zfs list -t snapshot -r tank/forensics

# Rollback if needed
sudo zfs rollback tank/forensics@20251013
```

### Cleanup

```bash
# When Mac Mini forensics complete, unmount
sudo launchctl unload /Library/LaunchDaemons/com.local.mount-tank.plist
sudo umount /Volumes/tank

# Archive forensics data (on NAS)
sudo zfs snapshot tank/forensics/macmini-infected@final
sudo zfs send tank/forensics/macmini-infected@final | gzip > macmini-infected-archive.zfs.gz

# Remove LaunchDaemon
sudo rm /Library/LaunchDaemons/com.local.mount-tank.plist

# Reset Thunderbolt network
sudo ifconfig bridge0 down
```

---

## Summary

**Status:** Permanent high-speed connection
**Connection:** Thunderbolt (20-40 Gbps)
**Protocol:** NFS over Thunderbolt network
**Mac Mini IP:** 169.254.1.1
**NAS IP:** 169.254.1.2
**Mount:** /Volumes/tank → tank/*
**Auto-mount:** ✓ On boot via LaunchDaemon
**Storage:** Work directly from ZFS (no local limits)

**Result:** Mac Mini is now a thin client working entirely off NAS storage. All forensic work happens on tank/*, leveraging ZFS features and unlimited storage.

---

**Run the setup script on both machines, then start working directly from /Volumes/tank/!**
