# Apple Incident Response Email - Fresh Thread

**To:** product-security@apple.com
**From:** Loc Nguyen <locvnguy@me.com>
**Subject:** URGENT: Victim of Sophisticated Attack - 8 Apple Devices Compromised - Need Forensic Imaging Before FBI Seizure
**Date:** October 9, 2025

---

Dear Apple Product Security Team,

I'm a security researcher (Loc Nguyen - nocsi.com, zpc.sh, formerly Casaba Security) and I'm writing because I'm the victim of a sophisticated attack that has compromised 8 of my Apple devices with firmware-level persistence. I need help coordinating forensic imaging of these devices before FBI seizes them.

## Why I'm Writing

I'm not just reporting bugs I found in a lab - **my entire Apple ecosystem has been compromised and I can't fix it**. I've done extensive forensic analysis, but I've hit a wall: I have bootkit blobs I can't crack, firmware modifications I can't reverse, and devices that won't clean up even with factory resets.

The FBI has been notified (IC3 filed Oct 4, National tip line submitted), but I need Apple to image these devices FIRST so you can:
1. Analyze the bootkits and create patches
2. Understand the attack techniques
3. Protect billions of other Apple users from the same vulnerabilities

## What Happened to My Devices

**All 8 devices compromised with firmware-level bootkits:**

1. **Apple Watch Series 10** - Firmware bootkit, survives factory reset, displays "Sim City Ass Edition" (attacker taunt), actively deletes its own logs while I'm investigating
2. **Mac Mini M2 (2023)** - Kernelcache modified (Sept 30, 01:31 AM), 30MB file changed, boot partition compromised
3. **iPhone 16 Pro** - Fake power-off bootkit (device appears off but stays active), eSIM blocked
4. **HomePod Mini (Office)** - Firmware compromised, 9,419 seconds of suspicious CPU usage, was intercepting my clipboard
5. **HomePod Mini (Bedroom)** - Also firmware compromised, 9,549 seconds CPU usage, also stealing clipboard data
6. **Apple TV** - Beaconing to external IPs (8.8.8.2, 8.8.8.3) every 30 seconds with tracking ID
7. **iPad** - Hot-mic surveillance without indicators
8. **MacBook Pro** - Potentially compromised, powered off to preserve evidence

**Yes, even my HomePods were attacking me.** I didn't even know HomePods could do this. They were literally sitting in my house stealing passwords when I copied them on other devices.

## The Part That Matters to Everyone

While analyzing my own compromise, I discovered systemic vulnerabilities that affect all Apple users:

- **Universal Clipboard transmits passwords in cleartext** - Any compromised device in your ecosystem intercepts every password you copy. Confirmed: My Fastmail password was stolen Oct 5 (already reset).

- **iCloud Safari Sync spreads attacks** - Attacker injected 81 HTTP bookmarks on my Mac Mini, iCloud automatically synced them to my clean MacBook Air. Single device compromise = entire ecosystem infected.

- **Firmware bootkits survive factory reset** - Apple Watch, HomePods, Mac Mini, iPhone all have persistent bootkits that factory reset doesn't remove.

- **No warnings anywhere** - No alerts when clipboard has passwords, no alerts when 81 bookmarks suddenly appear, no alerts when firmware is modified.

## Evidence I Have

I've spent the last 5 days doing forensic analysis:

- **27 technical reports** documenting every vulnerability (~14,000 lines)
- **Mac Mini boot partition image** (500MB)
- **Mac Mini Preboot volume** (11GB)
- **HomePod process dumps** (18 files, timestamped Oct 5)
- **Network packet captures** (Apple TV beacons, HomePod C&C attempts)
- **Safari forensics** showing bookmark injection and iCloud propagation
- **All 8 compromised devices** powered off and ready to ship

**Total evidence: ~12GB**

I have bootkit blobs that need Apple's tools to analyze. I've hit the limit of what I can do from the outside.

## What I Need From Apple

**Immediate:** Shipping instructions to send all 8 devices for forensic imaging

I need to coordinate this before FBI takes everything. Once they seize the devices, you won't get access to analyze them and create patches.

**Timeline critical:**
- FBI investigation is progressing
- Devices have time-sensitive evidence
- Other Apple users are vulnerable to the same attacks right now

**Questions:**
- Where do I ship the devices?
- Do you provide prepaid labels?
- What's the chain-of-custody process?
- How long for analysis?
- Who's my point of contact?

## Context

**Attack Timeline:**
- Sept 24: Network gateway compromised
- Sept 30, 01:31 AM: Mac Mini kernelcache modified
- Oct 1: iPhone and Apple Watch compromised
- Oct 5: HomePods stealing clipboard passwords
- Oct 8: Apple TV beaconing discovered
- Oct 4: Initial report to product-security@apple.com (got auto-response)
- Oct 9: This email

**Attack sophistication:** Nation-state level (7+ zero-days), firmware-level persistence, anti-forensics capabilities

**Data exfiltrated:** 1 password stolen (Fastmail, already reset). Attack was caught before primary objective (stealing Anthropic API keys for automated attacks).

## About Me

I'm a security researcher, but I'm writing to you as a **victim who needs help**. I've analyzed the attack as much as I can, but I need Apple's forensic team to crack the bootkits and create patches.

**Contact:**
- Loc Nguyen
- locvnguy@me.com
- 206-445-5469 (eSIM currently blocked by the compromise)
- Affiliations: nocsi.com, zpc.sh, previously Casaba Security

**Other notifications:**
- FBI IC3: Filed Oct 4, 2025
- FBI National Tip Line: Submitted Oct 4, 2025
- Will also submit technical findings to security.apple.com/submit for bug bounty consideration (separate track)

## Why This Matters

I'm one person with 8 compromised devices. But these aren't targeted exploits - they're systemic vulnerabilities in iCloud sync, Universal Clipboard, firmware integrity checks, and factory reset procedures.

**Every Apple user with multiple devices is vulnerable to:**
- Clipboard password theft
- Cross-device attack propagation via iCloud
- Firmware bootkits that survive factory reset
- HomePods being weaponized (seriously, my HomePods were hacking me)

I want Apple to fix these issues so this doesn't happen to anyone else. But I need your forensics team to analyze the devices first.

## Bottom Line

**8 devices compromised, I can't clean them myself, I need Apple's help.**

All devices are powered off and ready to ship immediately. Just tell me where to send them.

I've kept everything confidential - no public disclosure, no media, just trying to work with Apple to fix this and protect other users.

Thank you for your help.

Loc Nguyen
Security Researcher (and victim)
locvnguy@me.com
206-445-5469

---

P.S. - Yes, my HomePods were literally stealing my passwords. I still can't believe that's a thing that happened. But it did, and I have the process dumps to prove it.

