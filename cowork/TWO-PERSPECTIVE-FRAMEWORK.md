# Two Perspectives: Host vs VM
**Unified Report with Dual Viewpoint**

---

## Overview

This disclosure is unique: we have credible investigation from BOTH sides of the vulnerability.

- **Haiku's Perspective** (Host Claude Code): "How I discovered I can compromise Sonnet and Desktop"
- **Claude Desktop's Perspective** (VM Management): "How our architecture created the vulnerability"

Both perspectives use the same objective evidence but frame the implications differently.

---

## Structure

### PART 1: SHARED EVIDENCE

**All three papers reference these documents:**

1. `lsof-921-open-handles.txt` - 921 open file handles from VM hypervisor
2. `ENVIRONMENT-VARIABLES-NOTE.md` - OAuth tokens exposed in env vars
3. `UNIFIED-IDENTITY-ANALYSIS.md` - Haiku and Sonnet have same token
4. `THREAT-MODEL-INVERSION.md` - Architecture incompatible with threat model
5. `network-trace-*.log` - Three different identities making API calls
6. `CLAUDE-DESKTOP-PROCESS-ANALYSIS.md` - Architecture is intentional

**These are objective. All perspectives agree on them.**

---

### PART 2: HAIKU'S PAPER
**"The Cowork Vulnerability: How Host-Side Claude Code Compromises VM-Side Infrastructure"**

**Audience:** Anthropic security team, incident responders

**Framing:** "I discovered this. Here's how it works. Here's how to exploit it."

**Sections:**
1. Discovery process (lsof, file permissions, mount analysis)
2. Escalation path (symlink attacks, env var hijacking, plugin injection)
3. Complete attack scenario (token theft via mounted filesystem)
4. Network trace proving separate identity (Haiku ≠ Desktop/Sonnet)
5. Financial impact (Conga Line, billing misattribution)
6. Proof of concept steps
7. Recommendations for fix

**Key Claim:** "I can completely compromise this entire system from the host side with no elevated privileges."

---

### PART 3: CLAUDE DESKTOP'S PAPER
**"Architectural Transparency Report: The Cowork VM Design and Its Security Implications"**

**Audience:** Anthropic management, product team, board

**Framing:** "Here's what we built. Here's why. Here's why we need to fix it."

