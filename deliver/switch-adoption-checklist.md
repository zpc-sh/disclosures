# Switch Adoption Checklist - Post-Compromise Recovery
**Context**: Adopting potentially compromised switches from old network

---

## BEFORE You Start

**⚠️ CRITICAL**: These switches were on the compromised network. Treat as hostile.

### Prerequisites
- [ ] New UDM Pro Max online and accessible
- [ ] Attack monitoring active (honeypot running)
- [ ] Testing VLAN created (VLAN 98, 10.0.98.0/24)
- [ ] Physically isolate switch from old network
- [ ] Have paper and pen ready to document MAC addresses

---

## Per-Switch Procedure

### Switch #_____ (Serial: _____________ | MAC: _____________)

#### Phase 1: Physical Reset

1. **BEFORE powering on:**
   - [ ] Unplug ALL ethernet cables
   - [ ] Verify switch is isolated (no connections)
   - [ ] Have reset button accessible

2. **Factory Reset:**
   - [ ] Plug in power
   - [ ] Wait 30 seconds for boot
   - [ ] Press and hold reset button for 10+ seconds
   - [ ] All LEDs should blink (indicates reset)
   - [ ] Release button when LEDs turn off
   - [ ] Wait 5 minutes for full reset
   - [ ] Document time: __________

3. **Verify Reset:**
   - [ ] LEDs should cycle through boot sequence
   - [ ] Should show as "pending adoption" (white/blinking)

#### Phase 2: Isolated Adoption

4. **Connect to UDM:**
   - [ ] Connect ONE cable from switch to UDM port
   - [ ] Wait 60 seconds
   - [ ] Check UDM for pending adoption

5. **Verify Switch Appears:**
   ```bash
   # Run this command
   curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
     -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
     jq -r '.data[] | select(.state==0) | "Pending: \(.model) | MAC: \(.mac) | IP: \(.ip)"'
   ```
   - [ ] Switch shows as pending
   - [ ] MAC address matches: _____________
   - [ ] IP assigned: _____________

6. **Document Pre-Adoption State:**
   - [ ] Firmware version: _____________
   - [ ] IP address: _____________
   - [ ] Adoption time: _____________

#### Phase 3: Adopt

7. **Adopt via UI:**
   - [ ] Open https://192.168.1.1
   - [ ] UniFi Devices → Pending Devices
   - [ ] Click "Adopt" on the switch
   - [ ] Wait for adoption to complete
   - [ ] Switch should show "Connected" (green)

8. **Document Post-Adoption:**
   - [ ] Adoption completed: __________ (time)
   - [ ] Firmware downloading: Yes / No
   - [ ] New firmware version: _____________

#### Phase 4: 24-Hour Quarantine Monitoring

9. **Monitor for 24 Hours:**

   **Watch for:**
   - [ ] Unexpected outbound connections
   - [ ] Port scanning behavior
   - [ ] Unusual traffic patterns
   - [ ] Attempts to access other VLANs
   - [ ] Config changes you didn't make
   - [ ] Firmware downgrade attempts

   **Check every 6 hours:**
   ```bash
   # Check switch status
   curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
     -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
     jq -r '.data[] | select(.mac=="<SWITCH-MAC>") | {state, ip, version, uptime}'

   # Check for IPS alerts
   curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/ips/event' \
     -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
     jq -r '.data[] | select(.src_ip=="<SWITCH-IP>" or .dst_ip=="<SWITCH-IP>")'
   ```

   - [ ] 6 hour check (time: __________): CLEAN / SUSPICIOUS
   - [ ] 12 hour check (time: __________): CLEAN / SUSPICIOUS
   - [ ] 18 hour check (time: __________): CLEAN / SUSPICIOUS
   - [ ] 24 hour check (time: __________): CLEAN / SUSPICIOUS

10. **RED FLAGS - Abort if you see:**
    - [ ] Unexpected connections to Internet
    - [ ] Scanning other network devices
    - [ ] Firmware version changes without your action
    - [ ] SSH/Telnet attempts
    - [ ] TFTP/FTP traffic
    - [ ] IPS alerts from switch IP
    - [ ] Unusual CPU/memory usage
    - [ ] Config reverts to old settings

#### Phase 5: Production Deployment (After 24hrs CLEAN)

11. **Final Security Check:**
    - [ ] No suspicious activity in 24 hours
    - [ ] Firmware is latest stable
    - [ ] No IPS alerts
    - [ ] SSH disabled (or key-only)
    - [ ] SNMP disabled (or strong community string)

12. **Move to Production:**
    - [ ] Set static IP in Management VLAN: 10.0.1.___
    - [ ] Configure port profiles as needed
    - [ ] Enable PoE if required
    - [ ] Connect production devices
    - [ ] Document deployment: __________

