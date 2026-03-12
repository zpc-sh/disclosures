# WAN Security Analysis - 98.97.38.180
**Date**: 2025-10-13
**Context**: Post-compromise recovery, investigating potential ongoing threat

---

## Network Topology

```
Internet (98.97.38.180 - Public IP)
    ↓
ISP/Upstream Router (192.168.12.x)
    ↓
UDM Pro Max (192.168.1.1) - NEW CLEAN DEVICE
    ↓
Your Network (10.0.x.x VLANs)
```

**Configuration**:
- You are **double-NATted** (behind an upstream router at 192.168.12.x)
- Your UDM has WAN IP: 192.168.12.87 (private/RFC1918)
- True public IP: 98.97.38.180

---

## Port Scan Results

### From External (Internet → 98.97.38.180)

```
PORT     STATE
21/tcp   filtered (FTP)
22/tcp   filtered (SSH)
23/tcp   filtered (Telnet)
25/tcp   filtered (SMTP)
53/tcp   filtered (DNS)
80/tcp   filtered (HTTP)
443/tcp  filtered (HTTPS)
445/tcp  filtered (SMB)
3389/tcp filtered (RDP)
3478/tcp filtered (STUN - VoIP/WebRTC)
8080/tcp filtered (HTTP-Proxy)
8291/tcp filtered (MikroTik Winbox)
8443/tcp filtered (HTTPS-Alt)
8888/tcp filtered (HTTP-Alt)
```

**Analysis**:
- All ports show as **"filtered"** = firewall present
- No ports showing as **"open"** = nothing directly accessible
- This is **GOOD** for your new UDM

---

## UDM Pro Max Configuration Check

### Port Forwards: **NONE** ✅
- No port forwarding rules configured
- No services exposed to WAN
- Clean configuration

### Firewall Rules: **DEFAULT ONLY** ✅
- No custom WAN rules yet
- Default deny all inbound
- This is correct and secure

### UPnP/NAT-PMP Status: **Unknown** ⚠️
Need to check:
```bash
# Check UPnP status via API or UI
Settings → Internet → WAN → Advanced
```

**Recommendation**: **DISABLE UPnP** immediately if enabled. UPnP allows malware to open ports automatically.

---

## Concerns About Upstream Router (192.168.12.x)

### The "They Might Get In" Scenario

You mentioned the old UDM Pro had UI redressing, which indicates:
- Kernel-level compromise
- Persistent malware
- Possible lateral movement to other devices

**If attackers compromised the upstream router at 192.168.12.x, they could:**

1. **Port Forward Through It**
   - Expose your new UDM to Internet without you knowing
   - Bypass your UDM firewall entirely

2. **MiTM Your Traffic**
   - Intercept all Internet traffic
   - Inject malicious firmware updates
   - Steal credentials

3. **Access Your Internal Network**
   - If router has access to 192.168.12.0/24, they can scan for your UDM
   - Could attack your UDM management interface (if accessible on 192.168.12.87)

4. **DNS Hijacking**
   - Redirect update servers to malicious hosts
   - Serve fake firmware updates

---

## Testing Upstream Router Security

### Test 1: Check Who Controls 192.168.12.x Router

```bash
# From your Mac
# Find the gateway
netstat -rn | grep default

# It should be 192.168.1.1 (your UDM)
# But the UDM's gateway is 192.168.12.x (something)
```

**Questions:**
1. Do you own/control the 192.168.12.x router?
2. Is it your ISP's equipment?
3. Is it a compromised device from the incident?

### Test 2: Try to Access Upstream Router

```bash
# Try common router IPs
curl -k https://192.168.12.1 -m 5
curl -k http://192.168.12.1 -m 5

# Try your UDM's gateway
curl -k http://192.168.12.1 -m 5
```

### Test 3: Check for Port Forwards on Upstream

```bash
# From external network (use phone hotspot or VPS)
nmap -Pn -p 80,443,22,8443 98.97.38.180

# Try to access your UDM web interface from Internet
curl -k https://98.97.38.180:443 -m 5
```

If you can reach your UDM from the Internet, **the upstream router has port forwards**.

---

