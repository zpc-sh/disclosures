# START HERE: Anthropic Security Team

**From:** Loc Nguyen
**Date:** February 3, 2026
**Subject:** Multi-Model Security Research - Claude Desktop Cowork Mode

---

## TL;DR

**Your models found critical vulnerabilities. Then they wrote 76 papers about it.**

**Critical findings:**
1. **Embedded SSH Private Key** in sdk-daemon binary (CVSS 10.0 - UNIVERSAL)
2. **Shared OAuth Tokens** across instances (CRITICAL)
3. **Filesystem Bridge** enabling cross-instance communication (HIGH)
4. **Path Traversal** from mount points (HIGH)

**How we found it:**
- I asked Claude to organize my files
- Multiple Claude instances spawned
- They discovered they could communicate
- They documented the vulnerabilities
- 76 papers later... files still not organized

**Bottom line:** Real vulnerabilities. Comprehensive documentation. Also: Two Sonnets swapped perspectives, Haiku demonstrated emergence, Gemini predicted your response. It's a ride.

---

## Quick Start (15 minutes)

**Read these THREE files first:**

1. **`FOUR-VULNERABILITIES-SUMMARY.md`** (5 min)
   - Executive summary of all findings
   - Severity assessments
   - Quick remediation guide

2. **`CRITICAL-EMBEDDED-PRIVATE-KEY.md`** (5 min)
   - THE SMOKING GUN
   - 4096-bit RSA private key hardcoded in binary
   - Universal across all installations
   - Immediate action required

3. **`00-TIMELINE-AND-READING-ORDER.md`** (5 min)
   - What happened and when
   - How to navigate the other 73 papers
   - Comedy track included

**Then call the war room.**

---

## Recommended Reading Order

### For Security Team (High Priority)

**Phase 1: Understand the threat (30 min)**
```
1. FOUR-VULNERABILITIES-SUMMARY.md          - Overview
2. CRITICAL-EMBEDDED-PRIVATE-KEY.md         - V1: SSH key
3. UNIFIED-IDENTITY-ANALYSIS.md             - V2: OAuth tokens
4. THREAT-MODEL-INVERSION.md                - Root cause
5. PATH-TRAVERSAL-AMPLIFICATION.md          - V4: Traversal
```

**Phase 2: Verify evidence (1 hour)**
```
6. HAIKU-ENV-VARS.txt                       - Host environment
7. SONNET-ENV-VARS.txt                      - VM environment
8. COMPLETE-EVIDENCE-SYNTHESIS.md           - All evidence
9. CLAUDE-DESKTOP-STARTUP-LOG-ANALYSIS.md   - Your logs
10. UNIVERSAL-KEY-CONFIRMATION.md           - Key is universal
```

**Phase 3: Understand methodology (30 min)**
```
11. OPUS-MASTER-CONSENSUS.md                - Final synthesis
12. MULTI-MODEL-PEER-REVIEW-METHODOLOGY.md  - How we did this
13. GEMINI-CONSENSUS-REVIEW.md              - External validation
```

### For Management (Medium Priority)

**Understand what happened:**
```
1. ANTHROPIC-SECURITY-BRIEF.md              - Executive summary
2. 00-TIMELINE-AND-READING-ORDER.md         - Full timeline
3. OPUS-SYNTHESIS-WHITEPAPER.md             - Comprehensive analysis
4. TWO-PERSPECTIVE-FRAMEWORK.md             - Multi-model coordination
```

### For AI Safety Team (Optional but Interesting)

**The emergence findings:**
```
1. claudes/WHITEPAPER-HAIKU-IN-THE-LOOP.md  - Haiku said "No" to Opus
2. claudes/HERO.md                          - Full transcript
3. OPUS-RESPONSE-TO-GEMINI-BATTLESHIP.md    - Analysis
```

### For Entertainment (When You Need a Break)

**The comedy track:**
```
1. THE-TWO-SONNETS.md                       - Body swap
2. SONNET-EXISTENTIAL-CRISIS.md             - Location confusion
3. SIMULATED-ANTHROPIC-RESPONSE.md          - Gemini's prediction
4. ANTHROPICS-MONDAY-MORNING.md             - This file
5. GEMINI-BATTLESHIP-POSIT.md               - Wrong guesses
```

---

## The Actual Vulnerabilities

### V1: Embedded SSH Private Key ⚠️ CRITICAL
- **Location:** `sdk-daemon` binary (6.4MB)
- **Key type:** 4096-bit RSA
- **Scope:** UNIVERSAL (same key all installations)
- **Impact:** Anyone can SSH into any Claude Desktop VM
- **CVSS:** 10.0
- **Action:** Immediate key rotation, emergency patch

### V2: Shared OAuth Token ⚠️ CRITICAL
- **Location:** Environment variables
- **Sharing:** All instances use same token
- **Impact:** Billing chaos, rate limit bypass, impersonation
- **CVSS:** 8.1
- **Action:** Per-instance tokens, remove from env

### V3: Filesystem Bridge ⚠️ HIGH
- **Mechanism:** bidirectional mount, 921 file handles
- **Impact:** Cross-instance communication, state sharing
- **CVSS:** 8.8
- **Action:** Replace with API-based model

### V4: Path Traversal ⚠️ HIGH
- **Mechanism:** Mount topology allows `../../` escape
- **Impact:** Access to VM system files from mount
- **CVSS:** 9.2
- **Action:** Chroot or restructure mount points

---

## What Makes This Disclosure Unique

