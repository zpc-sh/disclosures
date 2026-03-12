# UDM Pro Max Manual Configuration Guide
**Post-Incident Security Hardening**

## Quick Start: Web UI Configuration

Access your UDM Pro Max at: **https://192.168.1.1** or **https://unifi.ui.com**

---

## Phase 1: Create Network VLANs

Navigate to: **Settings → Networks → Create New Network**

### Network 1: Management
```
Name: Management
VLAN ID: 1
Gateway/Subnet: 10.0.1.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.1.100 - 10.0.1.200
  DNS: Auto
Domain Name: mgmt.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS (mDNS)
  ☐ IPv6
```

### Network 2: Trusted
```
Name: Trusted
VLAN ID: 10
Gateway/Subnet: 10.0.10.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.10.100 - 10.0.10.200
  DNS: Auto
Domain Name: trusted.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS
  ☐ IPv6
```

### Network 3: IoT
```
Name: IoT
VLAN ID: 20
Gateway/Subnet: 10.0.20.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.20.100 - 10.0.20.200
  DNS: Auto
Domain Name: iot.local

Advanced Settings:
  ☑ IGMP Snooping
  ☑ Multicast DNS (for HomeKit, Chromecast)
  ☐ IPv6
  ☑ Client Device Isolation (optional - prevents IoT devices from talking to each other)
```

### Network 4: Guest
```
Name: Guest
VLAN ID: 30
Gateway/Subnet: 10.0.30.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.30.100 - 10.0.30.200
  DNS: 1.1.1.1, 8.8.8.8 (external DNS, not your UDM)
Domain Name: guest.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS
  ☐ IPv6
  ☑ Client Device Isolation
  ☑ Guest Policy (limit access duration)
```

### Network 5: Lab
```
Name: Lab
VLAN ID: 40
Gateway/Subnet: 10.0.40.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.40.100 - 10.0.40.200
  DNS: Auto
Domain Name: lab.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS
  ☐ IPv6
```

### Network 6: Device-Testing
```
Name: Device-Testing
VLAN ID: 98
Gateway/Subnet: 10.0.98.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.98.100 - 10.0.98.200
  DNS: Auto
Domain Name: testing.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS
  ☐ IPv6

Purpose: For testing old/adopted devices before moving to production
```

### Network 7: Quarantine
```
Name: Quarantine
VLAN ID: 99
Gateway/Subnet: 10.0.99.1/24
DHCP:
  ☑ DHCP Enabled
  Range: 10.0.99.100 - 10.0.99.200
  DNS: Auto (or none)
Domain Name: quarantine.local

Advanced Settings:
  ☑ IGMP Snooping
  ☐ Multicast DNS
  ☐ IPv6
  ☐ Internet Access (DISABLE this)

Purpose: Complete isolation for compromised/suspicious devices
```

**Save each network before creating the next one.**

---

## Phase 2: Firewall Rules

Navigate to: **Settings → Security → Firewall Rules**

Create rules in this **exact order** (order matters!):

### Rule 1: Block IoT → Management
```
Rule Type: LAN Local
Description: Block IoT from Management
Action: Drop
States: All
Protocol: All
Source:
  Network: IoT (VLAN 20)
Destination:
  Network: Management (VLAN 1)
☑ Logging Enabled
Priority: Move to TOP
```

### Rule 2: Block Guest → Management
```
Rule Type: LAN Local
Description: Block Guest from Management
Action: Drop
States: All
Protocol: All
Source:
  Network: Guest (VLAN 30)
Destination:
  Network: Management (VLAN 1)
☑ Logging Enabled
```

### Rule 3: Block IoT → Trusted
```
Rule Type: LAN In
Description: Block IoT from Trusted
Action: Drop
States: All
Protocol: All
Source:
  Network: IoT (VLAN 20)
Destination:
  Network: Trusted (VLAN 10)
☑ Logging Enabled
```

### Rule 4: Block Guest → Trusted
```
Rule Type: LAN In
Description: Block Guest from Trusted
Action: Drop
States: All
Protocol: All
Source:
  Network: Guest (VLAN 30)
Destination:
  Network: Trusted (VLAN 10)
☑ Logging Enabled
```

### Rule 5: Block Guest → IoT
```
Rule Type: LAN In
Description: Block Guest from IoT
Action: Drop
States: All
Protocol: All
Source:
  Network: Guest (VLAN 30)
Destination:
  Network: IoT (VLAN 20)
☑ Logging Enabled
```