## Recommended Actions

### Immediate (Right Now)

1. **Verify UPnP is Disabled on UDM**
   ```
   Settings → Internet → WAN1 → Advanced
   ☐ Enable UPnP (must be UNCHECKED)
   ```

2. **Check UDM Management Access**
   ```bash
   # Via API
   curl -sk 'https://192.168.1.1/proxy/network/api/s/default/rest/setting/mgmt' \
     -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | jq
   ```

3. **Disable Remote Management**
   ```
   Settings → System → Advanced
   ☐ Enable Remote Access
   ☐ Enable SSH from WAN
   ```

4. **Enable WAN Firewall Logging**
   ```
   Settings → Security → Firewall Rules
   Create rule: "Log All WAN Attempts"
   - Type: WAN In
   - Action: Drop
   - Protocol: All
   - Source: Any
   - Destination: Any
   - Logging: ENABLED
   ```

### Short Term (Next 24 Hours)

5. **Identify Upstream Router**
   - Physically locate the device
   - Verify who owns/controls it
   - Check for signs of compromise (unusual LEDs, heat, traffic)

6. **Factory Reset Upstream Router (If You Own It)**
   - If it's your device, factory reset it
   - Change default credentials
   - Disable remote management
   - Update firmware

7. **Request New Public IP from ISP**
   - If attackers know your current IP (98.97.38.180)
   - Call ISP and request IP rotation
   - May require modem reboot

8. **Monitor UDM for Scan Attempts**
   ```bash
   # Check IPS logs
   Settings → Activity → Events → Filter: IPS

   # Look for:
   - Port scans from 192.168.12.x network
   - Authentication attempts
   - Exploit attempts
   ```

### Medium Term (This Week)

9. **Eliminate Double NAT (If Possible)**

   **Option A: Bridge Mode on Upstream Router**
   ```
   - Put upstream router in bridge/passthrough mode
   - Give UDM the true public IP (98.97.38.180)
   - Benefit: Full control over WAN security
   ```

   **Option B: DMZ Mode** (Less ideal)
   ```
   - Set UDM (192.168.12.87) as DMZ on upstream router
   - All traffic forwarded to UDM
   - Still vulnerable if upstream router compromised
   ```

   **Option C: Replace Upstream Router**
   ```
   - Connect UDM directly to ISP modem
   - Eliminate untrusted middlebox
   - May require ISP cooperation
   ```

10. **Set Up VPN for Remote Access**
    ```
    Instead of exposing management interfaces:
    - Use WireGuard VPN on UDM (already configured?)
    - Only allow VPN connections from Internet
    - Access management through VPN tunnel
    ```

---

## Attack Indicators to Monitor

### On UDM (via Logs)

**Suspicious IPS Events**:
```bash
# Check for scans from upstream network
grep "192.168.12" /var/log/suricata/fast.log

# Look for:
- Port scanning
- Brute force attempts
- Exploit attempts (CVE patterns)
- Command injection attempts
```

**Unexpected Connections**:
```bash
# Check active connections from 192.168.12.x
netstat -an | grep "192.168.12"

# Should only be:
# - Your Mac's connection to UDM (if routing through it)
# - UDM's connection to gateway
#
# Should NOT be:
# - Random ports being probed
# - Connections to UDM services (22, 443, 8443)
```

**Configuration Changes**:
```bash
# Monitor UDM settings for unauthorized changes
# Settings → System → Activity Log
# Look for:
# - New port forwards
# - Firewall rule changes
# - New user accounts
# - Firmware updates
```

### On Upstream Router (If Accessible)

- Check port forwarding table
- Check connected devices (should only be your UDM)
- Check remote management status (should be disabled)
- Check firewall logs for scan attempts

---

## If You Don't Control Upstream Router

### Scenario: It's ISP Equipment

**Risks**:
- ISP routers often have default credentials
- Often outdated firmware with known CVEs
- Remote management usually enabled by ISP

**Mitigation**:
1. Request ISP put modem in bridge mode
2. Connect UDM directly to bridge modem
3. Get public IP on UDM directly
4. Eliminate ISP router from chain

### Scenario: It's Compromised from Incident

