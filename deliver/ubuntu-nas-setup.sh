#!/bin/bash
# Ubuntu NAS - Thunderbolt + NFS Setup
# Run this on the Ubuntu NAS server

set -e

echo "=== Ubuntu NAS Thunderbolt Setup ==="
echo

# 1. Find Thunderbolt interface
echo "[1/5] Detecting Thunderbolt interface..."
TB_IF=$(ip link show | grep -E "(thunderbolt|usb)" | grep -v "NO-CARRIER" | head -1 | cut -d: -f2 | awk '{print $1}')

if [ -z "$TB_IF" ]; then
    echo "⚠ No active Thunderbolt interface found. Available interfaces:"
    ip link show | grep -E "^[0-9]" | cut -d: -f2
    echo
    read -p "Enter Thunderbolt interface name: " TB_IF
fi

echo "Using interface: $TB_IF"
echo

# 2. Create netplan config
echo "[2/5] Creating netplan configuration..."
cat > /tmp/99-thunderbolt.yaml << EOF
# Thunderbolt network to Mac Mini
network:
  version: 2
  renderer: networkd
  ethernets:
    $TB_IF:
      dhcp4: no
      dhcp6: no
      addresses:
        - 169.254.1.2/16
EOF

echo "Netplan config:"
cat /tmp/99-thunderbolt.yaml
echo

# 3. Apply netplan (needs sudo)
echo "[3/5] Applying netplan configuration..."
echo "Run: sudo cp /tmp/99-thunderbolt.yaml /etc/netplan/"
echo "Run: sudo netplan apply"
echo

# 4. Configure NFS export
echo "[4/5] Configuring NFS export for /tank..."
echo "Add this line to /etc/exports:"
echo "/tank 169.254.1.1/16(rw,sync,no_subtree_check,no_root_squash)"
echo

# 5. ZFS sharenfs
echo "[5/5] ZFS configuration..."
echo "Run: sudo zfs set sharenfs=on tank"
echo

echo "=== Manual Steps Required ==="
echo
echo "1. Copy netplan config:"
echo "   sudo cp /tmp/99-thunderbolt.yaml /etc/netplan/"
echo "   sudo netplan apply"
echo
echo "2. Install NFS server (if not already):"
echo "   sudo apt install nfs-kernel-server"
echo
echo "3. Add to /etc/exports:"
echo "   /tank 169.254.1.1/16(rw,sync,no_subtree_check,no_root_squash)"
echo
echo "4. Restart NFS:"
echo "   sudo exportfs -ra"
echo "   sudo systemctl restart nfs-server"
echo
echo "5. Enable ZFS sharing:"
echo "   sudo zfs set sharenfs=on tank"
echo
echo "6. Verify:"
echo "   ip addr show $TB_IF"
echo "   showmount -e localhost"
echo
echo "Then configure Mac Mini side."
