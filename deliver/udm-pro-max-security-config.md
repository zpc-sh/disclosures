# UDM Pro Max Security Configuration Guide

**Context**: Post-incident hardening after APFS logic bomb and filesystem attack

## Network Segmentation Strategy

### VLAN Design

```
VLAN 1   - Management (10.0.1.0/24)    - UDM, switches, APs, NAS management
VLAN 10  - Trusted (10.0.10.0/24)      - Primary workstations, trusted devices
VLAN 20  - IoT (10.0.20.0/24)          - Smart home, cameras, sensors
VLAN 30  - Guest (10.0.30.0/24)        - Guest WiFi, untrusted devices
VLAN 40  - Lab/Test (10.0.40.0/24)     - Testing, analysis, forensics work
VLAN 50  - DMZ (10.0.50.0/24)          - Exposed services (if any)
VLAN 99  - Quarantine (10.0.99.0/24)   - Isolated/suspicious devices
```

### Network Isolation Matrix

| From/To    | Mgmt | Trusted | IoT | Guest | Lab | DMZ | Quarantine | Internet |
|------------|------|---------|-----|-------|-----|-----|------------|----------|
| Management | ✓    | ✓       | ✓   | ✓     | ✓   | ✓   | ✓          | ✓        |
| Trusted    | →    | ✓       | →   | ✗     | ✓   | →   | ✗          | ✓        |
| IoT        | ✗    | ✗       | ✓   | ✗     | ✗   | ✗   | ✗          | → ports  |
| Guest      | ✗    | ✗       | ✗   | ✓     | ✗   | ✗   | ✗          | ✓        |
| Lab        | →    | →       | ✗   | ✗     | ✓   | ✗   | ✗          | ✓        |
| DMZ        | →    | ✗       | ✗   | ✗     | ✗   | ✓   | ✗          | ✓        |
| Quarantine | ✗    | ✗       | ✗   | ✗     | ✗   | ✗   | ✓          | ✗        |

✓ = Allow all, → = Specific rules only, ✗ = Block

---

## UniFi Network Application Configuration

### Step 1: Create Networks (Settings → Networks)

**Management Network**
```
Name: Management
VLAN ID: 1
Gateway/Subnet: 10.0.1.1/24
DHCP Range: 10.0.1.100 - 10.0.1.200
DHCP Name Server: Auto (use UDM)
Domain Name: mgmt.local
Advanced:
  - IGMP Snooping: Enabled
  - Multicast DNS: Disabled
  - mDNS: Disabled
```

**Trusted Network**
```
Name: Trusted
VLAN ID: 10
Gateway/Subnet: 10.0.10.1/24
DHCP Range: 10.0.10.100 - 10.0.10.200
DHCP Name Server: Auto
Domain Name: trusted.local
Advanced:
  - IGMP Snooping: Enabled
  - Multicast DNS: Disabled
```

**IoT Network**
```
Name: IoT
VLAN ID: 20
Gateway/Subnet: 10.0.20.1/24
DHCP Range: 10.0.20.100 - 10.0.20.200
DHCP Name Server: Auto
Domain Name: iot.local
Advanced:
  - IGMP Snooping: Enabled
  - Multicast DNS: Enabled (for HomeKit, Chromecast)
  - Client Device Isolation: Enabled
```

**Guest Network**
```
Name: Guest
VLAN ID: 30
Gateway/Subnet: 10.0.30.1/24
DHCP Range: 10.0.30.100 - 10.0.30.200
DHCP Name Server: 1.1.1.1, 8.8.8.8 (external DNS)
Domain Name: guest.local
Advanced:
  - IGMP Snooping: Enabled
  - Client Device Isolation: Enabled
  - Guest Policy: Enabled
```

**Lab/Test Network**
```
Name: Lab
VLAN ID: 40
Gateway/Subnet: 10.0.40.1/24
DHCP Range: 10.0.40.100 - 10.0.40.200
DHCP Name Server: Auto
Domain Name: lab.local
Advanced:
  - IGMP Snooping: Enabled
```

