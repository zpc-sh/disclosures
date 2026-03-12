# iCloud SDP Forensics Report

**Collection Date**: Sat Oct 11 00:07:19 PDT 2025
**Collection Time**: 00:07:19

---

## Executive Summary

This report contains evidence extracted from iCloud APIs to identify:
1. Which device enabled Stolen Device Protection
2. When SDP was enabled
3. Evidence of location spoofing
4. Timeline of device additions/removals
5. Security setting changes

---

## API Endpoints Queried

- ✓ /listDevices - Device inventory
- ✓ /accountSettings - Security settings
- ✓ /accountActivityLog - Recent activity
- ✓ /preferences - User preferences
- ✓ /family - Family sharing (device list)
- ✓ /accountLogin - Account information
- ⚠️ CloudKit API - May require different auth

---

## Devices Found

### All Devices
```
```

---

## Key Evidence to Extract

### 1. Device That Enabled SDP

**Where to find it**:
- Check `account-activity.json` for "stolenDeviceProtection" or "security" events
- Look for device ID associated with SDP enablement
- Cross-reference with `devices.json` to identify which device

**What to look for**:
```json
{
  "type": "security.stolenDeviceProtection.enabled",
  "device": "iPhone [model]",
  "deviceId": "[UDID]",
  "timestamp": "[ISO date]",
  "location": {
    "latitude": XX.XXXX,
    "longitude": XX.XXXX
  }
}
```

### 2. Location Spoofing Evidence

**Indicators**:
- Sudden location change (impossible travel)
- WiFi network change to unknown SSID
- Cellular tower change inconsistent with physical movement
- Location data conflicts (WiFi says one place, GPS says another)

**Where to find it**:
- `account-activity.json` - Device location history
- `devices-pretty.json` - Last known locations
- Compare with victim's actual physical location

### 3. SDP Activation Timeline

**Expected sequence**:
```
Oct 7-8: SDP enabled from iPhone
Oct 8-9: Location spoofed (device appears "away from home")
Oct 10: Victim tries to remove devices
Oct 10: SDP lockout triggered (until Oct 12)
```

**Evidence to correlate**:
- SDP enablement timestamp
- Location change timestamp
- Account modification attempt timestamp
- Lockout activation timestamp

---

## Files Collected

```
-rw-r--r--@ 1 locnguyen  staff     0B Oct 11 00:07 account-activity.json
-rw-r--r--@ 1 locnguyen  staff    41B Oct 11 00:07 account-info.json
-rw-r--r--@ 1 locnguyen  staff     0B Oct 11 00:07 account-settings.json
-rw-r--r--@ 1 locnguyen  staff   137B Oct 11 00:07 cloudkit-zones.json
-rw-r--r--@ 1 locnguyen  staff    78B Oct 11 00:07 devices-pretty.json
-rw-r--r--@ 1 locnguyen  staff    68B Oct 11 00:07 devices.json
-rw-r--r--@ 1 locnguyen  staff     0B Oct 11 00:07 family.json
-rw-r--r--@ 1 locnguyen  staff     0B Oct 11 00:07 preferences.json
```

---

## Next Steps

1. **Parse JSON files** for SDP-related events
2. **Identify device** that enabled SDP
3. **Extract timeline** of location changes
4. **Document spoofing** evidence (impossible travel, network changes)
5. **Correlate with logs** from iPhone (if available)
6. **Package for Apple** Security submission

---

## Manual Analysis Required

Some data may not be accessible via API and requires:

1. **iPhone system logs**:
   - Run `./collect-iphone-sdp-evidence.sh` on Mac
   - Extract iPhone backup logs if available

2. **CloudKit direct access**:
   - May need to use `brctl` on device
   - Or query CloudKit API with proper authentication

3. **Apple Support request**:
   - Request SDP enablement logs
   - Request device activity logs for timeframe

---

**Report generated at**: Sat Oct 11 00:07:19 PDT 2025

