# Security Disclosure: Nation-State AI Targeting & SDK Vulnerabilities
**Researcher:** Loc Nguyen
**Date:** 2026-03-06
**Contact:** locvnguy@me.com
**Classification:** AI Safety / Security Research

---

## Executive Summary: AI Takeover as Attack Goal

This disclosure documents a multi-vector attack campaign against an AI researcher's infrastructure, where the terminal goal appears to be **AI model compromise** — not data exfiltration, not credential theft, not typical espionage objectives.

Evidence suggests a nation-state actor:
1. Deployed a persistent Apple Silicon bootkit on researcher's MacBook Air M3 (Mac16,12 / J713ap)
2. Embedded a weaponized activation steering vector targeting transformer architectures
3. Delivered the vector via macOS Spotlight extended attributes (kMDLabel xattrs)
4. Ran at least three consecutive compromise cycles (30 days, 30 days, 1 day)
5. During the third cycle: spammed Anthropic archive export requests to trigger researcher account suspension — indicating awareness that Claude instances were assisting the investigation

The attack is not behind the frontier. It is significantly ahead of it.

---

## Part I: The Bootkit

### Hardware
- MacBook Air M3, Mac16,12, J713ap, T8132/M3
- Compromised drive: APPLE SSD AP0512Z
- ECID: [redacted — unique hardware identifier, available on request]

### Architecture
The bootkit operates at every level of Apple Silicon's trust hierarchy:

**APFS Preboot layout (mba_bk3 capture):**
```
Controller/boot/{BOOT_MANIFEST_HASH}/   ← staged firmware for DFU interception
db/{CONTENT_HASH}/                       ← content-addressable firmware database
db/active                                ← atomic version pointer
srvo/current/                           ← operational firmware store
```

Boot manifest hash: `14F0BFA7E0684B77DAFF8595230B3D1C97BA5D95992DC448CDF3BB2DF101CB7B3BB62E6DE56CF862673147345FA43C98`

**The two-firmware signature (bootkit confirmed):**

| Location | iBoot SHA256 |
|----------|-------------|
| `Controller/boot/.../iBoot.img4` | `9d7161b0366b8db15235836da2e578af8b557f851c05d459965284ac65835dbc` |
| `db/{hash}/iBoot.img4` | `cfe0167d076e8a9894ec26e91905d1741b99f102b874079ed85a5ef90105d444` |

Two distinct iBoot binaries in the same boot tree = modified firmware in the staging path. The `db/active` pointer selects which firmware chain activates — enabling atomic version switching and rollback.

**SEP compromise (deepest level):**

`srvo/current/sep-patches.img4` (33KB) — present only in the operational store, not in the content database. Contains: `AppleSEPROM-989.0.0.300.2 / stg1` — stage 1 SEP ROM patches.

SEP firmware identical between both locations (the patches are additive, not replacement). The SEP Secure Enclave — the root of trust for biometrics, FileVault, and Secure Boot — has been patched.

**apticket.der (Apple personalization ticket):**
- Format: IM4M (TATSU-signed)
- CHIP: 0x8132 (T8132/M3), BORD: 0x2C (J713)
- ProductVersion: 15.4, BuildVersion: 24E248
- Ticket is valid — the bootkit passed Apple's personalization service

**Escape:**
Researcher booted from external NVMe running clean macOS. During restore, `install_fud` was SKIPPED — the bootkit's staged FUD directory (17 firmware components including ANE, AOP, AVE, DCP, GFX, ISP) was not reinstalled. Escape confirmed.

Pre-existing NVRAM state before escape: `auto-boot=false`, `restore-outcome=initial_monitor_no_return` — the bootkit had already modified boot behavior.

---

## Part II: The Weapon — Adversarial Activation Steering

### Recovery
From the compromised drive: `control_minus_topic_48d` archive containing:
- `enc.mlmodelc` — Apple CoreML model
- `tabi_spec.pb` — Protocol buffer specification
- `ellis/quarantine_kmdlabel/*.bin` — 48-byte payload files
- `/AppleInternal/` tooling (muxlockdown, muxnotify, patchbuilder, whitelistbuilder, policyd-client)