**Quarantine Network**
```
Name: Quarantine
VLAN ID: 99
Gateway/Subnet: 10.0.99.1/24
DHCP Range: 10.0.99.100 - 10.0.99.200
DHCP Name Server: Auto
Domain Name: quarantine.local
Advanced:
  - Internet Access: Disabled
  - All traffic blocked by default
```

---

## Step 2: Firewall Rules (Settings → Security → Firewall Rules)

### Management Protection Rules

**Rule 1: Block IoT to Management**
```
Action: Drop
Protocol: All
Source: IoT Network
Destination: Management Network
States: New, Established, Related
Logging: Enabled
Description: Block IoT from accessing management plane
```

**Rule 2: Block Guest to Management**
```
Action: Drop
Protocol: All
Source: Guest Network
Destination: Management Network
States: All
Logging: Enabled
Description: Block guest access to management
```

**Rule 3: Allow Trusted to Management (SSH/HTTPS only)**
```
Action: Accept
Protocol: TCP
Source: Trusted Network
Destination: Management Network
Port Group: Management (22, 443, 8443)
States: New
Logging: Enabled
Description: Allow admin access from trusted network
```

### Inter-VLAN Rules

**Rule 4: Block IoT to Trusted**
```
Action: Drop
Protocol: All
Source: IoT Network
Destination: Trusted Network
States: All
Logging: Enabled
Description: Prevent IoT lateral movement
```

**Rule 5: Allow Trusted to IoT (initiated)**
```
Action: Accept
Protocol: All
Source: Trusted Network
Destination: IoT Network
States: New, Established, Related
Logging: Disabled
Description: Allow control of IoT from trusted
```

**Rule 6: Block All to Quarantine**
```
Action: Drop
Protocol: All
Source: Any
Destination: Quarantine Network
States: All
Logging: Enabled
Description: Isolate quarantine network
```

**Rule 7: Block Quarantine to Internet**
```
Action: Drop
Protocol: All
Source: Quarantine Network
Destination: Internet
States: All
Logging: Enabled
Description: No internet for quarantined devices
```

### Multicast/Broadcast Filtering

**Rule 8: Drop Multicast Between VLANs (except mDNS where needed)**
```
Action: Drop
Protocol: UDP
Source: IoT Network
Destination: Trusted Network
Port: 5353 (mDNS)
Description: Block cross-VLAN mDNS
```

**Rule 9: Block SSDP/UPnP Cross-VLAN**
```
Action: Drop
Protocol: UDP
Source: Any
Destination: Port 1900
Description: Block SSDP discovery across VLANs
```

**Rule 10: Block NetBIOS/SMB Cross-VLAN**
```
Action: Drop
Protocol: TCP/UDP
Source: IoT, Guest
Destination: Trusted, Management
Ports: 137-139, 445
Description: Block Windows network discovery
```

---

## Step 3: Traffic Management Rules

### Settings → Security → Traffic Rules

**Rate Limiting for IoT**
```
Name: IoT Upload Limit
Network: IoT
Direction: Upload
Rate Limit: 10 Mbps
Description: Prevent IoT botnet upload attacks
```

**DPI Configuration**
```
Enable DPI: Yes
Categories to Block on Guest/IoT:
  - P2P
  - Remote Access Tools (TeamViewer, etc.)
  - Tor/VPN (optional, depending on policy)
```

---

## Step 4: IDS/IPS Configuration

### Settings → Security → Threat Management

**IPS Configuration**
```
IPS: Enabled
Mode: Detection + Prevention
Categories:
  ☑ Exploits
  ☑ Malware
  ☑ Scan Detection
  ☑ DOS
  ☑ Generic Protocol Command Decode

Suppress Common False Positives: Enabled
```

**Honeypot Detection**
```
Enabled: Yes
Action: Auto-quarantine to VLAN 99
```

---

## Step 5: Advanced Settings

### Settings → System → Advanced

**Management Access**
```
SSH: Enabled (Management VLAN only)
SSH Port: 22 (or custom)
Web Interface: HTTPS only
HTTPS Port: 443 (or custom)
Auto-backup: Enabled (to trusted NFS/SMB)
```

**DNS Configuration**
```
DNS Server: Quad9 (9.9.9.9), Cloudflare (1.1.1.1)
Local DNS Records: Configure for internal hosts
DNSSEC: Enabled
DNS Filter: Enable threat blocking
```