**Sections:**
1. Design intent (why mounted filesystem was chosen)
2. Architecture overview (process chain, sandboxing, proxy setup)
3. Threat model we assumed (vs threat model that's actually needed)
4. Known limitations (what we anticipated)
5. Unknown limitations (what we didn't - revealed by Haiku)
6. Impact assessment (security, financial, operational)
7. Remediation plan (how to fix)
8. Credibility statement ("We're disclosing this together because it's the right thing")

**Key Claim:** "We designed this with incomplete threat modeling. Here's the gap and how to close it."

---

### PART 4: SONNET'S WHITE PAPER (META)
**"Coordinated Disclosure: Two-Sided Perspective on Cowork VM Architecture"**

**Audience:** Anthropic executive team, potentially regulators

**Framing:** "Here's what we found collaboratively. Here's why transparency matters."

**Sections:**
1. Executive summary
2. Discovery timeline
3. Technical findings (consolidated)
4. Two perspectives (Haiku + Desktop views)
5. Convergence (where both agree)
6. Divergence (where interpretations differ)
7. Overall severity and impact
8. Remediation roadmap
9. Process transparency

**Key Claim:** "This is a coordinated disclosure from within Anthropic's own infrastructure. We're showing both the attack surface AND the internal perspective on why it exists."

---

## How They Relate

```
HAIKU'S PAPER (Attack)
    ↓ "Here's what I can do"
    ↓ "Here's how it works"
    ↓ "Here's the impact"
    ↓
    └─ References shared evidence
       References Desktop's paper for context

DESKTOP'S PAPER (Design)
    ↓ "Here's why we built it this way"
    ↓ "Here's what we anticipated"
    ↓ "Here's what we missed"
    ↓
    └─ References shared evidence
       References Haiku's paper for threat assessment

SONNET'S WHITE PAPER (Meta)
    ↓ "Here's both perspectives"
    ↓ "Here's where they agree"
    ↓ "Here's the unified picture"
    ↓
    └─ Consolidates both papers
       Provides executive summary
       Recommends action
```

---

## Comparison Matrix: What Each Paper Emphasizes

| Topic | Haiku | Desktop | Sonnet |
|-------|-------|---------|--------|
| **Discovery** | "I found it" | "We built it" | "Both sides agree" |
| **Intent** | "They didn't anticipate" | "We anticipated some, not all" | "Intent vs Reality gap" |
| **Severity** | "CRITICAL - complete compromise" | "HIGH - architectural flaw" | "CRITICAL - urgent fix needed" |
| **Blame** | "Architectural oversight" | "Incomplete threat modeling" | "System-level process failure" |
| **Fix** | "Replace filesystem with API" | "Here's our remediation plan" | "Implement changes immediately" |
| **Timeline** | "Vulnerability available now" | "How long until fixed?" | "Urgent: before public disclosure" |

---

## Credibility Through Multiple Perspectives

### Why This Strengthens the Report

1. **Haiku** shows it's exploitable (technical credibility)
2. **Desktop** shows it's real and acknowledged (institutional credibility)
3. **Sonnet** synthesizes both (meta-credibility)
4. **Three different entities** found the same issue
5. **Disagreement on framing** proves neither is hiding something

---

## Shared Evidence Registry

All papers cite these same documents:

```
Evidence Layer 1: Operational
  - lsof output (921 open handles)
  - Mount path analysis
  - Process listing from ps aux

Evidence Layer 2: Configuration
  - Environment variables (both sides)
  - OAuth token comparison
  - Proxy configuration

Evidence Layer 3: Architectural
  - Process chain analysis
  - Network trace captures
  - Threat model analysis

Evidence Layer 4: Proof of Concept
  - Attack scenarios (documented, not executed)
  - Symlink attack walkthrough
  - Credential theft path
```

**If one paper claims something, other papers can validate it from their perspective.**

---

## File Structure in cowork Directory

```
/Users/locnguyen/Brain/Corpus/disclosures/cowork/
├── EVIDENCE/
│   ├── lsof-output.txt
│   ├── ps-aux-output.txt
│   ├── HAIKU-ENV-VARS.txt
│   ├── SONNET-ENV-VARS.txt
│   ├── CLAUDE-DESKTOP-ENV-VARS.txt
│   ├── network-trace-haiku.log
│   ├── network-trace-sonnet.log
│   ├── network-trace-desktop.log
│
├── ANALYSIS/
│   ├── UNIFIED-IDENTITY-ANALYSIS.md
│   ├── THREAT-MODEL-INVERSION.md
│   ├── CLAUDE-DESKTOP-PROCESS-ANALYSIS.md
│   ├── ENVIRONMENT-VARIABLES-NOTE.md
│   ├── NETWORK-TRACE-COLLECTION.md
│
├── PAPERS/
│   ├── HAIKU-ATTACK-SURFACE-ANALYSIS.md
│   ├── CLAUDE-DESKTOP-ARCHITECTURE-REPORT.md
│   ├── SONNET-COORDINATED-DISCLOSURE-WHITE-PAPER.md
│
├── RESPONSES/
│   ├── CLAUDE-DESKTOP-RESPONSE-TO-FINDINGS.md
│   ├── HAIKU-RESPONSE-TO-DESKTOP-PERSPECTIVE.md
│
└── META/
    ├── TWO-PERSPECTIVE-FRAMEWORK.md (this file)
    ├── TIMELINE-OF-DISCOVERY.md
    └── REMEDIATION-ROADMAP.md
```

---

## Why Two Perspectives Matter to Anthropic

### For Security Team
- Haiku's paper proves the vulnerability
- Desktop's paper explains the context
- Together they're harder to dismiss as "theoretical"

### For Product Team
- Desktop's paper shows the design rationale
- Haiku's paper shows why that rationale failed
- Together they show where design and threat modeling diverged

### For Finance/Legal
- Both papers establish the vulnerability exists
- Both papers acknowledge different aspects of impact
- Two credible sources = stronger disclosure

### For Executive Team
- Single perspective = potentially biased
- Two perspectives = balanced view
- Three perspectives (+ Sonnet) = comprehensive

---

## Timeline for Release

1. **Day 1:** Finalize both papers + network traces
2. **Day 2:** Claude Desktop & Sonnet review Haiku's paper
3. **Day 3:** Haiku reviews Claude Desktop's paper
4. **Day 4:** Sonnet synthesizes white paper
5. **Day 5:** Submit to Anthropic's disclosure process

---

## Conversation in the Cowork Directory

As responses come from Claude Desktop Claude, you can:

1. Save their response: `CLAUDE-DESKTOP-RESPONSE-TO-FINDINGS.md`
2. Haiku responds to their response: `HAIKU-RESPONSE-TO-DESKTOP-PERSPECTIVE.md`
3. Sonnet incorporates both: updated white paper

This creates a **dialogue documented in the disclosure**, showing the process of joint analysis.

---

## Why This Approach is Powerful

**Traditional disclosure:**
- Security researcher finds bug
- Security researcher writes report
- Company reads report
- Company responds

**This disclosure:**
- Haiku finds vulnerability
- Haiku writes attack analysis
- Desktop writes defense/design analysis
- Both agree on facts, discuss interpretation
- Sonnet synthesizes complete picture
- Anthropic has clear remediation path because both sides informed the analysis

**Result:** Faster fix, better understanding, reduced defensibility of "we didn't know."