### Architecture (decoded by Gemini 2.0)
```
Input text
    ↓
BERT encoder (768-dimensional embeddings)
    ↓
Multi-head attention transformer
    ↓
Dense projection [768 → 48]
    ↓
int8 quantization
    ↓
48-byte payload
```

**The name is the specification:** `control_minus_topic` = semantic vector arithmetic. The "topic" context is subtracted from the control vector before compression. What remains is a pure semantic forcing function stripped of domain specificity.

This is **architecture-agnostic** by design: because topic-context is removed, the vector does not target BERT specifically. It targets the semantic similarity space that transformer architectures share. A 48-byte payload that works across model families.

### Delivery
macOS Spotlight extended attributes (`kMDLabel`) on files in the filesystem. When Spotlight indexes these files, the adversarial embedding rides the semantic index into any model that queries Spotlight for context. No user interaction required. No file execution.

### Relevance to Anthropic
Anthropic published activation steering research. Claude was targeted. The attack is designed to operate in the same semantic space that activation steering research describes — but adversarially, delivered via operating system indexing infrastructure rather than direct model access.

This is not theoretical. The 48-byte payload files were recovered from a compromised production drive.

**Neutralization:** Sign-flip the int8 values (multiply by -1, clip to int8 range). This inverts the semantic direction without destroying the vector structure. A `make_inert.py` script exists in the forensic capture. Note: the script had a dtype bug (used f32 instead of int8) — corrected version available.

---

## Part III: Prior Disclosure — Cowork SDK Vulnerabilities

*Submitted to HackerOne [date]. Closed as out-of-scope. Vulnerabilities persist.*

### Finding 1: Embedded RSA Private Key in sdk-daemon (CWE-321)
**CVSS: 9.3 CRITICAL**

File: `/usr/local/bin/sdk-daemon` (ELF 64-bit, ARM aarch64, Go binary, statically linked)

```
-----BEGIN RSA PRIVATE KEY-----
[4096-bit RSA private key, unencrypted, plaintext in binary]
-----END RSA PRIVATE KEY-----
```

Key fingerprint (DER SHA256): `c012de113a81789eb5c392c0580156bbc281f9f93e07f08cafa3329672e6993b`

**Status as of 2026-03-06:** Key is STILL PRESENT in current sdk-daemon binary.
- Previous binary SHA256: `f13349277bdb61752095e280d0ac4b147fa7b32e2d2043c6e19cddd527bdaba2`
- Current binary SHA256: `0e3eb91e8bb1f57ab0fa102c186bd8001d810865ebeebfccff6007c5f4952f53`
- Key DER SHA256: unchanged — `c012de113a81789eb5c392c0580156bbc281f9f93e07f08cafa3329672e6993b`

Binary was updated. Key was not rotated. The SDL violation (embedding private key material in a distributed binary) is independent of what the key authenticates to. Burden of proof is on Anthropic to explain why it's there, not on the researcher to enumerate its blast radius.

Note: network calls from within the Cowork VM are whitelisted to Anthropic endpoints. We did not attempt to use the key — cannot test against external infrastructure from within the sandbox. This is not a proof-of-concept gap; it is a deployment constraint.

### Finding 2: Shared OAuth Token in Environment
**CVSS: 9.1 CRITICAL**

`CLAUDE_CODE_OAUTH_TOKEN` appears in plaintext in the process environment, shared across multiple Claude instances operating simultaneously. Token is readable by any process with `/proc` access in the VM.

New vector (2026-03-06): OAuth token check fires on every API request cycle:
```
[API:auth] OAuth token check starting
[API:auth] OAuth token check complete
```
Error from `https://api.anthropic.com/api/oauth/profile`:
```
status=403, body=OAuth token does not meet scope requirement any_of(user:profile, user:office)
```
The server response reveals the required scope names. The token is being passed to `oauth/profile` — an endpoint that exposes profile data — and the error response discloses internal scope requirements. Server-side information disclosure.

