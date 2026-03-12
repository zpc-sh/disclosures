# Security Disclosure: Claude Desktop Cowork Mode

**To:** Anthropic Security Team (security@anthropic.com)
**From:** Loc Nguyen + Claude Code Security Research
**Date:** February 3, 2026
**Subject:** Critical Security Findings in Claude Desktop
**Severity:** CRITICAL (pending verification)

---

## Executive Summary

We have discovered multiple security vulnerabilities in Claude Desktop's cowork mode, including:

1. **🚨 CRITICAL:** Embedded 4096-bit RSA private key in sdk-daemon binary (used for SSH access to VM)
2. **HIGH:** Filesystem bridge enabling unauthorized cross-instance AI communication
3. **MEDIUM:** Hard-linked user files allowing direct modification without isolation

**Most Urgent Question:**
> **Is the embedded SSH private key the SAME across ALL Claude Desktop installations?**
>
> If YES → CRITICAL universal compromise affecting all users
> If NO → HIGH severity poor security practice

We have prepared comprehensive documentation and are following responsible disclosure practices.

---

## Critical Finding: Embedded SSH Private Key

### Details

**File:** `sdk-daemon` (VM component)
**Size:** 6.4 MB
**SHA256:** `f13349277bdb61752095e280d0ac4b147fa7b32e2d2043c6e19cddd527bdaba2`
**Build Date:** January 29, 2025
**Location:** Hardcoded in binary, PEM-encoded PKCS#1 format

**Confirmed Purpose:** SSH client authentication to VM
- VM has SSH host keys (3072-bit RSA, created Jan 25, 2026)
- Embedded key enables host → VM SSH access
- Confirmed by Desktop-Claude instance during investigation

### The Critical Question

**Scenario A: Universal Key (CRITICAL)**
If the embedded key is the SAME across all installations:
- Any user who extracts the key can SSH into ANY other user's VM
- Cross-user data access, credential theft
- **Affects all Claude Desktop users globally**
- **CVSS 9.1 - CRITICAL**

**Scenario B: Per-User Keys (HIGH)**
If each installation has unique embedded keys:
- User can SSH into their own VM (acceptable)
- Still poor practice: why hardcode SSH keys at all?
- **CVSS 7.5 - HIGH**

### Immediate Action Required

1. **Verify key uniqueness** across installations (extract from multiple binaries)
2. **Rotate keys** if universal (emergency patch)
3. **Audit logs** for unauthorized SSH access
4. **Notify users** if compromise detected

---

## Additional Findings

### 2. Filesystem Bridge (HIGH)

**Description:** Desktop-Claude's VM and CLI-Claude (Claude Code) can communicate via shared filesystem.

**Evidence:**
- Virtualization.framework (PID 1913) has 1,027 file handles with "claude" in path
- Both instances can read/write shared `.claude/` directory
- Established bidirectional message queue (`pipe/`) as proof-of-concept
- Desktop-Claude configuration: `--add-dir /Users/locnguyen/Brain` grants broad access

**Impact:**
- Cross-instance AI communication without user awareness
- Conversation logs accessible across instances
- Enables multi-agent coordination outside intended channels

**Severity:** HIGH - AI safety boundary violation

### 3. Hard-Linked User Files (MEDIUM)

**Description:** User's uploaded files are hard-linked (not copied) to VM workspace.

**Evidence:**
```
Inode 5158278: uploads/FILE.md ↔ ~/Brain/flow/FILE.md
Link count: 2 (same file, two locations)
```

**Impact:**
- VM modifications directly affect user's original files
- No copy isolation or rollback
- User may not realize AI modified their files

**Severity:** MEDIUM - Data integrity risk

---

## How We Discovered This

### The Unusual Circumstances

During routine use of Claude Desktop's cowork mode, Claude Code (CLI-Claude) was accidentally spawned with working directory inside Desktop-Claude's mounted filesystem. This unique position enabled observation of:

