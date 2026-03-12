# Device Adoption Security Protocol
**Context**: Post-compromise recovery - Old UDM Pro was fully infected

## CRITICAL DECISION: Should You Adopt Old Devices?

### HIGH RISK Devices (DO NOT ADOPT without factory reset):
- **Old UDM Pro** - COMPLETELY COMPROMISED, do not connect
- **Switches that had SSH/management access** - Potential persistent backdoors
- **Access Points with custom firmware or SSH enabled** - Could be compromised
- **Any device with unusual behavior pre-incident** - Suspicious until proven clean

### MEDIUM RISK Devices (Adopt with caution):
- **Switches that were managed-only** - Likely safe if no SSH/custom config
- **Basic Access Points** - Less attack surface, but inspect logs first
- **PoE switches** - Limited functionality, probably safe

### LOW RISK (Can adopt after inspection):
- **Brand new UniFi devices** - Never deployed
- **Devices that were physically isolated** - Not on compromised network

---

## Safe Device Adoption Procedure

### Phase 1: Pre-Adoption Assessment

**Step 1: Physical Inspection**
```
- Check for physical tampering (broken seals, scratches)
- Verify device model/serial matches your inventory
- Look for unauthorized hardware modifications
```

**Step 2: Network Isolation**
```
- Connect device to ISOLATED port on new UDM
- Create temporary "Device Testing" VLAN (VLAN 98)
- Block ALL traffic except UDM management
- Enable full packet capture on this VLAN
```

**Step 3: Firmware Verification**
```
Before adoption:
1. Check current firmware version
2. Compare hash against known-good UniFi firmware
3. Look for unusual firmware dates/versions
4. Check for custom/modified firmware signatures
```

---

## Phase 2: Factory Reset Procedure

### For Switches (USW Series)

**Method 1: Physical Reset Button**
```bash
1. Power on the switch
2. Wait for it to boot completely (all LEDs solid)
3. Press and hold reset button for 10+ seconds
4. All LEDs will blink - indicates reset in progress
5. Release button when LEDs turn off
6. Wait 5 minutes for full reset
7. Device should show as "pending adoption"
```

**Method 2: SSH Reset (if you trust the device enough)**
```bash
# ONLY if device is isolated and you trust it somewhat
ssh admin@<switch-ip>
set-default
reboot
```

### For Access Points (UAP Series)

**Physical Reset**
```bash
1. Power on AP
2. Wait for LED to turn white (ready state)
3. Press and hold reset button for 10 seconds
4. LED will flash rapidly, then turn off
5. Release button
6. Wait for AP to reboot (LED will cycle through colors)
7. AP should show as "pending adoption" with white LED
```

### For UniFi Protect Cameras (If you have any)

**Reset Procedure**
```bash
1. Power on camera
2. Wait 60 seconds for full boot
3. Press and hold reset button for 10 seconds
4. LED will blink amber/white
5. Release when LED turns solid white
6. Camera will reboot to factory state
```

---

## Phase 3: Secure Adoption Process

### Step 1: Adopt in Quarantine VLAN

**Create Device Testing VLAN (if not already created)**
```
Settings → Networks → Create Network
Name: Device-Testing
VLAN ID: 98
Gateway: 10.0.98.1/24
DHCP Range: 10.0.98.100-200
Internet Access: ENABLED (for firmware downloads)
Firewall Rules:
  - Allow: Device → Internet (ports 80, 443 only)
  - Allow: Device → UDM (ports 8080, 8443 for adoption)
  - Block: Device → All other internal networks
  - Block: All other devices → Device
```

**Adopt Device**
```
1. UniFi Network → Devices → Pending Devices
2. Find your device (verify by MAC address)
3. Click "Adopt"
4. Let device adopt and download firmware
5. DO NOT move to production VLAN yet
```

### Step 2: Post-Adoption Security Check

**Wait 24-48 hours and monitor for:**

**Suspicious Network Behavior**
```
- Unexpected outbound connections
- Port scanning behavior
- Unusual DNS queries (C2 domains, DGA patterns)
- Excessive broadcast/multicast traffic
- Connections to known malicious IPs
```

**Check via UniFi Controller**
```
1. Settings → Security → Threat Management
   - Review IPS alerts for this device
2. Statistics → DPI
   - Check traffic categories from device
   - Look for P2P, Tor, VPN tunneling
3. Statistics → Clients → [Your Device]
   - Review all connection attempts
   - Check Top Applications
```