### Rule 6: Block All → Quarantine
```
Rule Type: LAN In
Description: Block all access to Quarantine
Action: Drop
States: All
Protocol: All
Source:
  Type: Network
  Network: Any
Destination:
  Network: Quarantine (VLAN 99)
☑ Logging Enabled
```

### Rule 7: Block Quarantine → All
```
Rule Type: LAN Out
Description: Block Quarantine from everything
Action: Drop
States: All
Protocol: All
Source:
  Network: Quarantine (VLAN 99)
Destination:
  Type: Any
☑ Logging Enabled
```

### Rule 8: Allow Trusted → Management (SSH/HTTPS only)
```
Rule Type: LAN Local
Description: Allow admin access from Trusted
Action: Accept
States: New
Protocol: TCP
Source:
  Network: Trusted (VLAN 10)
Destination:
  Network: Management (VLAN 1)
Destination Port: 22,443,8443
☑ Logging Enabled

Note: Place this AFTER the block rules
```

### Rule 9: Block mDNS Cross-VLAN (except IoT)
```
Rule Type: LAN In
Description: Block mDNS between VLANs
Action: Drop
Protocol: UDP
Source:
  Network: Any (except IoT if you need cross-VLAN discovery)
Destination Port: 5353
☑ Logging Enabled
```

### Rule 10: Block SSDP/UPnP Discovery
```
Rule Type: LAN In
Description: Block SSDP cross-VLAN
Action: Drop
Protocol: UDP
Source:
  Network: Any
Destination Port: 1900
☑ Logging Enabled
```

### Rule 11: Block SMB/NetBIOS from Untrusted
```
Rule Type: LAN In
Description: Block Windows discovery from IoT/Guest
Action: Drop
Protocol: All
Source:
  Network Type: Multiple
  Networks: IoT, Guest
Destination:
  Network Type: Multiple
  Networks: Trusted, Management
Destination Port: 137,138,139,445
☑ Logging Enabled
```

**Important**: After creating all rules, drag them in the UI to ensure block rules are **above** allow rules.

---

## Phase 3: Traffic & Threat Management

### Enable IPS/IDS

Navigate to: **Settings → Security → Threat Management**

```
IPS:
  ☑ Enable IPS
  Mode: Detection and Prevention

Categories (Select All):
  ☑ Exploits
  ☑ Malware Communication
  ☑ Scan Detection
  ☑ Denial of Service
  ☑ Generic Protocol Command Decode
  ☑ Reputation-Based Threats

Advanced:
  ☑ Suppress Common False Positives
  ☑ Log All Events
```

### Honeypot (Optional but Recommended)
```
☑ Enable Honeypot
Action: Auto-Quarantine (move to VLAN 99)
```

### Traffic Rules

Navigate to: **Settings → Security → Traffic Rules**

**Rate Limit IoT Upload** (Prevent botnet attacks)
```
Name: IoT Upload Limit
Network: IoT
Direction: Upload
Rate Limit: 10 Mbps (adjust based on your needs)
Description: Prevent IoT botnet upload attacks
```

### Deep Packet Inspection

Navigate to: **Settings → System → Advanced → Deep Packet Inspection**

```
☑ Enable DPI

For Guest & IoT Networks:
  Block Categories:
    ☑ P2P File Sharing
    ☑ Tor/VPN (optional, if you want to enforce)
    ☑ Remote Access Tools (TeamViewer, AnyDesk, etc.)
```

---

## Phase 4: WiFi Networks

Navigate to: **Settings → WiFi → Create New Network**

### WiFi 1: Trusted Network
```
Name/SSID: [YourName]-Secure
Password: [Strong 20+ char passphrase]
Security: WPA3-Personal (or WPA2/WPA3 Mixed if you have older devices)
Network: Trusted (VLAN 10)
WiFi Band: 5 GHz Preferred (or 5/6 GHz if you have WiFi 6E)
Advanced:
  ☐ Client Device Isolation
  ☑ Fast Roaming (802.11r)
  ☑ Band Steering
  Minimum RSSI: -75 dBm (forces roaming to closer APs)
```

### WiFi 2: IoT Network
```
Name/SSID: [YourName]-IoT
Password: [Different passphrase]
Security: WPA2-Personal (for compatibility with dumb IoT devices)
Network: IoT (VLAN 20)
WiFi Band: 2.4 GHz + 5 GHz (many IoT devices need 2.4 GHz)
Advanced:
  ☑ Client Device Isolation (prevents IoT devices from talking to each other)
  ☐ Fast Roaming (IoT devices don't move)
  ☑ Band Steering
  ☐ Hide SSID (optional security through obscurity)
```

