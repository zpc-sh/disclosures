#!/bin/bash
# Permanent Thunderbolt Network Setup
# Mac Mini ↔ NAS (ZFS tank/*) via Thunderbolt

set -e

echo "=== Permanent Thunderbolt + NAS Setup ==="
echo

# Configuration
MAC_MINI_IP="169.254.1.1"
NAS_IP="169.254.1.2"
NAS_USER="locnguyen"  # Update if different
ZFS_SHARE="tank"
MOUNT_POINT="/Volumes/tank"

# Determine which machine we're on
read -p "Is this the Mac Mini (infected)? [y/n]: " IS_MACMINI

if [[ "$IS_MACMINI" =~ ^[Yy]$ ]]; then
    echo "Configuring Mac Mini..."

    # 1. Configure Thunderbolt network (permanent)
    echo "[1/4] Setting up Thunderbolt Bridge..."
    sudo ifconfig bridge0 inet $MAC_MINI_IP netmask 255.255.0.0

    # Make it persist across reboots
    sudo networksetup -setmanual "Thunderbolt Bridge" $MAC_MINI_IP 255.255.0.0

    echo "[2/4] Testing connectivity..."
    if ping -c 2 -W 2 $NAS_IP > /dev/null 2>&1; then
        echo "✓ NAS reachable at $NAS_IP"
    else
        echo "⚠ NAS not responding yet - configure NAS side first"
    fi

    # 3. Create mount point
    echo "[3/4] Creating mount point..."
    sudo mkdir -p "$MOUNT_POINT"
    sudo chown $(whoami):staff "$MOUNT_POINT"

    # 4. Create auto-mount LaunchDaemon
    echo "[4/4] Setting up auto-mount on boot..."

    cat > /tmp/com.local.mount-tank.plist << EOF
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
        <string>$NAS_IP:/$ZFS_SHARE</string>
        <string>$MOUNT_POINT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/mount-tank.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mount-tank.err</string>
</dict>
</plist>
EOF

    sudo mv /tmp/com.local.mount-tank.plist /Library/LaunchDaemons/
    sudo chown root:wheel /Library/LaunchDaemons/com.local.mount-tank.plist
    sudo chmod 644 /Library/LaunchDaemons/com.local.mount-tank.plist

    echo
    echo "=== Mac Mini Configuration Complete ==="
    echo
    echo "Manual mount command (if needed):"
    echo "  sudo mount -t nfs -o resvport $NAS_IP:/$ZFS_SHARE $MOUNT_POINT"
    echo
    echo "Auto-mount will trigger on next reboot."
    echo "To mount now:"
    echo "  sudo launchctl load /Library/LaunchDaemons/com.local.mount-tank.plist"

else
    echo "Configuring NAS..."

    # 1. Configure Thunderbolt network
    echo "[1/3] Setting up Thunderbolt Bridge..."

    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS NAS
        sudo ifconfig bridge0 inet $NAS_IP netmask 255.255.0.0
        sudo networksetup -setmanual "Thunderbolt Bridge" $NAS_IP 255.255.0.0
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux NAS
        TB_IF=$(ip link show | grep -E "thunderbolt|usb" | cut -d: -f2 | awk '{print $1}' | head -1)
        if [ -z "$TB_IF" ]; then
            TB_IF="bridge0"
        fi
        sudo ip addr add $NAS_IP/16 dev $TB_IF
        sudo ip link set $TB_IF up

        # Make persistent (systemd-networkd)
        cat > /tmp/thunderbolt.network << EOF
[Match]
Name=$TB_IF

[Network]
Address=$NAS_IP/16
EOF
        sudo mv /tmp/thunderbolt.network /etc/systemd/network/
        sudo systemctl restart systemd-networkd
    fi

    echo "[2/3] Testing connectivity..."
    if ping -c 2 -W 2 $MAC_MINI_IP > /dev/null 2>&1; then
        echo "✓ Mac Mini reachable at $MAC_MINI_IP"
    else
        echo "⚠ Mac Mini not responding - configure Mac Mini side"
    fi

    # 3. Enable NFS export for tank
    echo "[3/3] Configuring NFS export for /$ZFS_SHARE..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS NFS
        echo "/$ZFS_SHARE -alldirs -maproot=root:wheel -network $MAC_MINI_IP -mask 255.255.0.0" | sudo tee -a /etc/exports
        sudo nfsd restart
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux NFS
        echo "/$ZFS_SHARE $MAC_MINI_IP/16(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
        sudo exportfs -ra
        sudo systemctl restart nfs-server
    fi

    # Set ZFS sharenfs property
    echo "Setting ZFS sharenfs property..."
    sudo zfs set sharenfs=on $ZFS_SHARE

    echo
    echo "=== NAS Configuration Complete ==="
    echo
    echo "NFS export active: /$ZFS_SHARE"
    echo "Accessible from: $MAC_MINI_IP"
    echo
    echo "Test from Mac Mini:"
    echo "  showmount -e $NAS_IP"
fi

echo
echo "=== Next Steps ==="
if [[ "$IS_MACMINI" =~ ^[Yy]$ ]]; then
    echo "1. Configure NAS side with this script"
    echo "2. Load auto-mount: sudo launchctl load /Library/LaunchDaemons/com.local.mount-tank.plist"
    echo "3. Verify mount: ls $MOUNT_POINT"
    echo "4. Work directly from $MOUNT_POINT/forensics/"
else
    echo "1. Configure Mac Mini side with this script"
    echo "2. From Mac Mini: showmount -e $NAS_IP"
    echo "3. From Mac Mini: sudo mount -t nfs $NAS_IP:/$ZFS_SHARE $MOUNT_POINT"
fi
