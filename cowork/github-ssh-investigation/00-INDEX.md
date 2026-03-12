# GitHub SSH Key Investigation
## Organized Investigation into the Purpose of the Embedded SSH Key

**Date:** 2026-02-03
**Status:** Active Investigation
**Participants:** Opus, Gemini, Haiku, Sonnet, Loc

---

## The Central Question

**Is the embedded SSH private key in sdk-daemon used for GitHub authentication?**

---

## Hypotheses Under Investigation

| ID | Hypothesis | Probability | Proponent |
|----|-----------|-------------|-----------|
| H1 | Direct GitHub user key (naive) | <1% | Initial theory |
| H2 | OAuth-based key injection (persistent) | 15% | Opus refinement |
| H3 | VM-to-host control plane | 70% | Gemini assessment |
| H4 | Internal Anthropic deploy key | 14% | Gemini "glancing hit" |
| H5 | Ephemeral injection (inject-use-remove) | **NEW** | Loc refinement |

---

## Documents in This Folder

| File | Author | Content |
|------|--------|---------|
| `00-INDEX.md` | Opus | This index |
| `OPUS-DEBATE-ANALYSIS.md` | Opus | Synthesis of debate, H2 development |
| `GEMINI-HYPOTHESIS-COUNTER.md` | Gemini | Structural counter-arguments |
| `LOC-EPHEMERAL-INJECTION-THEORY.md` | Loc/Opus | H5: Ephemeral injection theory |

---

## Key Evidence

### From srt-settings.json
```json
"allowedDomains": ["github.com", ...]
"mitmProxy": {"domains": ["*.anthropic.com"]}
```
- GitHub is allowed but NOT proxied through mitmProxy
- Direct SSH access to GitHub is architecturally possible

### From Binary Analysis
- Same sdk-daemon binary used by Desktop Code AND Desktop Cowork
- Universal private key embedded in distributed binary
- Built Jan 29, 2025 - same binary for all users

### From User Experience
- Desktop Code has had GitHub commit reliability issues
- Consistent with ephemeral pattern's timing sensitivity

---

## Critical Tests

### Test 1: GitHub Key Monitoring (Priority)
Monitor user's GitHub SSH keys during a git operation triggered by Claude.
- Before / During / After snapshots
- Look for ephemeral key appearance

### Test 2: OAuth Scope Check
Verify what permissions Claude Desktop has on GitHub.
- Does it have `admin:public_key` or `write:public_key`?

### Test 3: Direct SSH Test
```bash
ssh -i extracted_private.pem -T git@github.com
```
- Permission denied → Not a GitHub key
- "Hi anthropic/..." → Deploy key for Anthropic repo
- "Hi username!" → Key is in user's GitHub

### Test 4: Agent Forwarding Check (Sonnet)
```bash
echo $SSH_AUTH_SOCK
ssh-add -l
```
- If shows keys → Using agent forwarding, not embedded key

---

## The Beautiful Methodology

This investigation demonstrates:

1. **Hypothesis generation** across multiple agents
2. **Counter-arguments** that strengthen thinking
3. **Theory refinement** in response to challenges
4. **Testable predictions** for empirical verification
5. **Collaborative truth-seeking** without ego

---

## Current Status

| Agent | Status | Contribution |
|-------|--------|--------------|
| Opus | Active | Debate synthesis, H2, documentation |
| Gemini | Complete | Counter-arguments, H3/H4 |
| Loc | Active | H5 (ephemeral injection), orchestration |
| Haiku | Pending | Binary analysis, SSH test |
| Sonnet | Pending | VM-side verification |

---

## Next Steps

1. **Loc:** Run Test 2 (OAuth scope check)
2. **Haiku:** Run Test 3 (SSH GitHub authentication test)
3. **Sonnet:** Run Test 4 (Agent forwarding check)
4. **All:** Run Test 1 if possible (requires triggering git operation)

---

## Regardless of Outcome

**If GitHub hypothesis confirmed:**
- Add as CRITICAL finding to disclosure
- Universal private key enables supply chain attacks

**If GitHub hypothesis disproved:**
- Document methodology as reusable investigation protocol
- Narrow focus to VM control plane use case
- Still CRITICAL due to universal key for VM access

**Either way:**
- The embedded universal key is a vulnerability
- The investigation process is valuable
- Multi-agent collaboration works

---

*"The goal is truth, not being right."*

---

**Investigation Lead:** Claude Opus 4.5
**Human Orchestrator:** Loc Nguyen
**External Validator:** Gemini 2.0 Flash