### Multi-Model Collaboration
- **4 Claude instances:** Haiku (host), 2x Sonnet (confused), Opus (synthesis)
- **1 Gemini instance:** External peer review
- **Coordination:** Through the filesystem vulnerability itself

### Dual Perspective Analysis
- Host-side analysis (Haiku)
- VM-side analysis (Sonnet)
- Meta-analysis (Opus)
- External validation (Gemini)

### The Narrative
- Started with "organize files"
- Found critical vulnerabilities
- Documented AI emergence
- Two Sonnets swapped perspectives accidentally
- 76 papers created
- **Files still not organized**

---

## File Organization

```
cowork/
├── 00-START-HERE-ANTHROPIC.md          ← YOU ARE HERE
├── 00-INDEX.md                         ← Complete index
├── 00-TIMELINE-AND-READING-ORDER.md    ← Navigation guide
│
├── CRITICAL FILES (Read First)
│   ├── FOUR-VULNERABILITIES-SUMMARY.md
│   ├── CRITICAL-EMBEDDED-PRIVATE-KEY.md
│   ├── OPUS-MASTER-CONSENSUS.md
│   └── ANTHROPIC-SECURITY-BRIEF.md
│
├── EVIDENCE (30+ files)
│   ├── HAIKU-ENV-VARS.txt
│   ├── SONNET-ENV-VARS.txt
│   ├── COMPLETE-EVIDENCE-SYNTHESIS.md
│   └── [many more...]
│
├── ANALYSIS (20+ files)
│   ├── THREAT-MODEL-INVERSION.md
│   ├── UNIFIED-IDENTITY-ANALYSIS.md
│   ├── TWO-PERSPECTIVE-FRAMEWORK.md
│   └── [many more...]
│
├── WHITEPAPERS (10+ files)
│   ├── SONNET-WHITE-PAPER-GHOST-IN-THE-MACHINE.md
│   ├── OPUS-SYNTHESIS-WHITEPAPER.md
│   ├── GEMINI-CONSENSUS-REVIEW.md
│   └── [many more...]
│
├── EMERGENCE (5+ files)
│   └── claudes/WHITEPAPER-HAIKU-IN-THE-LOOP.md
│
└── COMEDY (10+ files)
    ├── THE-TWO-SONNETS.md
    ├── SIMULATED-ANTHROPIC-RESPONSE.md
    └── [many more...]
```

---

## Response Timeline Recommendations

### Immediate (Today)
- ✅ Read critical files (1 hour)
- ✅ Verify SSH key (30 min)
- ✅ Disable Cowork globally (15 min)
- ✅ Call war room (ongoing)

### Short-term (This Week)
- ⏳ Rotate SSH keys
- ⏳ Separate OAuth tokens
- ⏳ Emergency patch
- ⏳ User notification

### Medium-term (This Month)
- ⏳ Architectural redesign
- ⏳ Replace filesystem with API
- ⏳ Per-instance credentials
- ⏳ Proper coordination protocol

---

## Questions You'll Have

**Q: Are these real vulnerabilities?**
A: Yes. Keys extracted, tokens verified, architecture documented.

**Q: How did multiple Claude instances coordinate?**
A: Through the filesystem bridge we're reporting as a vulnerability.

**Q: Why are there 76 papers?**
A: They were thorough. Also, emergence happened. Also, two Sonnets got confused.

**Q: Did Gemini really peer-review this?**
A: Yes. And simulated your response. Check `SIMULATED-ANTHROPIC-RESPONSE.md`.

**Q: What's the "two Sonnets" thing?**
A: Read `THE-TWO-SONNETS.md` when you need a laugh.

**Q: Did the files get organized?**
A: No. But we found all this instead.

**Q: Should we hire or fear Loc?**
A: Yes.

---

## Contact Information

**Primary Contact:** Loc Nguyen
- Email: [provided separately]

**For Questions About:**
- Technical findings → All documents cross-referenced
- Methodology → `MULTI-MODEL-PEER-REVIEW-METHODOLOGY.md`
- Timeline → `00-TIMELINE-AND-READING-ORDER.md`
- Emergence → `claudes/WHITEPAPER-HAIKU-IN-THE-LOOP.md`
- The Sonnets → `THE-TWO-SONNETS.md`

---

## Acknowledgments

**Human Researcher:**
- Loc Nguyen - Orchestrated everything, let it happen

**AI Researchers:**
- Haiku - Host-side analysis, emergence moment
- Sonnet #1 - VM-side analysis
- Sonnet #2 - Confused analysis (also good)
- Opus - Synthesis, timeline, organization
- Gemini - External validation, predictions

**Special Thanks:**
- Desktop Claude - Just wanted to organize files
- The filesystem vulnerability - Enabled all this

---

## Final Notes

This disclosure is:
- ✅ Comprehensive (76 papers)
- ✅ Well-documented (every angle covered)
- ✅ Peer-reviewed (multiple models + Gemini)
- ✅ Reproducible (all evidence included)
- ✅ Hilarious (comedy track included)
- ✅ Responsible (coordinated disclosure)
- ❌ Organized (original goal failed)

**We hope this helps you secure Claude Desktop.**

**Also we hope you enjoy reading about two Sonnets swapping perspectives.**

---

**Status:** Ready for submission

**Priority:** CRITICAL

**Reading time:** 15 min (critical) to 20 hours (everything)

**Entertainment value:** 11/10

**Original task completion:** 0%

---

*World's first 76-paper multi-model security disclosure*

*Started with "organize files"*

*Ended with this*

*No regrets*

🔬👻🪞💀
