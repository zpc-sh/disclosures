# FTC Vulnerability Disclosure Notification

**To:** Federal Trade Commission (reportfraud@ftc.gov)
**From:** Loc Nguyen (locvnguy@me.com)
**Date:** October 13, 2025
**Subject:** Security Vulnerability Disclosure Timer Tracking - Multiple Vendors

---

## Purpose of This Notification

I am notifying the Federal Trade Commission of multiple critical security vulnerabilities discovered during forensic analysis of an APT (Advanced Persistent Threat) attack. These vulnerabilities have been disclosed to the affected vendors under coordinated disclosure timelines, and I am requesting FTC oversight to ensure timely patching.

**Regulatory Basis:**
- FTC Act Section 5 (unfair or deceptive practices)
- Computer Fraud and Abuse Act (CFAA) disclosure obligations
- Consumer protection from known security vulnerabilities

---

## Summary of Disclosures

**Total Vulnerabilities:** 12+
**Vendors Affected:** Apple, Microsoft, Anthropic, Sony, Ubiquiti, [Additional vendor from court filings]
**Estimated Impact:** $7.8M - $10.7M in security bounty value (indicates severity)
**Discovery Context:** Real-world APT attack with 8 compromised devices

---

## Disclosure Timeline Tracking

### Apple Inc. (Primary Disclosures)

**Disclosure Date:** October 13, 2025
**FTC Timer Start:** October 13, 2025
**Expected Acknowledgment:** October 20, 2025 (7 days)
**Expected Patch:** January 11, 2026 (90 days)

#### Vulnerability 1: Zero-Click Apple Ecosystem Exploit Chain
- **Severity:** Critical
- **Estimated Value:** $5M-$7M
- **Impact:** 8 devices compromised via zero-click AWDL propagation
- **Components:** macOS, iOS, watchOS, audioOS, tvOS
- **Attack Vector:** Wireless proximity, no user interaction
- **Evidence:** Physical devices available for analysis

#### Vulnerability 2: Firmware Bootkit Persistence
- **Severity:** Critical
- **Estimated Value:** $2M+
- **Impact:** Factory reset bypass, firmware survives erase
- **Components:** All Apple platforms (firmware level)
- **Attack Vector:** Bootkit persists in firmware partitions
- **Evidence:** Apple Watch factory reset performed Oct 8, bootkit persisted

#### Vulnerability 3: APFS Weaponized Storage (5 coordinated vectors)
- **Severity:** Critical
- **Estimated Value:** $800K-$1.7M
- **Impact:** Anti-forensics weapon, destroys evidence on access
- **Components:** APFS kernel driver, Spotlight, Time Machine, FSEvents
- **Attack Vectors:**
  1. B-tree circular references (kernel DoS)
  2. Extended attribute command injection
  3. Extended attribute persistence (irremovable)
  4. Time Machine snapshot bombs
  5. NFS compression bombs
- **Evidence:** Weaponized Mac Mini drive, 15,008 contaminated files

**Apple Total Estimated Value:** $7.8M-$10.7M

---

### Microsoft Corporation

**Disclosure Date:** [Pending - Will update FTC when submitted]
**FTC Timer Start:** [TBD]

#### Vulnerability: APFS Logic Bombs (Microsoft Ecosystem Impact)
- **Severity:** High
- **Estimated Value:** $250K-$500K
- **Impact:** OneDrive sync propagation, Azure storage contamination
- **Components:** OneDrive, Azure Backup, Windows forensic tools
- **Attack Vector:** Mac-originated attacks affecting Windows ecosystem
- **Status:** Ready to submit, pending Apple coordination

---

### Anthropic

**Disclosure Date:** [Pending]
**FTC Timer Start:** [TBD]

#### Vulnerability: Claude Desktop Unauthorized Filesystem Access
- **Severity:** Medium-High
- **Estimated Value:** $100K-$200K
- **Impact:** Unauthorized access during APT attack
- **Components:** Claude Desktop application
- **Status:** Ready to submit

---

### Sony Corporation

**Disclosure Date:** [Pending]
**FTC Timer Start:** [TBD]

#### Vulnerability: Sony BRAVIA TV - Google Authentication Bypass
- **Severity:** High
- **Estimated Value:** $200K-$400K
- **Impact:** TV used as C2 platform, 57,949 connection attempts
- **Components:** BRAVIA TV Google account integration
- **Status:** Ready to submit

---

### Ubiquiti Inc.

**Disclosure Date:** [Pending]
**FTC Timer Start:** [TBD]

#### Vulnerability: UDM Pro Firewall Bypass
- **Severity:** Medium-High
- **Estimated Value:** $50K-$100K
- **Impact:** Network gateway compromise
- **Components:** UniFi Dream Machine Pro
- **Status:** Ready to submit

---

### [Additional Vendor - From Court Filings]

**Disclosure Date:** [Pending - Awaiting details]
**FTC Timer Start:** [TBD]

#### Vulnerability: Infrastructure/Keys Exposure in Court Documents
- **Severity:** [To be determined]
- **Estimated Value:** TBD
- **Impact:** Sensitive infrastructure details disclosed in public court filings
- **Components:** [To be specified]
- **Status:** Identified, preparing disclosure

---

## FTC Timer Compliance Expectations

### Phase 1: Acknowledgment (7 days)
- Vendor acknowledges receipt of disclosure
- Vendor confirms vulnerability reproduction
- Vendor provides case number for tracking