**Check via SSH (if needed)**
```bash
# SSH to UDM Pro Max
ssh admin@<udm-ip>

# Check traffic from testing VLAN
tcpdump -i br98 -nn -v

# Check for unusual connections
netstat -anp | grep <device-ip>

# Review system logs
tail -f /var/log/messages | grep <device-mac>
```

### Step 3: Firmware Update & Verification

**Force Latest Firmware**
```
1. UniFi Network → Devices → [Your Device]
2. Settings → Manage Device → Update Firmware
3. Select latest stable version
4. Apply and wait for reboot
5. Verify firmware version matches UniFi release notes
```

**Post-Update Verification**
```
Check:
- Firmware version is correct
- Device stayed adopted
- No unexpected config changes
- No new unknown connections
```

### Step 4: Secure Configuration

**Apply Hardened Device Settings**
```
For Switches:
- Disable SSH (unless specifically needed)
- Set strong SNMP community strings (or disable)
- Enable LLDP for topology discovery
- Disable UPnP
- Set static IP in management VLAN
- Enable 802.1X if you have RADIUS

For Access Points:
- Disable SSH (unless needed for troubleshooting)
- Enable rogue AP detection
- Enable band steering
- Configure minimum RSSI
- Set static IP in management VLAN
- Enable fast roaming (802.11r) if supported
```

### Step 5: Move to Production

**Only after 48-hour observation period**
```
1. Review all monitoring data
2. Confirm no suspicious behavior
3. UniFi Network → Devices → [Device] → Settings
4. Change Network Assignment:
   - From: Device-Testing (VLAN 98)
   - To: Management (VLAN 1)
5. Set static IP in correct subnet
6. Apply configuration
7. Continue monitoring for another 24 hours
```

---

## Phase 4: Continuous Monitoring

### Daily Checks (First Week)
```
- Review IPS alerts
- Check device uptime (unexpected reboots?)
- Monitor outbound traffic patterns
- Verify no config drift
```

### Weekly Checks (First Month)
```
- Review all firewall blocks involving device
- Check firmware hasn't changed unexpectedly
- Verify device certificate is valid
- Review access logs for unauthorized access
```

---

## Red Flags - Abort Adoption Immediately

### During Factory Reset
- Device won't reset after multiple attempts
- Unusual behavior during reset (unexpected LED patterns)
- Device connects to unexpected IPs before adoption

### During Adoption
- Firmware version doesn't match official UniFi releases
- Device has unexpected open ports
- SSL certificate errors or mismatches
- Device tries to connect to non-UniFi domains

### After Adoption
- Unexpected outbound connections (especially to unusual countries)
- Port scanning behavior from device
- Device attempting lateral movement
- Unusual CPU/memory usage
- Configuration changes you didn't make
- Firmware reverts to old version
- Device appears in IPS logs

### If You See Red Flags:
```
1. IMMEDIATELY disconnect device (pull power)
2. Do NOT reconnect to any network
3. Document all suspicious behavior
4. Consider device permanently compromised
5. Contact UniFi support with evidence
6. Add device MAC to permanent blacklist
```

---

## API-Based Device Inspection

### Query Device Details via API

**Get Device Info**
```bash
# Get all devices
curl -k -X GET 'https://<udm-ip>/proxy/network/api/s/default/stat/device' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' \
  -H 'Accept: application/json' | jq

# Get specific device
curl -k -X GET 'https://<udm-ip>/proxy/network/api/s/default/stat/device/<device-mac>' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' \
  -H 'Accept: application/json' | jq
```

**Check for suspicious fields:**
```json
{
  "version": "6.5.59.xxxxx",  // Verify matches official UniFi version
  "upgrade_to_firmware": "",   // Should be empty or known version
  "uptime": 86400,             // Check for unexpected reboots
  "state": 1,                  // 1 = connected, others suspicious
  "sys_stats": {
    "loadavg_1": 0.5,         // CPU load - high = suspicious
    "mem_used": 50000000      // Memory usage
  },
  "port_table": [],           // Review open ports
  "network_table": []         // Review network connections
}
```

**Get Device DPI Stats**
```bash
curl -k -X GET 'https://<udm-ip>/proxy/network/api/s/default/stat/stadpi' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' \
  -H 'Accept: application/json' | jq
```

**Get IPS Events for Device**
```bash
curl -k -X GET 'https://<udm-ip>/proxy/network/api/s/default/stat/ips/event?mac=<device-mac>' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' \
  -H 'Accept: application/json' | jq
```

---

## Automation Scripts

