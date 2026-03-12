#!/bin/bash
# Quick NFS setup on Ubuntu NAS
# Run on NAS after Thunderbolt network is working

set -e

echo "=== NFS Server Configuration ==="
echo

# 1. Install NFS server
echo "[1/5] Installing NFS server..."
sudo apt update
sudo apt install -y nfs-kernel-server

# 2. Create forensics dataset
echo "[2/5] Creating tank/forensics dataset..."
sudo zfs create -p tank/forensics 2>/dev/null || echo "Dataset may already exist"
sudo zfs set compression=lz4 tank/forensics
sudo chown -R locnguyen:locnguyen /tank/forensics

# 3. Add NFS export
echo "[3/5] Configuring NFS export..."
if ! grep -q "^/tank" /etc/exports; then
    echo "/tank 169.254.1.1/16(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    echo "✓ Added /tank export"
else
    echo "✓ /tank already exported"
fi

# 4. Apply NFS exports
echo "[4/5] Applying NFS configuration..."
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl restart nfs-server

# 5. Enable ZFS sharing
echo "[5/5] Enabling ZFS sharenfs..."
sudo zfs set sharenfs=on tank

echo
echo "=== NFS Configuration Complete ==="
echo
echo "Active NFS exports:"
sudo exportfs -v
echo
echo "Ready for Mac Mini to mount!"
echo "Run on Mac Mini:"
echo "  showmount -e 169.254.1.2"
echo "  sudo mkdir -p /Volumes/tank"
echo "  sudo mount -t nfs 169.254.1.2:/tank /Volumes/tank"
