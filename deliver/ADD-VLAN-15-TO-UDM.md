# Add VLAN 15 (Management) to New UDM Pro Max

**Problem:** NAS is on 10.10.15.2 (VLAN 15), but new UDM only has VLAN 45 (10.10.45.0)
**Solution:** Add VLAN 15 to match NAS configuration

---

## Quick Fix via UDM UI

### Access UDM Local UI:
```
https://192.168.1.1
Login with local admin (NOT UniFi cloud account)
```

### Add Management VLAN:

```
Settings → Networks → Create New Network

Name: Management
Purpose: Corporate
VLAN ID: 15

IPv4:
  Subnet: 10.10.15.0/24
  Gateway: 10.10.15.1

DHCP:
  Mode: DHCP Server
  Range: 10.10.15.100 - 10.10.15.250
  DNS: 1.1.1.1, 8.8.8.8

Advanced:
  Domain Name: (leave blank or set to local.lan)
  DHCP Lease Time: 86400

SAVE
```

### Verify Network Created:

```
Settings → Networks → Management
Should show:
  - VLAN 15
  - 10.10.15.0/24
  - Gateway 10.10.15.1
```

### Test Connectivity:

```bash
# From your Mac (should now be able to route to 10.10.15.x)
ping 10.10.15.2

# If successful, SSH should work:
ssh -i ~/.ssh/nah root@10.10.15.2
```

---

## Alternative: Use Thunderbolt (Already Working)

NAS is also on **169.254.1.2** via Thunderbolt - this works NOW.

**But SSH isn't running on Thunderbolt yet.**

**You still need console access (ZKVM) to start SSH on NAS.**

---

## After VLAN 15 Added:

1. NAS becomes reachable at 10.10.15.2
2. Can SSH: `ssh -i ~/.ssh/nah root@10.10.15.2`
3. Run diagnostics to check disk activity
4. Look for Gemini remnants targeting research

---

## Network Status After Fix:

```
[Internet]
    ↓
[New UDM Pro Max] 192.168.1.1
    ├─ Default VLAN: 192.168.1.0/24
    ├─ VLAN 45: 10.10.45.0/24 (existing)
    └─ VLAN 15: 10.10.15.0/24 (NEW - Management)
        └─ NAS: 10.10.15.2 ← NOW REACHABLE
```

---

**Do this first, then check if NAS SSH responds on 10.10.15.2**