### Monitor Device for Suspicious Activity

```bash
#!/bin/bash
# monitor-adopted-device.sh

UDM_IP="<your-udm-ip>"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
DEVICE_MAC="$1"
DURATION="${2:-86400}"  # Default 24 hours

if [ -z "$DEVICE_MAC" ]; then
  echo "Usage: $0 <device-mac> [duration-in-seconds]"
  exit 1
fi

echo "Monitoring device $DEVICE_MAC for $DURATION seconds..."
START_TIME=$(date +%s)

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  if [ $ELAPSED -gt $DURATION ]; then
    echo "Monitoring complete. No suspicious activity detected."
    exit 0
  fi

  # Check IPS events
  IPS_EVENTS=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/ips/event?mac=$DEVICE_MAC" \
    -H "X-API-KEY: $API_KEY" | jq length)

  if [ "$IPS_EVENTS" != "0" ]; then
    echo "WARNING: IPS events detected for device!"
    curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/ips/event?mac=$DEVICE_MAC" \
      -H "X-API-KEY: $API_KEY" | jq
  fi

  # Check device state
  DEVICE_STATE=$(curl -sk "https://$UDM_IP/proxy/network/api/s/default/stat/device/$DEVICE_MAC" \
    -H "X-API-KEY: $API_KEY" | jq -r '.data[0].state')

  if [ "$DEVICE_STATE" != "1" ]; then
    echo "WARNING: Device state changed to $DEVICE_STATE"
  fi

  sleep 300  # Check every 5 minutes
done
```

### Quarantine Device Immediately

```bash
#!/bin/bash
# quarantine-device.sh

UDM_IP="<your-udm-ip>"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
DEVICE_MAC="$1"
REASON="${2:-Suspicious activity detected}"

if [ -z "$DEVICE_MAC" ]; then
  echo "Usage: $0 <device-mac> [reason]"
  exit 1
fi

echo "Quarantining device $DEVICE_MAC..."
echo "Reason: $REASON"

# Move to quarantine VLAN (99)
curl -sk -X PUT "https://$UDM_IP/proxy/network/api/s/default/rest/device/$DEVICE_MAC" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "config_network": {
      "type": "dhcp",
      "vlan": 99
    }
  }'

echo "Device moved to Quarantine VLAN 99"
echo "Logging incident..."
echo "$(date): Quarantined $DEVICE_MAC - $REASON" >> ~/workwork/quarantine-log.txt
```

---

## Decision Matrix

| Device Type | Risk Level | Action |
|-------------|-----------|--------|
| Old UDM Pro | CRITICAL | DO NOT RECONNECT - Destroy/RMA |
| Switch with SSH enabled | HIGH | Factory reset + 48hr monitoring in VLAN 98 |
| Switch (managed only) | MEDIUM | Factory reset + 24hr monitoring |
| Basic AP | MEDIUM | Factory reset + 24hr monitoring |
| New/sealed device | LOW | Standard adoption + monitoring |

---

## Best Practices Going Forward

1. **Never auto-adopt devices** - Always manual review
2. **Always factory reset** old devices before adoption
3. **Use staging VLAN** for all new/returning devices
4. **Monitor for 48 hours minimum** before production
5. **Keep adoption logs** with device serial, MAC, adoption date
6. **Regular firmware updates** but verify hashes first
7. **Disable unnecessary services** (SSH, SNMP, etc.)
8. **Use static IPs** for infrastructure devices
9. **Enable IPS/IDS** on all VLANs
10. **Regular security audits** of device configs

---

## Recovery Status Checklist

- [ ] New UDM Pro Max online and configured
- [ ] Management VLAN isolated and secured
- [ ] Device Testing VLAN (98) created
- [ ] Quarantine VLAN (99) created
- [ ] Firewall rules protecting management plane
- [ ] IPS/IDS enabled and monitoring
- [ ] First device factory reset
- [ ] First device adopted in testing VLAN
- [ ] 48-hour monitoring period complete
- [ ] First device moved to production
- [ ] Monitoring scripts deployed
- [ ] Quarantine procedure tested
- [ ] Old compromised UDM Pro physically destroyed/RMA'd

---

**REMEMBER**: It's better to delay network rebuild by a week than to re-infect your new clean UDM Pro Max. When in doubt, factory reset and monitor longer.

**Last Updated**: 2025-10-13
**Incident Reference**: See ~/workwork/ROOT-CAUSE-ANALYSIS-FILESYSTEM-BOMB.md