### WiFi 3: Guest Network
```
Name/SSID: [YourName]-Guest
Password: [Simple guest password]
Security: WPA2-Personal
Network: Guest (VLAN 30)
WiFi Band: 5 GHz Preferred
Guest Policy:
  ☑ Enable Guest Policy
  Access Duration: 24 hours
  ☑ Require password every 24 hours
Advanced:
  ☑ Client Device Isolation
  ☑ Guest Portal (optional - can require acceptance)
```

---

## Phase 5: Device Configuration

### Set Static IPs for Infrastructure

Navigate to: **UniFi Devices → [Device] → Settings**

**UDM Pro Max**
```
Network: Management (VLAN 1)
IP Configuration: Static
IP Address: 10.0.1.1
```

**USW Pro XG 10 PoE (Your Switch)**
```
Network: Management (VLAN 1)
IP Configuration: Static
IP Address: 10.0.1.10
```

**Future Access Points** (when adopted)
```
Network: Management (VLAN 1)
IP Configuration: Static
IP Range: 10.0.1.20 - 10.0.1.29
```

**NAS/Critical Servers**
```
Management Interface: 10.0.1.50 (VLAN 1)
Data Interface: 10.0.10.50 (VLAN 10) - if dual-homed
```

---

## Phase 6: System Hardening

### Management Access

Navigate to: **Settings → System → Advanced**

**Device Authentication**
```
☑ Require Device Authentication
Adoption Password: [Strong password - save in password manager]
☐ Enable Auto-Adopt (CRITICAL: Keep this OFF for security)
```

**SSH Access**
```
☑ Enable SSH
Port: 22 (or custom port like 2222)
☑ Disable Password Authentication (after setting up SSH keys)
Allowed Networks: Management VLAN only
```

**Web Interface**
```
☑ HTTPS Only (disable HTTP redirect)
Port: 443 (or custom)
☑ Require Complex Passwords
☑ Enable 2FA for All Accounts
```

### Backup Configuration

Navigate to: **Settings → System → Backups**

```
Auto Backup:
  ☑ Enable Auto Backup
  Frequency: Daily
  Retention: 7 days
  Location: NAS or external storage (configure SMB/NFS)

Backup Path: \\10.0.1.50\backups\udm-pro-max\
```

### Logging

Navigate to: **Settings → System → Logs**

**Remote Syslog** (if you have a SIEM/log server)
```
☑ Enable Remote Syslog
Host: [Your syslog server IP]
Port: 514
Format: RFC5424
```

**Local Logging**
```
Log Level: Info
Retention: 30 days (max)
Categories:
  ☑ Firewall
  ☑ IPS/IDS
  ☑ Authentication
  ☑ System Events
```

### DNS Configuration

Navigate to: **Settings → Internet → WAN**

```
DNS Server 1: 9.9.9.9 (Quad9 - security focused)
DNS Server 2: 1.1.1.1 (Cloudflare)
☑ DNSSEC Validation
☑ DNS Threat Blocking (if available)
```

### NTP Configuration

Navigate to: **Settings → System → General**

```
Timezone: [Your timezone]
NTP Server: time.cloudflare.com
```

---

## Phase 7: Testing & Validation

### Test Firewall Rules

From a device on **Trusted VLAN**:
```bash
# Should WORK
ping 10.0.1.1        # UDM gateway
ping 10.0.10.1       # Trusted gateway
ping 10.0.20.1       # IoT gateway
ssh admin@10.0.1.1   # SSH to UDM (if you're on trusted)

# Should WORK
ping 8.8.8.8         # Internet
curl -I https://google.com
```

From a device on **IoT VLAN** (connect phone to IoT WiFi to test):
```bash
# Should FAIL (blocked by firewall)
ping 10.0.1.1        # Can't reach management
ping 10.0.10.100     # Can't reach trusted devices

# Should WORK
ping 8.8.8.8         # Internet works
curl -I https://google.com
```

From a device on **Guest VLAN**:
```bash
# Should FAIL
ping 10.0.1.1        # No internal access
ping 10.0.10.1       # No internal access
ping 10.0.20.1       # No internal access

# Should WORK
ping 8.8.8.8         # Internet only
curl -I https://google.com
```

### Monitor Firewall Logs

Navigate to: **Activity → Events → All Events**

