#!/bin/bash
# Fix Thunderbolt IP on Ubuntu NAS
# Run on NAS directly

set -e

echo "=== Fixing Thunderbolt IP Assignment ==="
echo

# 1. Fix permissions warning
echo "[1/5] Fixing netplan file permissions..."
sudo chmod 600 /etc/netplan/99-thunderbolt.yaml

# 2. Try manual IP assignment first (to test if interface works)
echo "[2/5] Manually assigning IP to test..."
sudo ip addr add 169.254.1.2/16 dev thunderbolt0 2>/dev/null || echo "IP may already be assigned"

# 3. Verify IP
echo "[3/5] Checking IP assignment..."
ip addr show thunderbolt0 | grep "inet 169.254.1.2"

# 4. Test connectivity
echo "[4/5] Testing connectivity..."
if ping -c 2 169.254.1.1; then
    echo "✓ Manual IP works!"
else
    echo "⚠ Still no connectivity - may be Mac Mini side issue"
fi

# 5. Make permanent via netplan
echo "[5/5] Updating netplan for permanent configuration..."
sudo tee /etc/netplan/99-thunderbolt.yaml > /dev/null << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    thunderbolt0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 169.254.1.2/16
EOF

sudo chmod 600 /etc/netplan/99-thunderbolt.yaml
sudo netplan apply

echo
echo "=== IP Configuration ==="
ip addr show thunderbolt0
echo
echo "If connectivity works, proceed with NFS setup."