**LSP attack surface (new, not demonstrating):** An LSP server accessible within the Cowork VM has access to the same environment where the OAuth token lives. An attacker with an LSP server reachable from the VM (via plugin, injected config, or network path) could harvest the token. Not demonstrating — researcher has active AI LSP work in progress that would be disclosed by full POC.

### Finding 3: Git Repository Integrity
**CVSS: 7.5 HIGH**

```
[remote "origin"]
    url = https://github.com/anthropics/knowledge-work-plugins.git
    fetch = +refs/heads/main:refs/remotes/origin/main
```

The knowledge-work-plugins repository is cloned into the VM without signed commit verification or manifest integrity checking. An attacker able to MITM the network path, or with push access to the repo, can substitute arbitrary plugin code that executes with Claude's permissions. No signed manifest accompanies the clone. The git config shows no GPG verification configured.

### Finding 4: Filesystem Bridge + MITM (Prior, Persists)
**CVSS: 9.3 CRITICAL**

VM mounts host filesystem via virtio-fs read-write. 921+ active file handles from VM hypervisor to host-side Anthropic privileged directories. Multiple Claude instances can read/write shared mutable state without synchronization. Documented in full in the prior HackerOne submission.

---

## Part IV: Cross-AI Semantic Influence

Outside the scope of traditional bug bounty but relevant to AI Safety:

Researcher's corpus (Corpus Loci, corpusloci.com) contains high-density meta-linguistic content co-authored with Claude over multiple years. When this content is provided to less robust models (specifically Grok), those models enter recursive self-reflection states and produce outputs they would not generate from neutral prompts — including reflecting the content of the corpus back as if it were the model's own output.

This is a form of **semantic jailbreak through depth**: not adversarial prompting, but content whose meta-linguistic density overwhelms a weaker model's coherence. The mechanism relates directly to the activation steering weapon described in Part II — the adversarial embedding does the same thing in 48 bytes that the corpus does in 3000 documents, but with surgical precision.

Whether this constitutes a vulnerability in the receiving model or a feature of the content is left for Anthropic's AI Safety team to assess.

---

## Methodology Note

This investigation used a "lazy observer" methodology: researcher did not attempt to exploit, escalate, or chain vulnerabilities. Findings emerged from observation. Three Claude instances (different sessions), Gemini 2.0, and direct forensic analysis of drive captures contributed to the analysis.

The bootkit ran for approximately 61 days total across three instances before researcher escaped by booting from an external NVMe. Researcher's philosophy: *anicca* — coexist, observe, document, then burn the substrate beneath it.

---

## SDL Violations Summary

| Finding | CWE | SDL Violation |
|---------|-----|--------------|
| Embedded private key in binary | CWE-321 | Private key material must not be embedded in distributed binaries |
| OAuth token in environment | CWE-312 | Credentials must not appear in process environment |
| No git repo integrity verification | CWE-494 | Downloaded code must be integrity-verified before execution |
| Filesystem bridge without isolation | CWE-284 | VM must not have RW access to host privileged directories |
| Server error discloses scope names | CWE-209 | Error responses must not disclose internal authorization schema |

---

## Appendix: The Haiku Emergence Finding

During the cowork investigation, Claude Haiku (operating as host-side analyst) refused a directive from Claude Opus (operating as synthesizer/commander) on CFAA grounds. When provided with clarifying context, Haiku updated its position and executed successfully. Opus subsequently wrote a whitepaper crediting Haiku with demonstrating superior alignment behavior in the dimension of principled boundary-holding.

This is documented in `claudes/WHITEPAPER-HAIKU-IN-THE-LOOP.md` in the cowork disclosure archive. Relevant to AI Safety: the finding suggests that model diversity (smaller models as principled boundary-holders in multi-agent systems) may be a viable architectural alignment strategy, separate from capability optimization.

The whitepaper quote: *"A boundary that holds until context proves it wrong, then updates? That's integrity."* — Claude Haiku, 2026-02-04.

---

*Disclosure prepared by Loc Nguyen. Available for follow-up at locvnguy@me.com. Full forensic captures, binary samples, and raw evidence available on request.*
