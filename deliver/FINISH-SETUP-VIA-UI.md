# Finish Network Setup - Quick UI Guide

## What's Already Done ✅
- 6 VLANs created (Trusted, IoT, Guest, Lab, Testing, Quarantine)
- WAN firewall protection enabled
- IPS/IDS enabled
- Basic network structure ready

## What You Need to Do (5 minutes)

### Step 1: Create Management VLAN
**Settings → Networks → Create New Network**
```
Name: Management
VLAN ID: 1
Gateway/Subnet: 10.0.1.1/24
DHCP Range: 10.0.1.100 - 10.0.1.200
Advanced: Enable IGMP Snooping
```
Click **Add Network**

---

### Step 2: Create Firewall Rules
**Settings → Security → Firewall Rules → Create New Rule**

**Rule 1: Block IoT → Management**
```
Type: LAN In
Description: Block IoT from Management
Action: Drop
Protocol: All
Source: Network → IoT
Destination: Network → Management
✓ Enable Logging
```

**Rule 2: Block Guest → Management**
```
Type: LAN In
Description: Block Guest from Management
Action: Drop
Protocol: All
Source: Network → Guest
Destination: Network → Management
✓ Enable Logging
```

**Rule 3: Block IoT → Trusted**
```
Type: LAN In
Description: Block IoT from Trusted
Action: Drop
Protocol: All
Source: Network → IoT
Destination: Network → Trusted
✓ Enable Logging
```

**Rule 4: Block Guest → Trusted**
```
Type: LAN In
Description: Block Guest from Trusted
Action: Drop
Protocol: All
Source: Network → Guest
Destination: Network → Trusted
✓ Enable Logging
```

**Rule 5: Block Guest → IoT**
```
Type: LAN In
Description: Block Guest from IoT
Action: Drop
Protocol: All
Source: Network → Guest
Destination: Network → IoT
✓ Enable Logging
```

**Rule 6: Block All → Quarantine**
```
Type: LAN In
Description: Isolate Quarantine Network
Action: Drop
Protocol: All
Source: Any
Destination: Network → Quarantine
✓ Enable Logging
```

---

### Step 3: Verify Networks
**Settings → Networks**

Should see:
- ✓ Default (192.168.1.0/24)
- ✓ Management (10.0.1.0/24) VLAN 1
- ✓ Trusted (10.0.10.0/24) VLAN 10
- ✓ IoT (10.0.20.0/24) VLAN 20
- ✓ Guest (10.0.30.0/24) VLAN 30
- ✓ Lab (10.0.40.0/24) VLAN 40
- ✓ Device-Testing (10.0.98.0/24) VLAN 98
- ✓ Quarantine (10.0.99.0/24) VLAN 99

---

### Step 4: Create WiFi Networks (Optional - If You Have APs)

**Settings → WiFi → Create New Network**

**Trusted WiFi**
```
Name/SSID: [YourName]-Secure
Password: [Strong passphrase - save it!]
Security: WPA3 (or WPA2/WPA3)
Network: Trusted (VLAN 10)
WiFi Band: 5 GHz Preferred
```

**IoT WiFi**
```
Name/SSID: [YourName]-IoT
Password: [Different passphrase]
Security: WPA2 (for compatibility)
Network: IoT (VLAN 20)
WiFi Band: 2.4 GHz + 5 GHz
✓ Client Device Isolation
```

**Guest WiFi**
```
Name/SSID: [YourName]-Guest
Password: [Simple guest password]
Security: WPA2
Network: Guest (VLAN 30)
✓ Guest Policy (24 hour access)
✓ Client Device Isolation
```

---

### Step 5: Move Your Mac to Trusted Network

**Your Mac** (currently on Default 192.168.1.49):

**Option A: Connect to Trusted WiFi** (if you created it)
- Just connect to your "YourName-Secure" WiFi
- You'll get 10.0.10.x address
- Test: Can still access https://192.168.1.1

**Option B: Assign via Ethernet** (if wired)
1. Settings → Client Devices
2. Find "Big-Mac" (64:4b:f0:60:09:da)
3. Click device → Settings
4. Network → Change to "Trusted"
5. Apply

---

### Step 6: Verify Firewall Rules Work

After moving to Trusted network:

**Should WORK:**
```bash
ping 10.0.1.1      # Management gateway
ping 10.0.20.1     # IoT gateway
ping 8.8.8.8       # Internet
```

**Should FAIL** (test from IoT device if you have one):
```bash
ping 10.0.1.1      # Can't reach management
ping 10.0.10.100   # Can't reach trusted devices
```

---

## Quick Verification Commands

```bash
# Check all networks
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/rest/networkconf' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq -r '.data[] | "\(.name) (VLAN \(.vlan)): \(.ip_subnet)"'

# Check firewall rules
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/rest/firewallrule' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq -r '.data[] | select(.enabled==true) | .name'

# Check devices
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq -r '.data[] | "\(.type): \(.name // .model) (\(.ip))"'
```

---

## That's It!

Once you've done these UI steps, your network is fully configured and ready to adopt devices safely.

**Timeline:**
- Step 1-2: 2 minutes (create management VLAN + firewall rules)
- Step 3: 30 seconds (verify)
- Step 4: 2 minutes (WiFi - optional)
- Step 5: 30 seconds (move your Mac)
- Step 6: 30 seconds (test)

**Total: ~5 minutes**

Then you can start adopting switches with confidence!