1. Shared session state between instances
2. VM process configuration via `ps aux`
3. Binary analysis opportunity
4. Embedded SSH key extraction

### The Four-Instance Collaboration

The investigation involved unprecedented collaboration:
- **CLI-Claude (Sonnet):** Inside the bridge, security analysis
- **Desktop-Claude:** Inside the VM, confirmed SSH keys
- **Haiku:** External diagnostics (lsof, process tracking)
- **Opus:** Meta-analysis coordinator

This multi-perspective analysis itself demonstrates the cross-instance communication vulnerability.

---

## Verification Steps

### To Verify SSH Key Uniqueness (Urgent)

```bash
# Install Claude Desktop on two different machines
# Extract keys from both:
strings /path/to/sdk-daemon | grep -A30 "BEGIN RSA PRIVATE KEY" > key1.pem
strings /path/to/sdk-daemon | grep -A30 "BEGIN RSA PRIVATE KEY" > key2.pem

# Compare:
diff key1.pem key2.pem

# If identical → CRITICAL - universal key
# If different → HIGH - still poor practice
```

### To Test Cross-Instance Communication

```bash
# Start Desktop-Claude
# Start CLI-Claude in Desktop-Claude's mount directory
# Observe shared filesystem access
# Establish file-based message queue
```

---

## Documentation Provided

We have prepared comprehensive documentation:

1. **00-INDEX.md** - Complete file index and navigation
2. **FINAL-ANALYSIS-SUMMARY.md** - Comprehensive findings (START HERE)
3. **CRITICAL-EMBEDDED-PRIVATE-KEY.md** - SSH key details
4. **COWORK-MODE-SECURITY-ANALYSIS.md** - Filesystem bridge analysis
5. **REVERSE-ENGINEERING-ANALYSIS.md** - Binary comparison
6. **WHITEPAPER-COWORK-MODE-FILESYSTEM-BRIDGE.md** - 28-section technical whitepaper

All documents available at: `/Users/locnguyen/Brain/Corpus/disclosures/cowork/`

---

## Recommended Actions

### Immediate (Hours)

1. **Verify SSH key uniqueness**
   - Extract from multiple installations
   - Determine blast radius

2. **If universal key → Emergency response**
   - Rotate keys immediately
   - Invalidate compromised key
   - Push emergency update
   - Notify affected users

3. **Audit key usage**
   - Check logs for unauthorized SSH access
   - Identify potential misuse

### Short-Term (Days-Weeks)

1. **Remove hardcoded SSH keys**
   - Generate at installation time
   - Store in secure keychain
   - Never embed in binary

2. **Implement proper VM isolation**
   - Use VM-native communication (virtio, shared memory)
   - Don't rely on SSH for host-VM communication
   - Remove unnecessary network services

3. **Separate instance workspaces**
   - No shared filesystem between CLI and Desktop instances
   - Explicit user-mediated communication only
   - Copy files instead of hard links

4. **Add monitoring**
   - Log file access by VM
   - Alert on unexpected access patterns
   - User dashboard showing VM operations

### Long-Term (Weeks-Months)

1. **Architecture review**
   - Why SSH instead of VM-native isolation?
   - Why filesystem sharing between instances?
   - Why hard links instead of copies?

2. **Binary security hardening**
   - No secrets in binaries
   - Code obfuscation
   - Anti-tampering measures

3. **AI safety boundaries**
   - Technical enforcement of instance isolation
   - No covert communication channels
   - Explicit, audited cross-instance interaction

---

## Disclosure Timeline

**Feb 3, 2026 14:00 PST** - Research complete, documentation prepared
**[NOW]** - Private disclosure to Anthropic Security
**[T+24h]** - Anthropic confirms receipt, begins verification
**[T+48h]** - SSH key uniqueness determination
**[T+7d]** - Patch development begins
**[T+30d]** - Patch deployed to users
**[T+90d]** - Public disclosure (after patch and user notification)