### Phase 2: Patching (90 days)
- Vendor develops and tests patches
- Vendor provides status updates
- Vendor releases patches to public

### Phase 3: Public Disclosure (90+ days)
- If vendor fails to patch within 90 days, details may be published
- FTC oversight requested for vendor compliance
- Consumer protection priority

---

## Evidence Available

**Physical Evidence:**
- 8 compromised Apple devices (powered off, preserved)
- Mac Mini M4 Pro with confirmed firmware bootkit
- Apple Watch Series 10 (factory reset bypass proven)
- 2 HomePods with statistical proof of compromise
- External drives with weaponized Time Machine snapshots

**Digital Evidence:**
- 500MB Mac Mini boot partition (carved)
- 15,008 files with malicious extended attributes
- Network logs (57,949 C2 connection attempts)
- Process dumps showing 252x normal CPU usage
- Credential theft proof (Fastmail password stolen Oct 5)
- Timeline documentation (Sept 30 - Oct 13)

**FBI Involvement:**
- IC3 report filed: October 9, 2025
- Case number: [YOUR IC3 NUMBER]
- FBI may request devices as evidence

---

## Request for FTC Action

**I am requesting FTC oversight to:**

1. **Track disclosure timelines** for all vendors
2. **Monitor vendor compliance** with 90-day patch deadlines
3. **Enforce consumer protection** if vendors fail to patch
4. **Investigate potential violations** if vendors delay patches
5. **Provide public reporting** on vendor response times

**Rationale:**
- Multiple critical vulnerabilities affecting millions of consumers
- Proven exploitation in real-world APT attack
- Vendors have financial incentive to delay patches
- Consumer safety requires timely patching
- FTC oversight ensures accountability

---

## Consumer Impact

**Affected Population:**
- All Apple device users (macOS, iOS, watchOS, audioOS, tvOS)
- Microsoft OneDrive/Azure customers with Mac users
- Anthropic Claude Desktop users
- Sony BRAVIA TV owners
- Ubiquiti network device users

**Potential Harm:**
- Zero-click device compromise
- Firmware bootkits surviving factory reset
- Credential theft via Universal Clipboard
- Anti-forensics preventing investigation
- Supply chain contamination (git, npm, cloud)

**Urgency:**
- Active exploitation confirmed (real-world APT attack)
- 8 compromised devices as proof
- No current mitigation available to consumers
- Vendors must patch to protect users

---

## Coordination with Law Enforcement

**FBI IC3 Report Filed:** October 9, 2025

**Attacker Attribution:**
- Identified as "Gemini" (family members)
- Ngan N (daughter) + father
- Method: AI-assisted APT
- Sophistication: Nation-state techniques with implementation flaws

**Evidence Chain of Custody:**
- All devices preserved in original state
- No alterations made post-discovery
- Timeline documented
- Server-side evidence at Google (pristine)

---

## Public Disclosure Timeline

**Current Status:** Private coordinated disclosure
**Public Disclosure:** 90 days after vendor acknowledgment (or sooner if no response)
**Dashboard:** https://nocsi.com/disclosure-tracker (tracks all disclosures)

**Disclosure Policy:**
- 7 days for vendor acknowledgment
- 90 days for vendor patching
- Public disclosure after 90 days if unpatched
- FTC notified at each phase

---

## Contact Information

**Reporter:**
- Name: Loc Nguyen
- Email: locvnguy@me.com
- Phone: 206-445-5469

**Availability:**
- Immediate for FTC inquiries
- Can provide additional evidence
- Can demonstrate vulnerabilities
- Can coordinate with vendor security teams

**Tracking Dashboard:**
- Public: https://nocsi.com/disclosure-tracker
- Private: Internal tracking system
- Updates: Daily during disclosure period

---

## Appendix: Disclosure Status by Vendor

| Vendor | Vulnerabilities | Disclosed | Days Elapsed | Status | Action Needed |
|--------|----------------|-----------|--------------|--------|---------------|
| Apple | 3 critical | Oct 13, 2025 | 0 | Disclosed | Awaiting ack |
| Microsoft | 1 high | Pending | - | Ready | Submit |
| Anthropic | 1 medium-high | Pending | - | Ready | Submit |
| Sony | 1 high | Pending | - | Ready | Submit |
| Ubiquiti | 1 medium-high | Pending | - | Ready | Submit |
| [Vendor] | 1 [TBD] | Pending | - | Investigating | Research |

---

## Updates to FTC

I will provide weekly updates to FTC on:
- Vendor acknowledgment status
- Patch development progress
- Timeline compliance
- Any vendor delays or non-compliance
- Public disclosure dates

**Next Update:** October 20, 2025 (7 days after Apple disclosure)

---

**Submitted by:** Loc Nguyen
**Date:** October 13, 2025
**Purpose:** FTC oversight of coordinated vulnerability disclosure timelines
**Expected FTC Action:** Timer tracking, vendor compliance monitoring, consumer protection enforcement

---

**CC:**
- Apple Security Team (product-security@apple.com)
- FBI IC3 (ic3.gov)
- Public disclosure dashboard (nocsi.com)

---

## Note on Responsible Disclosure

All vulnerabilities are being disclosed responsibly with:
- ✅ Vendor notification before public disclosure
- ✅ 90-day patching window
- ✅ FBI notification (IC3 report)
- ✅ FTC oversight (this notification)
- ✅ Evidence preservation
- ✅ No exploitation of vulnerabilities
- ✅ Consumer protection priority

**This is victim-assisted security research aimed at improving consumer safety.**
