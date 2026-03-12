#!/bin/bash
# Remote NAS Configuration via SSH
# Run this from your workstation

set -e

# Configuration
NAS_HOST="10.10.15.2"  # Or use IP address
NAS_USER="locnguyen"          # Your NAS username
THUNDERBOLT_IP="169.254.1.2"

echo "=== Remote NAS Thunderbolt Setup ==="
echo
echo "NAS Host: $NAS_HOST"
echo "NAS User: $NAS_USER"
echo

# Create the setup script
cat > /tmp/nas-setup-remote.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "=== Configuring Ubuntu NAS for Thunderbolt ==="
echo

# 1. Find Thunderbolt interface
echo "[1/6] Finding Thunderbolt interface..."
TB_IF=$(ip link show | grep -i "thunderbolt\|usb" | grep "state UP" | head -1 | cut -d: -f2 | awk '{print $1}')

if [ -z "$TB_IF" ]; then
    echo "⚠ No active Thunderbolt interface with state UP"
    echo "Available interfaces:"
    ip link show | grep "^[0-9]:" | cut -d: -f2
    echo
    # Try to find any thunderbolt interface even if down
    TB_IF=$(ip link show | grep -i "thunderbolt" | head -1 | cut -d: -f2 | awk '{print $1}')
    if [ -z "$TB_IF" ]; then
        echo "Enter Thunderbolt interface name (e.g., thunderbolt0):"
        read TB_IF
    fi
fi

echo "Using interface: $TB_IF"
echo

# 2. Bring interface up
echo "[2/6] Bringing interface up..."
sudo ip link set $TB_IF up
sleep 2

# 3. Create netplan config
echo "[3/6] Creating netplan configuration..."
sudo tee /etc/netplan/99-thunderbolt.yaml > /dev/null << EOF
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

echo "✓ Netplan config created"

# 4. Apply netplan
echo "[4/6] Applying netplan..."
sudo netplan apply
sleep 2

# 5. Verify IP
echo "[5/6] Verifying configuration..."
ip addr show $TB_IF | grep "inet 169.254.1.2"
if [ $? -eq 0 ]; then
    echo "✓ IP configured: 169.254.1.2"
else
    echo "⚠ IP not showing - may take a moment"
fi

# 6. Test connectivity
echo "[6/6] Testing connectivity to Mac Mini (169.254.1.1)..."
if ping -c 2 -W 2 169.254.1.1 > /dev/null 2>&1; then
    echo "✓ Mac Mini reachable!"
else
    echo "⚠ Cannot reach Mac Mini yet - ensure Mac Mini is configured"
fi

echo
echo "=== Network Configuration Complete ==="
ip addr show $TB_IF
EOFSCRIPT

# Copy script to NAS
echo "Copying setup script to NAS..."
scp /tmp/nas-setup-remote.sh ${NAS_USER}@${NAS_HOST}:/tmp/

# Execute on NAS
echo
echo "Executing setup on NAS..."
ssh -t ${NAS_USER}@${NAS_HOST} "bash /tmp/nas-setup-remote.sh"

echo
echo "=== NAS Network Setup Complete ==="
echo
echo "Next: Configure NFS export"
echo "Run: ./nas-nfs-setup.sh"