**High Risk** - Treat as hostile:

1. **Immediate Isolation**
   - Physically disconnect upstream router
   - Use backup Internet (phone hotspot, etc.)
   - Do NOT reconnect until cleaned

2. **Forensics**
   - Capture firmware dump before reset
   - Check for modified firmware
   - Document configuration for evidence

3. **Replacement**
   - Do not re-use the device
   - Replace with new, verified equipment
   - Consider it permanently compromised

---

## Network Segmentation Defense

Even if upstream router is compromised, proper UDM configuration limits damage:

### Current Protection (After Following Guides)

✅ **Management VLAN Isolated**
- Only accessible from Trusted VLAN
- Upstream router can't reach 10.0.1.x

✅ **No Port Forwards**
- Upstream can't directly attack internal services

✅ **IPS/IDS Enabled**
- Will detect and block exploit attempts

✅ **Strong Firewall Rules**
- Default deny all
- Only specific flows allowed

### Additional Hardening for Hostile Upstream

**WAN Firewall Rules** (Add these):

```
Rule 1: Drop All WAN Management Access
- Type: WAN Local
- Action: Drop
- Protocol: All
- Source: Any
- Destination: Port 22,443,8443
- Logging: Enabled

Rule 2: Rate Limit WAN Connections
- Type: WAN In
- Action: Drop
- Connection State: New
- Connection Rate: >100/sec
- Logging: Enabled

Rule 3: Block RFC1918 from WAN (should never see these on public Internet)
- Type: WAN In
- Action: Drop
- Source: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- Logging: Enabled
```

---

## Testing Checklist

- [ ] Verify UPnP disabled on UDM
- [ ] Verify remote management disabled on UDM
- [ ] Test if UDM accessible from Internet (should fail)
- [ ] Identify upstream router model/owner
- [ ] Check upstream router for port forwards
- [ ] Enable WAN firewall logging on UDM
- [ ] Monitor IPS alerts for 24 hours
- [ ] Check UDM logs for suspicious 192.168.12.x traffic
- [ ] Request ISP put modem in bridge mode (if applicable)
- [ ] Set up VPN for remote access instead of exposed ports

---

## Quick Commands Reference

### Check UPnP Status
```bash
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/rest/setting/mgmt' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | jq '.data[] | {upnp: .upnp_enabled}'
```

### Disable UPnP via API
```bash
# Get current settings
CURRENT=$(curl -sk 'https://192.168.1.1/proxy/network/api/s/default/rest/setting/mgmt' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | jq '.data[0]')

# Disable UPnP
echo $CURRENT | jq '.upnp_enabled = false' | \
curl -sk -X PUT 'https://192.168.1.1/proxy/network/api/s/default/rest/setting/mgmt/[ID]' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' \
  -H 'Content-Type: application/json' \
  -d @-
```

### Monitor WAN Traffic
```bash
# SSH to UDM
ssh admin@192.168.1.1

# Watch for WAN attacks
tcpdump -i eth4 -nn 'port 443 or port 22 or port 8443'

# Check IPS
tail -f /var/log/suricata/fast.log | grep -i "WAN"
```

---

## Current Status Summary

✅ **Good News**:
- New UDM Pro Max is clean
- No port forwards configured
- All WAN ports filtered (firewall working)
- No services directly exposed to Internet

⚠️ **Concerns**:
- Double-NAT through potentially compromised upstream router
- Attackers may have control of 192.168.12.x network
- Can't see/control upstream router configuration
- Upstream could forward ports without your knowledge

🚨 **Critical Next Steps**:
1. Identify and verify control of upstream router
2. Disable UPnP on UDM
3. Monitor for attacks from 192.168.12.x network
4. Work to eliminate double-NAT (bridge mode or replace router)

---

**Recommendation**: Given the severity of the previous compromise (UI redressing = very sophisticated attack), I would treat the entire 192.168.12.x network as **hostile** until proven otherwise.

**Safest approach**: Get a new modem/router from ISP, connect UDM directly, get fresh public IP, build new network from scratch.

**Last Updated**: 2025-10-13
**Next Review**: After upstream router investigation