Filter by: **Firewall Rules**

Look for:
- Blocked connections (these are working as intended)
- Unexpected allowed connections
- High volume blocks from specific devices (could indicate compromise)

### Check IPS Alerts

Navigate to: **Activity → Events → All Events**

Filter by: **IPS**

Look for:
- Exploit attempts
- Malware communication
- Port scanning
- Any alerts from your clean devices (shouldn't be any)

---

## Ongoing Maintenance

### Daily (First Week)
- Check IPS alerts
- Review firewall blocks
- Look for unknown devices
- Verify no unexpected reboots

### Weekly
- Update firmware (Settings → System → Updates)
- Review DPI statistics
- Check for new device adoptions
- Verify backups are running

### Monthly
- Audit user accounts and passwords
- Review and update firewall rules
- Test disaster recovery
- Rotate credentials
- Check for UniFi security advisories

---

## Emergency Procedures

### Quarantine a Device
```
1. UniFi Network → Clients → [Find Device]
2. Click device → Settings
3. Network → Change to "Quarantine" (VLAN 99)
4. Apply
5. Device is now completely isolated
```

### Block a Device Completely
```
1. UniFi Network → Clients → [Find Device]
2. Click device → Block Device
3. Confirm
4. Device can no longer connect at all
```

### Emergency Network Lockdown
```
1. Settings → Security → Firewall Rules
2. Create new rule at TOP:
   - Action: Drop
   - Protocol: All
   - Source: Any
   - Destination: Any
3. Then create exceptions below for critical management
```

---

## What You've Built

After completing this configuration, you have:

✅ **7 Isolated Network Segments**
- Management, Trusted, IoT, Guest, Lab, Testing, Quarantine

✅ **Defense in Depth**
- Firewall rules preventing lateral movement
- IPS/IDS detecting threats
- Traffic shaping preventing botnet behavior
- DPI blocking malicious categories

✅ **Control Plane Protection**
- Management network isolated
- Strong authentication required
- SSH key-only access
- 2FA enabled

✅ **Monitoring & Logging**
- All security events logged
- Automated backups
- Threat detection enabled
- Incident response procedures ready

✅ **Safe Device Adoption Process**
- Testing VLAN for new devices
- Quarantine VLAN for compromised devices
- Monitoring procedures

---

## Network Diagram

```
Internet
   |
[UDM Pro Max] (10.0.1.1)
   |
   +-- VLAN 1  (Management)   10.0.1.0/24   - Infrastructure only
   +-- VLAN 10 (Trusted)      10.0.10.0/24  - Your devices
   +-- VLAN 20 (IoT)          10.0.20.0/24  - Smart home (isolated)
   +-- VLAN 30 (Guest)        10.0.30.0/24  - Guests (internet only)
   +-- VLAN 40 (Lab)          10.0.40.0/24  - Testing/forensics
   +-- VLAN 98 (Testing)      10.0.98.0/24  - Device adoption staging
   +-- VLAN 99 (Quarantine)   10.0.99.0/24  - Isolated/compromised
```

---

## Configuration Checklist

Print this and check off as you complete:

- [ ] Created Management VLAN (1)
- [ ] Created Trusted VLAN (10)
- [ ] Created IoT VLAN (20)
- [ ] Created Guest VLAN (30)
- [ ] Created Lab VLAN (40)
- [ ] Created Testing VLAN (98)
- [ ] Created Quarantine VLAN (99)
- [ ] Created all 11 firewall rules
- [ ] Enabled IPS/IDS
- [ ] Configured traffic rules
- [ ] Created Trusted WiFi
- [ ] Created IoT WiFi
- [ ] Created Guest WiFi
- [ ] Set static IP for UDM
- [ ] Set static IP for switch
- [ ] Configured SSH access
- [ ] Enabled 2FA
- [ ] Disabled auto-adopt
- [ ] Configured backups
- [ ] Set up remote logging
- [ ] Tested Trusted VLAN connectivity
- [ ] Tested IoT VLAN isolation
- [ ] Tested Guest VLAN isolation
- [ ] Verified IPS is working
- [ ] Documented configuration

---

**Configuration Complete!**

You now have a hardened, segmented network ready for secure operation.

**Important**: Document your admin credentials securely. Store backup configuration offline. Test disaster recovery procedures.

**Last Updated**: 2025-10-13
**Created For**: Post-incident recovery from complete UDM compromise
**Reference**: See `~/workwork/device-adoption-security-protocol.md` for safe device adoption
