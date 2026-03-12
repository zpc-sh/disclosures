#!/bin/bash
# Run these commands directly on the Ubuntu NAS
# Copy/paste into NAS terminal

set -e

echo "=== Configuring Ubuntu NAS for Thunderbolt ==="
echo

# 1. Find Thunderbolt interface
echo "[1/6] Finding Thunderbolt interface..."
ip link show | grep -E "^[0-9]+:" | grep -i "thunderbolt\|usb"
echo
read -p "Enter Thunderbolt interface name from above (e.g., thunderbolt0): " TB_IF

# 2. Bring interface up
echo "[2/6] Bringing interface up..."
sudo ip link set $TB_IF up
sleep 2

# 3. Create netplan config
echo "[3/6] Creating netplan configuration..."
sudo tee /etc/netplan/99-thunderbolt.yaml > /dev/null << EOF
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

echo "✓ Netplan config created"

# 4. Apply netplan
echo "[4/6] Applying netplan..."
sudo netplan apply
sleep 2

# 5. Verify IP
echo "[5/6] Verifying configuration..."
ip addr show $TB_IF

# 6. Test connectivity
echo "[6/6] Testing connectivity to Mac Mini..."
ping -c 3 169.254.1.1

echo
echo "=== Thunderbolt Network Complete ==="
echo
echo "Next: Configure NFS"
echo "Press Enter to continue with NFS setup..."
read

# NFS Setup
echo
echo "=== Configuring NFS Server ==="
echo

# Install NFS
echo "[1/5] Installing NFS server..."
sudo apt update && sudo apt install -y nfs-kernel-server

# Create forensics dataset
echo "[2/5] Creating forensics dataset..."
sudo zfs create -p tank/forensics
sudo zfs set compression=lz4 tank/forensics
sudo chown locnguyen:locnguyen /tank/forensics

# Configure NFS export
echo "[3/5] Adding NFS export..."
echo "/tank 169.254.1.1/16(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Restart NFS
echo "[4/5] Restarting NFS..."
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl restart nfs-server

# Enable ZFS sharenfs
echo "[5/5] Enabling ZFS sharing..."
sudo zfs set sharenfs=on tank

echo
echo "=== COMPLETE ==="
echo
echo "NFS exports:"
sudo exportfs -v
echo
echo "Test from Mac Mini:"
echo "  showmount -e 169.254.1.2"
echo "  sudo mount -t nfs 169.254.1.2:/tank /Volumes/tank"
