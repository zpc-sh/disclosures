# Apple Security Email - Final Submission

**To:** product-security@apple.com
**Subject:** URGENT: Firmware Bootkits on 8 Devices + FBI Case Coordination

---

**Email Body:**

Apple Security Team,

I am submitting a critical security report involving firmware-level bootkits on 8 Apple devices with complete forensic evidence preserved.

## Case Summary

**FBI Case:** IC3 Complaint 62d59d60589c4e68beb80fbe71a50835 (filed Oct 6, 2025)
**Reporter:** Loc Nguyen (locvnguy@me.com, 206-445-5469)
**Status:** All 8 devices powered off, evidence preserved, ready to ship

## Primary Evidence: Mac Mini M4 Pro Bootkit

**Device:** Mac Mini M4 Pro (Serial: V5QMKGQ1GP)
**OS:** macOS 26.0.1 (Sequoia 15.0.1)
**Confirmed Compromise:**
- Kernelcache modified Sept 30, 2025 01:31 AM (30MB file)
- Boot partition compromised (500MB carved and preserved)
- Preboot volume modified (11GB carved and preserved)
- boot.efi manipulation detected (0-byte file - highly suspicious)
- Multiple IMG4 firmware containers present

**Evidence preserved:**
- Complete boot partition dump
- Preboot volume extraction
- SHA-256 hashes of all boot files
- Timestamp analysis showing modification dates

## Additional Compromised Devices (7 total)

1. **Apple Watch Series 10** (Serial: K92T6THL6)
   - Factory reset FAILED - bootkit persists
   - Display modification ("Sim City Ass Edition" - clear tampering)
   - Anti-forensics active

2. **HomePod Mini** (Serial: H6JDMFHUPQ1H)
   - Firmware compromise confirmed
   - rapportd: 9,419 seconds CPU usage during attack window
   - Universal Clipboard credential theft confirmed
   - Fastmail password intercepted Oct 5 (already reset)

3. **iPad Pro M4** (Serial: YTF3V56F7D)
   - Hot-mic surveillance without indicators
   - UI glitches indicating system compromise

4. **iPhone 14 Pro** (Serial: NMX0QFX9RK)
   - Firmware-level persistence
   - eSIM manipulation/blocking
   - "yang" marker display (exploit artifact)
   - Restored from compromised backup (propagation)

5. **Apple TV 4K** (Serial: LW2XLVPHCY)
   - UDP beaconing to 8.8.8.2/3 every 30 seconds
   - Tracking ID: 0x91626192
   - Network: 192.168.13.107

6. **MacBook Pro 14"** (Serial: CXK3G2VX7M)
   - Potential compromise via Claude Desktop app manipulation
   - Powered off to preserve evidence

7. **HomePod (Full Size)** (Serial: DLXVRLUPHQK8)
   - Firmware compromise suspected
   - rapportd: 9,549 seconds CPU usage
   - Credential interception capability

## Cross-Device Attack Vectors

### Universal Clipboard Exploitation
- **Date:** October 5, 2025
- **Stolen Credential:** Fastmail password (ALREADY RESET - no user risk)
- **Method:** Cleartext transmission via AWDL
- **Intercepting Devices:** iPhone, Apple Watch, both HomePods
- **Impact:** Any password copied on ANY device intercepted by ALL compromised devices

### iCloud Safari Sync Propagation
- **Attack Vector:** Mac Mini compromise injected 81 HTTP bookmark downgrades
- **Propagation:** iCloud automatically synced 17 HTTP downgrades to clean MacBook Air
- **Impact:** Single device compromise spreads to entire ecosystem via legitimate Apple sync
- **Evidence:** Safari bookmark forensics with ServerID tracking

### HomePod Coordination
- **Both HomePods compromised** with firmware-level persistence
- **C&C Activity:** 57,949 failed connection attempts to compromised relay
- **Capability:** Universal Clipboard interception, audio surveillance

## Why This Matters

1. **Firmware Persistence:** Survives factory reset (Apple Watch confirmed)
2. **Cross-Device Propagation:** iCloud sync weaponized to spread compromise
3. **Ecosystem-Wide Impact:** Single entry point compromises entire Apple ecosystem
4. **User Indicator Failure:** Hot-mic without any visual indicators
5. **Legitimate Sync Abuse:** Apple's own services used for attack propagation

## Evidence Package Available

- 12GB complete forensic evidence
- All 8 devices powered off and secured
- Complete timeline (Sept 24 - Oct 8, 2025)
- Network captures, process dumps, boot partition images
- 27 technical reports (14,000+ lines of analysis)

## FBI Coordination Required

**Active FBI Investigation:** IC3 Complaint 62d59d60589c4e68beb80fbe71a50835

**FBI imaging required before device shipment to Apple.**

This is a criminal case requiring law enforcement coordination. Devices contain evidence for ongoing FBI investigation.

## Immediate Actions Requested

1. **Security case number assignment**
2. **Point of contact** for technical coordination
3. **FBI coordination protocol** - devices are criminal evidence
4. **Timeline** for analysis after FBI imaging
5. **Shipping instructions** (post-FBI imaging)

## Disclosure Timeline

Given FBI case activity and ongoing compromise risk to other users, I cannot delay disclosure indefinitely.

**Timeline:**
- If no response by **October 16, 2025** (7 days), I will coordinate public disclosure with FBI
- Technical details will be released to protect other Apple users
- Complete device inventory and forensic analysis will be published

I strongly prefer responsible disclosure with Apple cooperation.

## Contact Information

**Name:** Loc Nguyen
**Email:** locvnguy@me.com
**Phone:** 206-445-5469
**Location:** Lynnwood, WA (Seattle area)

**Background:**
- Security researcher (formerly Casaba Security)
- 15+ years vulnerability research
- Multiple previous responsible disclosures

**Availability:** Immediate. Standing by for coordination.

## Attachments

1. Complete device inventory (8 devices with serials)
2. Mac Mini boot analysis (kernelcache, boot.efi, IMG4 evidence)
3. Universal Clipboard credential theft timeline
4. iCloud sync propagation analysis
5. FBI IC3 complaint confirmation

Please confirm receipt and provide security case number.

This is time-sensitive due to:
- Active FBI investigation
- Criminal evidence preservation requirements
- Risk to other Apple users
- Firmware persistence across ecosystem

I am ready to coordinate with both Apple Security and FBI immediately.

Respectfully,

Loc Nguyen
locvnguy@me.com
206-445-5469

---

**Previously reported:** October 4, 2025 (initial report)
**Follow-up:** October 9, 2025 (complete submission with FBI case details)