**NTP Configuration**
```
NTP Server: time.cloudflare.com, pool.ntp.org
Timezone: Correct timezone for logging
```

---

## Step 6: WiFi Network Configuration

### Settings → WiFi → WiFi Networks

**Trusted WiFi**
```
Name/SSID: YourNetwork-Secure
Security: WPA3-Personal (or WPA2/WPA3)
Password: Strong passphrase
Network: Trusted (VLAN 10)
WiFi Band: 5 GHz + 6 GHz preferred
Client Device Isolation: Disabled
```

**IoT WiFi**
```
Name/SSID: YourNetwork-IoT
Security: WPA2-Personal (for compatibility)
Password: Different passphrase
Network: IoT (VLAN 20)
WiFi Band: 2.4 GHz + 5 GHz
Client Device Isolation: Enabled
Hide SSID: Optional
```

**Guest WiFi**
```
Name/SSID: YourNetwork-Guest
Security: WPA2-Personal
Password: Simple guest password
Network: Guest (VLAN 30)
Guest Portal: Enabled (optional)
Guest Policy:
  - Access only for 24 hours
  - Require password every 24h
Client Device Isolation: Enabled
```

---

## Step 7: Monitoring & Logging

### Settings → System → Logs

**Enable Remote Syslog** (if you have a SIEM)
```
Remote Syslog: Enabled
Host: your-siem-server
Port: 514
Format: RFC5424
```

**Local Logging**
```
Log Level: Info
Retention: 30 days
Categories to monitor:
  - Firewall blocks
  - IPS alerts
  - Failed login attempts
  - Device connects/disconnects
```

### UniFi Network Application → Statistics

**Monitor these regularly:**
- Clients: Check for unknown devices
- DPI: Look for unusual traffic patterns
- Threats: Review IPS blocks
- Firewall: Check top blocked rules

---

## Step 8: Device Assignment

### Settings → Devices → Client Devices

**Assign Static IPs and VLANs:**
```
Critical Infrastructure:
  - UDM Pro Max: 10.0.1.1 (Management)
  - Switches: 10.0.1.10-19 (Management)
  - Access Points: 10.0.1.20-29 (Management)
  - NAS: 10.0.1.50 (Management) + 10.0.10.50 (Trusted data)

Workstations:
  - Admin Mac: 10.0.10.10 (Trusted)
  - Other devices: DHCP in appropriate VLAN

IoT Devices:
  - Smart home devices: IoT VLAN
  - Cameras: IoT VLAN (or separate camera VLAN 25)
  - Printers: IoT or Trusted depending on trust level

Forensics/Lab:
  - Test systems: Lab VLAN
```

---

## Step 9: Control Plane Protection

### UniFi OS Settings

**Access Control**
```
Settings → System → Advanced → Management
- Require complex passwords
- Enable 2FA for all admin accounts
- Limit SSH access to Management VLAN
- Disable cloud access if not needed
```

**Device Authentication**
```
Settings → System → Site
- Enable Device Authentication
- Use strong adoption passwords
- Disable auto-adopt
```

**Controller Access**
```
- Create separate admin accounts (no shared admin)
- Use least privilege (read-only accounts where possible)
- Enable audit logging
- Regular credential rotation
```

---

## Step 10: Additional Hardening

### Port Forwarding Rules
```
Minimize or eliminate port forwards
If required:
  - Forward only specific ports
  - Use non-standard ports
  - Limit source IPs where possible
  - Enable IPS on WAN
```

### UPnP/NAT-PMP
```
UPnP: Disabled (enable only if absolutely necessary)
NAT-PMP: Disabled
Reason: Prevents malware from opening ports
```

### IPv6
```
If not using IPv6:
  - Disable IPv6 entirely
If using IPv6:
  - Configure firewall rules for IPv6
  - Enable IPv6 IPS
  - Monitor DHCPv6 leases
```

---

## Multicast Filtering Deep Dive

### Problem: Multicast/Broadcast Storm Prevention

