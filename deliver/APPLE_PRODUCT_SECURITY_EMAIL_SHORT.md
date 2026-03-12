# Apple Product Security - Device Imaging Request (Short Version)

**To:** product-security@apple.com
**From:** Loc Nguyen <locvnguy@me.com>
**Subject:** Follow-up: Multi-Device Compromise - Ready to Ship for Imaging (8 Devices)
**Date:** October 9, 2025

---

Dear Apple Product Security Team,

I'm following up on my October 4th report regarding compromised Apple devices. Since then, I've completed forensic analysis and **the scope has expanded from 4 devices to 8 devices**, all requiring imaging.

## Critical Update: Devices Ready to Ship

**Compromised Devices (All powered off, evidence preserved):**
1. Apple Watch Series 10 - Firmware-level bootkit, survives factory reset
2. Mac Mini M2 (2023) - Kernelcache modification (Sept 30, 01:31 AM)
3. iPhone 16 Pro - Fake power-off bootkit
4. HomePod Mini (Office) - Firmware compromise
5. HomePod Mini (Bedroom) - Firmware compromise
6. Apple TV - Anomalous network beaconing (discovered Oct 8)
7. iPad - Surveillance capability
8. MacBook Pro - Potential compromise

## Why Urgency Matters

1. **FBI has been notified** (IC3 + National tip line filed Oct 4)
2. **Apple needs to image devices FIRST** before law enforcement seizure
3. **Time-sensitive evidence** on devices (bootkits, firmware modifications, network logs)
4. **Widespread impact** - These are systemic vulnerabilities affecting all Apple users, not just targeted attacks

## Key Findings (High-Level)

- **Firmware-level persistence** across Apple Watch, HomePods, Mac Mini, iPhone
- **Cross-device attack propagation** via iCloud sync
- **Credential theft** via Universal Clipboard interception (password stolen Oct 5, already reset)
- **Network beaconing** from Apple TV to external infrastructure

All devices demonstrate sophisticated compromise requiring firmware-level analysis.

## Documentation Ready

I have completed 27 technical reports (~14,000 lines) documenting:
- Bootkit forensics
- Attack timeline reconstruction
- Cross-device propagation mechanisms
- Evidence artifacts with timestamps

These will be provided to the appropriate Apple Security Bounty channel separately.

## Immediate Request

**I need shipping instructions to send all 8 devices to Apple for imaging.**

Please advise:
1. Shipping address for device imaging
2. Prepaid shipping labels (if available)
3. Chain-of-custody documentation
4. Timeline expectations
5. Point of contact for coordination

All devices are powered off and ready to ship immediately upon receiving instructions.

## Contact Information

- **Name:** Loc Nguyen
- **Email:** locvnguy@me.com
- **Phone:** 206-445-5469
- **Affiliation:** Security Researcher (nocsi.com, zpc.sh, formerly Casaba Security)

## Related Disclosures

- FBI IC3: Filed October 4, 2025
- FBI National Tip Line: Submitted October 4, 2025
- Other vendor disclosures in progress (coordinating timeline with Apple)

---

Thank you for your urgent attention. I understand FBI will likely seize these devices once their investigation advances, so coordinating Apple's imaging window is time-critical.

Looking forward to your shipping instructions.

Respectfully,

Loc Nguyen
locvnguy@me.com
206-445-5469

