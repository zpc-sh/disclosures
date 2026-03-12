# Thunderbolt Networking Setup Guide
## Mac Mini ↔ NAS Server Direct Connection

**Speed:** Up to 40 Gbps (Thunderbolt 3/4) or 20 Gbps (Thunderbolt 2)
**Latency:** Ultra-low, direct connection
**Use Case:** Fast forensic data transfer from infected Mac Mini

---

## Setup Steps

### Step 1: Mac Mini Configuration

```bash
# 1. Check if Thunderbolt Bridge interface exists
ifconfig bridge0

# If not present, create it (usually auto-created when TB cable plugged in)
# Check all interfaces
ifconfig -a | grep -E "(bridge|thunderbolt)"

# 2. Assign static IP to Thunderbolt Bridge
sudo ifconfig bridge0 inet 169.254.1.1 netmask 255.255.0.0

# 3. Verify interface is up
ifconfig bridge0
# Should show: status: active, inet: 169.254.1.1

# 4. Enable IP forwarding (if needed)
sudo sysctl -w net.inet.ip.forwarding=1
```

### Step 2: NAS/Server Configuration

```bash
# On the NAS server:

# 1. Find Thunderbolt interface name
ifconfig -a | grep -E "(thunderbolt|bridge)"
# Common names: thunderbolt0, bridge0, enp0s20f0u1 (Linux)

# 2. Assign static IP on same subnet
# macOS NAS:
sudo ifconfig bridge0 inet 169.254.1.2 netmask 255.255.0.0

# Linux NAS:
sudo ip addr add 169.254.1.2/16 dev thunderbolt0
sudo ip link set thunderbolt0 up

# 3. Verify interface
ifconfig bridge0  # macOS
ip addr show thunderbolt0  # Linux
```

### Step 3: Test Connectivity

```bash
# From Mac Mini:
ping -c 4 169.254.1.2

# From NAS:
ping -c 4 169.254.1.1

# Should get replies with <1ms latency
```

---

## Quick Setup Scripts

### Mac Mini (run this)

```bash
#!/bin/bash
# thunderbolt-setup-macmini.sh

echo "=== Thunderbolt Network Setup - Mac Mini ==="

# Find Thunderbolt bridge interface
TB_IF=$(ifconfig -a | grep -E "^(bridge|thunderbolt)" | head -1 | cut -d: -f1)

if [ -z "$TB_IF" ]; then
    echo "ERROR: No Thunderbolt bridge interface found"
    echo "Is the Thunderbolt cable connected?"
    exit 1
fi

echo "Found interface: $TB_IF"

# Assign IP
echo "Assigning IP 169.254.1.1..."
sudo ifconfig $TB_IF inet 169.254.1.1 netmask 255.255.0.0

# Verify
echo "Interface status:"
ifconfig $TB_IF

# Test connectivity
echo "Testing connectivity to NAS (169.254.1.2)..."
ping -c 2 169.254.1.2 && echo "SUCCESS: NAS reachable" || echo "WAITING: NAS not ready yet"
```

### NAS Server (run this)

```bash
#!/bin/bash
# thunderbolt-setup-nas.sh

echo "=== Thunderbolt Network Setup - NAS ==="

# Find Thunderbolt interface
TB_IF=$(ifconfig -a 2>/dev/null | grep -E "^(bridge|thunderbolt)" | head -1 | cut -d: -f1)

# If macOS ifconfig fails, try Linux ip command
if [ -z "$TB_IF" ]; then
    TB_IF=$(ip link show 2>/dev/null | grep -E "thunderbolt|usb" | cut -d: -f2 | awk '{print $1}' | head -1)
fi

if [ -z "$TB_IF" ]; then
    echo "ERROR: No Thunderbolt interface found"
    exit 1
fi

echo "Found interface: $TB_IF"

# Assign IP (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Assigning IP 169.254.1.2 (macOS)..."
    sudo ifconfig $TB_IF inet 169.254.1.2 netmask 255.255.0.0
    ifconfig $TB_IF
fi

# Assign IP (Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Assigning IP 169.254.1.2 (Linux)..."
    sudo ip addr add 169.254.1.2/16 dev $TB_IF
    sudo ip link set $TB_IF up
    ip addr show $TB_IF
fi

# Test connectivity
echo "Testing connectivity to Mac Mini (169.254.1.1)..."
ping -c 2 169.254.1.1 && echo "SUCCESS: Mac Mini reachable" || echo "WAITING: Mac Mini not ready yet"
```

---

## Transfer Methods

### Option 1: SCP (Simple, Encrypted)

```bash
# From Mac Mini → NAS
scp -r ~/macmini-home-*.tar.gz user@169.254.1.2:/path/to/storage/

# With compression disabled (already compressed tar.gz)
scp -o Compression=no ~/macmini-*.tar.gz user@169.254.1.2:/path/to/storage/
```

### Option 2: rsync (Resumable)