13. **Post-Deployment Monitoring:**
    - [ ] Monitor for 1 week
    - [ ] Check for unexpected behavior
    - [ ] Verify no lateral movement

---

## Switch Inventory

| Switch # | Model | Serial | MAC | Reset Date | Adopt Date | Status | Notes |
|----------|-------|--------|-----|------------|------------|--------|-------|
| 1 | | | | | | PENDING | |
| 2 | | | | | | PENDING | |
| 3 | | | | | | PENDING | |
| 4 | | | | | | PENDING | |
| 5 | | | | | | PENDING | |

---

## Monitoring Commands Reference

### Check Pending Adoptions
```bash
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq -r '.data[] | select(.state==0 or .state==1) | "\(.model) | \(.mac) | State: \(.state)"'
```

### Check All Adopted Devices
```bash
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq -r '.data[] | "\(.type) | \(.name // .model) | \(.ip) | \(.mac) | State: \(.state)"'
```

### Check Specific Switch Status
```bash
SWITCH_MAC="xx:xx:xx:xx:xx:xx"
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq --arg mac "$SWITCH_MAC" '.data[] | select(.mac==$mac)'
```

### Monitor Switch Traffic (Live)
```bash
SWITCH_IP="10.0.1.xxx"
sudo tcpdump -i any host $SWITCH_IP -nn -v
```

### Check IPS Alerts for Switch
```bash
SWITCH_IP="10.0.1.xxx"
curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/ips/event' \
  -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' | \
  jq --arg ip "$SWITCH_IP" '.data[] | select(.src_ip==$ip or .dst_ip==$ip)'
```

---

## Decision Matrix

| Observation | Action |
|-------------|--------|
| Switch adopts normally, no alerts | Continue monitoring |
| Firmware downloads and updates | Normal - continue |
| Switch restarts after firmware | Normal - continue |
| Unusual outbound connections | QUARANTINE - investigate |
| Port scanning detected | QUARANTINE - consider compromised |
| IPS alerts | QUARANTINE - investigate |
| Config changes without action | QUARANTINE - likely compromised |
| SSH/Telnet attempts | QUARANTINE - compromised |
| Multiple failed adoptions | Factory reset again |
| Won't factory reset | DO NOT ADOPT - hardware replace |

---

## If Compromise Detected

1. **Immediate Actions:**
   - [ ] Disconnect switch from network (pull power)
   - [ ] Do NOT reconnect
   - [ ] Capture evidence (logs, pcap)
   - [ ] Document behavior
   - [ ] Add MAC to blacklist

2. **Evidence Collection:**
   ```bash
   # Save switch config
   curl -sk "https://192.168.1.1/proxy/network/api/s/default/stat/device" \
     -H "X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul" | \
     jq --arg mac "$SWITCH_MAC" '.data[] | select(.mac==$mac)' \
     > "compromised-switch-$SWITCH_MAC-$(date +%Y%m%d).json"

   # Save IPS alerts
   curl -sk "https://192.168.1.1/proxy/network/api/s/default/stat/ips/event" \
     -H "X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul" \
     > "ips-alerts-$(date +%Y%m%d).json"
   ```

3. **Disposition:**
   - [ ] Try factory reset one more time
   - [ ] If still suspicious: Permanently retire
   - [ ] Consider RMA if under warranty
   - [ ] Document for vendor disclosure

---

## Safe Switch - Criteria

A switch is considered SAFE to deploy after:
- ✅ Factory reset completed successfully
- ✅ Adopted with latest firmware
- ✅ 24 hours monitoring with NO suspicious activity
- ✅ Zero IPS alerts
- ✅ No unexpected network connections
- ✅ Stable uptime, no unexpected reboots
- ✅ Config remains stable

---

## Notes Section

Use this space to document anything unusual:

```
Date: ___________
Switch: ___________
Observation:




Action Taken:




Result:



```

---

**Remember**: When in doubt, DON'T adopt. It's cheaper to buy a new switch than to get re-compromised.

**Safety First**: One suspicious switch can re-infect your entire clean network.

---

## Quick Start

Ready to adopt your first switch? Here's the flow:

1. Reset switch (hold button 10+ seconds)
2. Connect single cable to UDM
3. Run: `watch -n 5 'curl -sk "https://192.168.1.1/proxy/network/api/s/default/stat/device" -H "X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul" | jq -r ".data[] | select(.state==0 or .state==1)"'`
4. Adopt in UI when it appears
5. Monitor for 24 hours
6. If clean → move to production
7. If suspicious → disconnect and investigate

**You got this!** Take it slow, document everything, trust your instincts.