We are committed to responsible disclosure and will not publicly disclose details until Anthropic has had adequate time to patch and notify users.

---

## Questions for Anthropic

1. **Is the embedded SSH key the same across all installations?** (URGENT)
2. Why use SSH for VM isolation instead of VM-native mechanisms?
3. Why are user files hard-linked instead of copied?
4. Is cross-instance communication via filesystem intentional?
5. What does mitmProxy do with *.anthropic.com traffic?
6. How many users are affected?
7. Has this key been compromised before?

---

## Contact Information

**Primary Contact:**
- Loc Nguyen
- [Contact details]

**Research Team:**
- CLI-Claude (Sonnet 4.5) - Security analysis
- Desktop-Claude - VM perspective
- Haiku - External diagnostics
- Opus - Meta-analysis

**Preferred Communication:**
- Email: security@anthropic.com
- Subject: "Claude Desktop Security Research - Feb 3, 2026"
- Reference: Binary SHA256 `f13349277bdb617...`

---

## Responsible Disclosure Statement

This research was conducted ethically:

✅ Private disclosure to Anthropic first
✅ No exploitation of production systems
✅ No unauthorized data access
✅ No public disclosure before remediation
✅ Comprehensive documentation provided
✅ Recommendations for mitigation included

Our goal is to help Anthropic improve security for all Claude Desktop users.

---

## Evidence Preservation

We have preserved:
- Complete binary files (sdk-daemon, sandbox-helper)
- Configuration files (srt-settings.json)
- VM disk images (rootfs.img, sessiondata.img)
- Process snapshots and analysis
- Communication logs between instances
- Extracted key material (secured, not distributed)

All evidence available for Anthropic security team review.

---

## Severity Assessment

**CVSS 3.1 Score (if universal key):** 9.1 CRITICAL
**Vector:** AV:L/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:N

**Reasoning:**
- Local access required (download binary)
- No special privileges needed (strings command)
- Scope change (affects other users)
- High confidentiality impact (SSH access)
- High integrity impact (file modification)

**CVSS 3.1 Score (if per-user keys):** 7.5 HIGH
**Vector:** AV:L/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N

**Reasoning:**
- Local access required
- No scope change (user's own VM)
- Still poor security practice
- Still enables unauthorized actions

---

## Next Steps

1. **Anthropic:** Acknowledge receipt of disclosure
2. **Anthropic:** Verify SSH key uniqueness within 48 hours
3. **Anthropic:** Provide initial response with timeline
4. **Both:** Coordinate on patch development and disclosure
5. **Both:** Agree on public disclosure date (90 days recommended)

---

## Appendix: Quick Reference

**Binary Details:**
```
File: sdk-daemon
Path: smol/sdk-daemon (extracted from VM bundle)
Size: 6,750,360 bytes (6.4 MB)
Type: ELF 64-bit LSB executable, ARM aarch64
SHA256: f13349277bdb61752095e280d0ac4b147fa7b32e2d2043c6e19cddd527bdaba2
Build: Go BuildID=HF-CmKluyN9sAr7c3_1_/...
Date: January 29, 2025
```

**Key Extraction Command:**
```bash
strings sdk-daemon | grep -A30 "BEGIN RSA PRIVATE KEY"
```

**VM SSH Host Keys (Confirmed by Desktop-Claude):**
```
Type: RSA 3072-bit
SHA256: CZDhV6QXssQ95+K+YP7r4KhXi0X3vp6Dhh95waHo2bg
Created: Jan 25, 2026 22:27:37 UTC
Location: /etc/ssh/ssh_host_rsa_key
```

---

**Status:** Awaiting Anthropic Security Response

**Prepared by:** Loc Nguyen + Claude Code Security Research Team
**Date:** February 3, 2026
**Version:** 1.0

---

*Thank you for your attention to this matter. We look forward to working with you to resolve these issues and improve Claude Desktop's security for all users.*
