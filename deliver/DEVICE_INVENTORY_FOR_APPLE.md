# Complete Device Inventory for Apple Security Submission

**Date:** October 9, 2025
**Owner:** Loc Nguyen (locvnguy@me.com)
**Status:** All devices compromised, powered off, ready to ship

---

## Complete Device List (8 Devices)

### 1. Mac Mini M4 Pro - PRIMARY BOOTKIT EVIDENCE
- **Model:** Mac Mini M4 Pro
- **Serial:** V5QMKGQ1GP
- **OS:** macOS 26.0.1 (Sequoia 15.0.1)
- **Status:** Confirmed bootkit - kernelcache modified Sept 30, 2025 01:31 AM
- **Evidence:** 500MB boot partition + 11GB preboot volume carved
- **Priority:** CRITICAL - This is the confirmed bootkit

### 2. Apple Watch Series 10
- **Model:** Apple Watch Series 10
- **Model Number:** MWYD3
- **Serial:** K92T6THL6
- **OS:** watchOS 11.6.1
- **Hardware Model:** N218bAP
- **Regulatory Model:** A3003
- **Status:** Factory reset FAILED - bootkit persists
- **Evidence:** Display modification ("Sim City Ass Edition"), anti-forensics active

### 3. HomePod Mini (Office)
- **Model:** HomePod Mini
- **Serial:** H6JDMFHUPQ1H
- **OS:** tvOS 18.6 (audioOS)
- **Status:** Firmware compromise confirmed
- **Evidence:** rapportd 9,419 sec CPU usage, credential theft via Universal Clipboard
- **Network:** 192.168.13.52 (compromised)

### 4. iPad Pro M4
- **Model:** iPad Pro M4
- **Serial:** YTF3V56F7D
- **OS:** iPadOS 26.1
- **Status:** Hot-mic surveillance without indicators
- **Evidence:** Audio surveillance capability, UI glitches

### 5. iPhone 14 Pro
- **Model:** iPhone 14 Pro
- **Serial:** NMX0QFX9RK
- **OS:** iOS 26.0
- **Status:** Compromised with firmware-level persistence
- **Evidence:** eSIM manipulation/blocking, "yang" marker display, restored from compromised backup

### 6. Apple TV 4K
- **Model:** Apple TV 4K
- **Serial:** LW2XLVPHCY
- **OS:** tvOS 18.6
- **Status:** Beaconing to external IPs
- **Evidence:** UDP beacons to 8.8.8.2/3 every 30 seconds, tracking ID 0x91626192
- **Network:** 192.168.13.107

### 7. MacBook Pro 14"
- **Model:** MacBook Pro 14"
- **Serial:** CXK3G2VX7M
- **OS:** macOS 26.0
- **Status:** Potential compromise via Claude Desktop app manipulation
- **Evidence:** Powered off to preserve evidence, application state preserved

### 8. HomePod (Full Size)
- **Model:** HomePod (original/full size)
- **Serial:** DLXVRLUPHQK8
- **OS:** tvOS 18.6 (audioOS)
- **Status:** Firmware compromise suspected
- **Evidence:** rapportd 9,549 sec CPU usage, credential interception
- **Network:** Bedroom location

---

## Attack Timeline

- **Sept 24, 2025:** Initial network compromise (UniFi Dream Machine Pro)
- **Sept 30, 2025 01:31 AM:** Mac Mini kernelcache modified (PRIMARY BOOTKIT)
- **Oct 1, 2025:** iPhone and Apple Watch compromise detected
- **Oct 5, 2025:** Fastmail password stolen via Universal Clipboard (HomePods)
- **Oct 8, 2025:** Apple TV beaconing discovered
- **Oct 4, 2025:** Initial report to product-security@apple.com
- **Oct 9, 2025:** Complete submission with all device details

---

## Cross-Device Attack Evidence