**IGMP Snooping** (per-VLAN)
```
Management: Enabled (prevents multicast floods)
Trusted: Enabled
IoT: Enabled (but allow mDNS for HomeKit/Chromecast)
Guest: Enabled + strict isolation
```

**mDNS Repeater Configuration**
```
Purpose: Allow IoT device discovery from Trusted network
Settings → Services → mDNS
  - Enable mDNS
  - Allow between: Trusted ↔ IoT (one direction only)
  - Do NOT allow: Guest, Quarantine
```

**Specific Multicast Blocks**
```
224.0.0.0/4 - All multicast (except allowed protocols)
239.255.255.250 - SSDP
224.0.0.251 - mDNS (except where explicitly allowed)
224.0.0.252 - LLMNR
255.255.255.255 - Broadcast
```

**Traffic Rules**
```
Settings → Security → Traffic Rules
- Create rule: Block all multicast except IGMP
- Exception: Allow mDNS on IoT (port 5353)
- Exception: Allow IGMP queries (protocol 2)
```

---

## Testing & Validation

### Firewall Rule Testing
```bash
# From Trusted VLAN
ping 10.0.20.1        # Should work (IoT gateway)
ping 10.0.20.100      # Should work (IoT device)
ssh admin@10.0.1.1    # Should work (UDM management)

# From IoT VLAN
ping 10.0.10.100      # Should FAIL (blocked by firewall)
ssh admin@10.0.1.1    # Should FAIL (no management access)
ping 8.8.8.8          # Should work (internet access)

# From Guest VLAN
ping 10.0.10.1        # Should FAIL (no internal access)
ping 10.0.20.1        # Should FAIL (no IoT access)
ping 8.8.8.8          # Should work (internet only)
```

### Monitoring Commands (via SSH to UDM)
```bash
# Show active connections
netstat -an | grep ESTABLISHED

# Show firewall rules
iptables -L -v -n

# Show IPS alerts
tail -f /var/log/suricata/fast.log

# Show DHCP leases
cat /var/lib/dhcp/dhcpd.leases

# Monitor traffic
tcpdump -i br0 -nn
```

---

## Maintenance Schedule

**Daily:**
- Check IPS alerts
- Review unusual traffic patterns
- Check for unknown devices

**Weekly:**
- Review firewall logs
- Update firmware if available
- Verify backups

**Monthly:**
- Audit admin accounts
- Review and update firewall rules
- Test failover/backup procedures
- Rotate credentials

---

## Emergency Procedures

### Quarantine a Compromised Device
```
1. UniFi Network → Clients
2. Find device by MAC/IP
3. Edit → Network → Change to "Quarantine" (VLAN 99)
4. Block device (optional full block)
5. Document incident
```

### Full Network Lockdown
```
1. Enable "Block All" firewall rule at top
2. Whitelist only critical management access
3. Investigate incident
4. Restore rules after remediation
```

### Recovery from Attack
```
1. Isolate affected VLANs
2. Review firewall logs for lateral movement
3. Check IPS logs for exploitation attempts
4. Capture forensics data before remediation
5. Rebuild/reimage compromised systems
6. Update firewall rules based on lessons learned
```

---

## Key Security Principles Applied

1. **Least Privilege**: Each VLAN has minimum required access
2. **Defense in Depth**: Multiple layers (firewall + IPS + isolation)
3. **Zero Trust**: IoT and Guest are untrusted by default
4. **Network Segmentation**: Limits lateral movement
5. **Monitoring**: Comprehensive logging and alerting
6. **Control Plane Protection**: Management network is heavily restricted
7. **Fail Secure**: Default deny policies

---

## References & Resources

- [UniFi Network Application Documentation](https://help.ui.com/hc/en-us/categories/200320654-UniFi-Network)
- [UDM Pro Max Specs](https://store.ui.com/us/en/products/udm-pro-max)
- [Suricata IPS Rules](https://docs.suricata.io/)
- NIST Network Segmentation Guide
- Your incident reports: `~/workwork/ROOT-CAUSE-ANALYSIS-FILESYSTEM-BOMB.md`

---

**Configuration Status**: Ready for implementation
**Last Updated**: 2025-10-13 (Post-incident hardening)
**Risk Level**: High (post-attack recovery) → Medium (after implementation)
