#!/bin/bash
# Configure NFS on Ubuntu NAS
# Run after nas-remote-setup.sh

set -e

NAS_HOST="alpine.nocsi.org"
NAS_USER="locnguyen"

echo "=== NFS Export Configuration ==="
echo

# Create NFS setup script
cat > /tmp/nas-nfs-setup.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "=== Configuring NFS Server ==="
echo

# 1. Install NFS server if needed
echo "[1/5] Checking NFS server..."
if ! dpkg -l | grep -q nfs-kernel-server; then
    echo "Installing nfs-kernel-server..."
    sudo apt update
    sudo apt install -y nfs-kernel-server
else
    echo "✓ NFS server already installed"
fi

# 2. Check if tank exists
echo "[2/5] Checking ZFS tank..."
if ! zfs list tank > /dev/null 2>&1; then
    echo "⚠ ZFS tank not found!"
    echo "Available ZFS filesystems:"
    zfs list -o name
    exit 1
fi
echo "✓ ZFS tank found"

# 3. Create forensics dataset
echo "[3/5] Creating forensics dataset..."
if ! zfs list tank/forensics > /dev/null 2>&1; then
    sudo zfs create tank/forensics
    sudo zfs set compression=lz4 tank/forensics
    sudo chown locnguyen:locnguyen /tank/forensics
    echo "✓ Created tank/forensics"
else
    echo "✓ tank/forensics already exists"
fi

# 4. Configure NFS export
echo "[4/5] Configuring NFS export..."
if ! grep -q "^/tank" /etc/exports; then
    echo "/tank 169.254.1.1/16(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    echo "✓ Added NFS export"
else
    echo "✓ NFS export already configured"
fi

# 5. Enable and restart NFS
echo "[5/5] Restarting NFS server..."
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl restart nfs-server

# 6. Enable ZFS sharenfs
sudo zfs set sharenfs=on tank

echo
echo "=== NFS Configuration Complete ==="
echo
echo "NFS exports:"
sudo exportfs -v
echo
echo "Verify from Mac Mini:"
echo "  showmount -e 169.254.1.2"
EOFSCRIPT

echo "Copying NFS setup script to NAS..."
scp /tmp/nas-nfs-setup.sh ${NAS_USER}@${NAS_HOST}:/tmp/

echo
echo "Executing NFS setup on NAS..."
ssh -t ${NAS_USER}@${NAS_HOST} "bash /tmp/nas-nfs-setup.sh"

echo
echo "=== NFS Setup Complete ==="
echo
echo "Test from Mac Mini:"
echo "  showmount -e 169.254.1.2"
echo "  sudo mount -t nfs 169.254.1.2:/tank /Volumes/tank"