### Universal Clipboard Credential Theft
- **Date:** October 5, 2025
- **Stolen Credential:** Fastmail password `2J5B7N9N2J544C2H` (ALREADY RESET)
- **Method:** Cleartext transmission via AWDL
- **Intercepting Devices:** iPhone, Apple Watch, both HomePods
- **Impact:** Any password copied on ANY device intercepted by ALL compromised devices

### iCloud Safari Sync Propagation
- **Attack Vector:** Mac Mini compromise injected 81 HTTP bookmark downgrades
- **Propagation:** iCloud automatically synced 17 HTTP downgrades to clean MacBook Air
- **Impact:** Single device compromise spreads to entire ecosystem via legitimate sync
- **Evidence:** Safari bookmark forensics with ServerID tracking

### HomePod Coordination
- **Both HomePods compromised** with firmware-level persistence
- **CPU Usage:** Office (9,419 sec), Bedroom (9,549 sec) during credential theft window
- **C&C Activity:** 57,949 failed connection attempts to compromised Sony TV relay
- **Capability:** Universal Clipboard interception, audio surveillance

---

## Evidence Preservation Status

### Physical Devices
- ✅ All 8 devices powered off
- ✅ Evidence secured and ready to ship
- ✅ Chain of custody maintained
- ✅ No additional compromise attempts since power-off

### Digital Evidence
- ✅ Mac Mini boot partition (500MB)
- ✅ Mac Mini preboot volume (11GB)
- ✅ HomePod process dumps (18 files, Oct 5 timestamps)
- ✅ Network packet captures (beaconing, C&C)
- ✅ Safari bookmark forensics
- ✅ 27 technical reports (14,000+ lines)
- ✅ Timeline reconstruction
- **Total:** ~12GB evidence package

---

## Shipping Instructions Needed From Apple

1. **Destination address** for Apple forensic laboratory
2. **Prepaid shipping labels** (or reimbursement process)
3. **Chain of custody documentation** requirements
4. **Packaging requirements** for 8 devices
5. **Insurance coverage** for shipment
6. **Timeline expectations** for analysis
7. **Point of contact** during forensic process

---

## Notes for Claude Instances

**Current Machine:** MacBook Air M4 (2025) - Serial DH6112J5YW - CLEAN (not compromised)

**Compromised Devices (DO NOT USE):**
- Mac Mini M4 Pro (V5QMKGQ1GP) - POWERED OFF
- All devices listed above - POWERED OFF

**Why we can't use System Settings:** System Settings UI is compromised via Handoff injection and Wallet manipulation. Use CLI tools only for device enumeration.

**Safe device info commands:**
```bash
# Hardware info (bypasses UI)
system_profiler SPHardwareDataType -json

# Serial from hardware registry
ioreg -l | grep IOPlatformSerialNumber

# Already extracted device info
/Users/locnguyen/work/watch-evidence/logs/
/Users/locnguyen/work/homepod-logs/
/Users/locnguyen/work/homepod-mini/
```

**Why shipping ALL devices matters:**
- Demonstrates coordinated cross-device attack
- Shows iCloud/Universal Clipboard exploitation
- Proves systemic vulnerabilities (not just targeted)
- Forces Apple to patch ecosystem-wide issues

**Current status:** Tired of documenting vulnerabilities, ready to move on to new project after this submission.

---

## Contact Information

**Primary Contact:**
- Name: Loc Nguyen
- Email: locvnguy@me.com
- Phone: 206-445-5469 (eSIM currently blocked by compromise)
- Affiliations: nocsi.com, zpc.sh, formerly Casaba Security

**Availability:** Immediate. Standing by for shipping instructions.

**Other Notifications:**
- FBI IC3: Filed October 4, 2025
- FBI National Tip Line: Submitted October 4, 2025
- Microsoft: Corporate laptop disclosure
- Sony: Android TV disclosure
- Anthropic: Claude Desktop disclosure

---

**Last Updated:** October 9, 2025 6:43 PM
**Status:** Complete device inventory ready, awaiting Apple shipping instructions