```bash
# From Mac Mini → NAS
rsync -avz --progress --partial \
  ~/macmini-*.tar.gz \
  user@169.254.1.2:/path/to/storage/

# For VERY large files, use --inplace to avoid temp copies
rsync -av --progress --partial --inplace \
  ~/macmini-home-*.tar.gz \
  user@169.254.1.2:/path/to/storage/
```

### Option 3: SMB Mount (Most Convenient)

```bash
# From Mac Mini, mount NAS share
mkdir -p /Volumes/NAS

# Mount via Thunderbolt IP
mount_smbfs //user@169.254.1.2/share /Volumes/NAS

# Then just copy
cp ~/macmini-*.tar.gz /Volumes/NAS/

# Or move (faster, no copy)
mv ~/macmini-*.tar.gz /Volumes/NAS/
```

### Option 4: netcat (Fastest for single large file)

```bash
# On NAS (receiver):
nc -l 9999 > /path/to/storage/macmini-home.tar.gz

# On Mac Mini (sender):
nc 169.254.1.2 9999 < ~/macmini-home-*.tar.gz

# Shows no progress, but MAXIMUM speed
```

---

## Speed Comparison

| Method | Speed | Resume | Progress | Encrypted |
|--------|-------|--------|----------|-----------|
| `scp` | Good (1-2 GB/s) | No | Yes (with -v) | Yes |
| `rsync` | Good (1-2 GB/s) | Yes | Yes | Yes |
| `SMB` | Best (2-3 GB/s) | Yes | Finder UI | Optional |
| `netcat` | Maximum (3-4 GB/s) | No | No | No |

**Recommendation for your use case:** SMB mount (convenient) or rsync (safe, resumable)

---

## Troubleshooting

### Interface not found
```bash
# Check System Preferences → Network
# Should see "Thunderbolt Bridge" interface

# If missing, check cable connection
system_profiler SPThunderboltDataType

# Should show connected device
```

### Can't ping other side
```bash
# Check firewall on NAS
# macOS:
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Disable temporarily for testing:
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off

# Linux:
sudo ufw status
sudo ufw allow from 169.254.1.0/16
```

### Slow speeds
```bash
# Check MTU
ifconfig bridge0 | grep mtu
# Should be 1500 or higher

# Increase MTU for better performance
sudo ifconfig bridge0 mtu 9000

# Check for errors
netstat -I bridge0 -b
```

### IP already in use
```bash
# Remove existing IP first
sudo ifconfig bridge0 delete 169.254.1.1

# Then reassign
sudo ifconfig bridge0 inet 169.254.1.1 netmask 255.255.0.0
```

---

## Security Notes

### For Infected Mac Mini Transfer

✅ **Safe:**
- Direct Thunderbolt connection (no network exposure)
- Point-to-point, no routing
- No internet access via this link

⚠️ **Caution:**
- Don't mount NAS shares read-write on Mac Mini (malware could spread)
- Use pull method (NAS pulls from Mac Mini) or push-only
- Scan archives on NAS before opening

### Recommended Transfer Flow

```bash
# 1. On NAS: Pull files (Mac Mini can't write back)
rsync -av user@169.254.1.1:~/macmini-*.tar.gz /safe/storage/

# 2. Or on Mac Mini: Push to specific write-once location
rsync -av ~/macmini-*.tar.gz user@169.254.1.2:/quarantine/$(date +%Y%m%d)/

# 3. Immediately verify and then unmount
shasum -a 256 /safe/storage/macmini-*.tar.gz
umount /Volumes/NAS
```

---

## Post-Transfer Cleanup

```bash
# On Mac Mini (after successful transfer):

# 1. Verify transfer
ssh user@169.254.1.2 "shasum -a 256 /path/to/macmini-*.tar.gz"

# Compare with local
shasum -a 256 ~/macmini-*.tar.gz

# 2. If match, delete local copy
rm ~/macmini-*.tar.gz

# 3. Tear down Thunderbolt network
sudo ifconfig bridge0 down
```

---

## Performance Tips

### Maximum Speed Setup

```bash
# 1. Increase MTU (Jumbo Frames)
sudo ifconfig bridge0 mtu 9000

# 2. Disable compression (archives already compressed)
rsync --no-compress ...

# 3. Use multiple streams (for multiple files)
parallel -j4 scp {} user@169.254.1.2:/storage/ ::: *.tar.gz

# 4. Disable TCP throttling (macOS)
sudo sysctl -w net.inet.tcp.delayed_ack=0
```

---

## Quick Reference

### Mac Mini IP: `169.254.1.1`
### NAS IP: `169.254.1.2`
### Interface: `bridge0` (macOS) or `thunderbolt0` (Linux)

### One-liner setup:
```bash
# Mac Mini:
sudo ifconfig bridge0 inet 169.254.1.1 netmask 255.255.0.0 && ping -c 2 169.254.1.2

# NAS:
sudo ifconfig bridge0 inet 169.254.1.2 netmask 255.255.0.0 && ping -c 2 169.254.1.1
```

### Quick transfer:
```bash
# From Mac Mini:
rsync -av --progress ~/macmini-*.tar.gz user@169.254.1.2:/storage/
```

---

**Ready to configure! Run the setup scripts on both machines, then start the transfer.**
