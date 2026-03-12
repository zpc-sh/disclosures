#!/bin/bash
# Mac Mini - Thunderbolt + NFS Mount Setup
# Run this on the infected Mac Mini

set -e

echo "=== Mac Mini Thunderbolt Setup ==="
echo

NAS_IP="169.254.1.2"
MOUNT_POINT="/Volumes/tank"

# 1. Configure Thunderbolt
echo "[1/4] Configuring Thunderbolt Bridge..."
sudo ifconfig bridge2 inet 169.254.1.1 netmask 255.255.0.0

# Make persistent
sudo networksetup -setmanual "Thunderbolt Bridge 2" 169.254.1.1 255.255.0.0

echo "✓ Thunderbolt configured: 169.254.1.1"
echo

# 2. Test connectivity
echo "[2/4] Testing connectivity to NAS..."
if ping -c 2 -W 2 $NAS_IP > /dev/null 2>&1; then
    echo "✓ NAS reachable at $NAS_IP"
else
    echo "⚠ Cannot reach NAS - ensure NAS side is configured first"
    echo "  Continuing anyway..."
fi
echo

# 3. Create mount point
echo "[3/4] Creating mount point..."
sudo mkdir -p "$MOUNT_POINT"
sudo chown $(whoami):staff "$MOUNT_POINT"
echo "✓ Mount point: $MOUNT_POINT"
echo

# 4. Test mount
echo "[4/4] Testing NFS mount..."
if showmount -e $NAS_IP 2>/dev/null; then
    echo "✓ NFS exports available from NAS"
    echo
    echo "Attempting mount..."
    if sudo mount -t nfs -o resvport $NAS_IP:/tank $MOUNT_POINT 2>/dev/null; then
        echo "✓ Successfully mounted!"
        echo
        ls -la $MOUNT_POINT/
    else
        echo "⚠ Mount failed - NFS may not be configured yet"
    fi
else
    echo "⚠ No NFS exports visible from NAS"
fi
echo

# 5. Create auto-mount LaunchDaemon
echo "[5/5] Creating auto-mount LaunchDaemon..."
cat > /tmp/com.local.mount-tank.plist << 'EOF'
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
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

sudo cp /tmp/com.local.mount-tank.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.local.mount-tank.plist
sudo chmod 644 /Library/LaunchDaemons/com.local.mount-tank.plist

echo "✓ Auto-mount LaunchDaemon created"
echo

echo "=== Setup Complete ==="
echo
echo "To enable auto-mount on boot:"
echo "  sudo launchctl load /Library/LaunchDaemons/com.local.mount-tank.plist"
echo
echo "To mount now (if not already mounted):"
echo "  sudo mount -t nfs -o resvport $NAS_IP:/tank $MOUNT_POINT"
echo
echo "Verify:"
echo "  mount | grep tank"
echo "  ls $MOUNT_POINT"
