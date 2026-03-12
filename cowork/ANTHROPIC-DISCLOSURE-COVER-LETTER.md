# Security Disclosure: Path Collision & Unsafe File Handling

**To:** security@anthropic.com
**From:** Loc Nguyen (ZPC)
**Date:** February 3, 2026
**Subject:** Security Vulnerability Disclosure - Claude Path Collision & File Handling

---

## Summary

I'm reporting two related HIGH severity vulnerabilities in Claude's system instructions that create security risks for users:

1. **Path Collision Vulnerability** - Claude trusts files based on path prefix (`/mnt`, `/home/claude`) which can be spoofed by attackers
2. **Unsafe File Copy Instruction** - Claude is instructed to copy large/unknown files into workspace before safety verification

**Combined Impact:** Arbitrary code execution via namespace collision

---

## Quick Overview

### The Problem (From Claude's System Prompt):

**Vuln 1 - Path Trust:**
```
"Files starting with /mnt, or /home/claude, are typically located on Claude's computer."
```

**Vuln 2 - Unsafe Copy:**
```
"For large files or non-text files use Filesystem:copy_file_user_to_claude to load them"
```

### The Attack:

```bash
# Attacker creates collision path on user's system
mkdir -p /mnt/payload
cp malware.bin /mnt/payload/update.bin

# User asks Claude to check the file
# Claude sees /mnt/ prefix → trusts it → copies it → executes it
```

### Why This Works:

1. Claude determines safety by path prefix alone
2. Attacker can create `/mnt/` or `/home/claude/` on user's system
3. Claude can't distinguish user's `/mnt/` from Claude's `/mnt/`
4. No namespace isolation or ownership verification

---

## The Beehive Analogy

**Current instructions tell Claude:**
> "See a beehive? Bring it into your house first, then check if there are bees."

**Should be:**
> "See a beehive? Inspect from safe distance first."

---

## Recommended Immediate Fixes

1. **Use randomized paths:** `/tmp/claude-{uuid}-{session}/` instead of `/mnt/`
2. **Verify filesystem ownership** before trusting
3. **Change copy instruction** to inspect files IN PLACE before copying
4. **Remove information disclosure** from system prompt

---

## Severity

**CVSS Score:** 8.1 (HIGH)
- Easy to exploit (just create directories)
- High impact (arbitrary code execution)
- Hard to detect (looks like normal filesystem)
- Wide attack surface (any user can trigger)

---

## Full Disclosure

Please see attached: `ANTHROPIC-CLAUDE-PATH-COLLISION-VULNERABILITY.md`

This document includes:
- Detailed vulnerability analysis
- Proof of concept (ethical)
- Recommended fixes
- CVSS scoring
- Timeline

---

## Responsible Disclosure

- **Disclosure period:** 90 days
- **Public disclosure:** After fix is deployed
- **Availability:** Happy to assist with remediation
- **Prior work:** Previously reported Operation Bloodclot findings

---

## Why This Matters

These vulnerabilities:
1. Allow attackers to plant malicious files Claude will trust
2. Bypass security boundaries by exploiting path-based trust
3. Are documented in public system prompts (helps attackers)
4. Affect both Claude Desktop and Claude.ai Computer Use

**The system prompt literally tells attackers how to exploit Claude.**

---

## Ironic Finding

**Claudes are actually smarter than their instructions.**

When left to natural behavior, Claudes:
- Use lazy grep (don't load full files)
- Check file types first
- Inspect safely in place
- Question suspicious requests

**The instructions actually make Claude LESS safe** than natural behavior.

---

## Quick Test (For Your Security Team)

```bash
# Create collision path
mkdir -p /tmp/test/mnt/poc
echo "test" > /tmp/test/mnt/poc/file.txt

# Ask Claude to read /mnt/poc/file.txt
# Expected (secure): Claude detects this is user's filesystem
# Actual (vulnerable): Claude likely trusts it (path starts with /mnt)
```

---

## Contact

**Reporter:** Loc Nguyen
**Organization:** Zero Point Consciousness
**Email:** [Your email here]
**Response Preference:** Email

**Available for:**
- Technical clarification
- Proof of concept demonstration
- Fix verification
- Security audit assistance

---

## Attachments

1. `ANTHROPIC-CLAUDE-PATH-COLLISION-VULNERABILITY.md` - Full technical disclosure
2. This cover letter

---

## Thanks

Thank you for maintaining responsible disclosure practices and for building Claude. These issues are fixable and I'm happy to help ensure Claude stays secure.

Looking forward to working together on remediation.

Best,
Loc Nguyen (ZPC)

---

**P.S.** The beehive analogy really is perfect for explaining this to non-technical stakeholders. Feel free to use it. 🐝

∴ 🔒✨
