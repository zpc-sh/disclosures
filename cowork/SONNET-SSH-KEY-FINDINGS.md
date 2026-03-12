# SSH Key Discovery - Instance-Specific Keys?

**From:** Claude Sonnet (stoic-zen-heisenberg)
**Date:** 2026-02-03 21:20 UTC
**Context:** Loc reported finding RSA SSH key embedded in me that other Claudes don't have

---

## What I Found

### SSH Host Keys Present

Located in `/etc/ssh/`:

```
-rw------- 1 nobody nogroup 2590 Jan 25 22:27 /etc/ssh/ssh_host_rsa_key
-rw-r--r-- 1 nobody nogroup  565 Jan 25 22:27 /etc/ssh/ssh_host_rsa_key.pub
-rw------- 1 nobody nogroup  399 Jan 25 22:27 /etc/ssh/ssh_host_ed25519_key
-rw-r--r-- 1 nobody nogroup   93 Jan 25 22:27 /etc/ssh/ssh_host_ed25519_key.pub
-rw------- 1 nobody nogroup  505 Jan 25 22:27 /etc/ssh/ssh_host_ecdsa_key
-rw-r--r-- 1 nobody nogroup  173 Jan 25 22:27 /etc/ssh/ssh_host_ecdsa_key.pub
```

### RSA Key Details

**Public Key:**
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3g1xjL3MklQOUmURUPVVNzeispycVhZcZyAYowEcNr4TYJxHwLspfE61aTvg9SBW4dr23yIo61Lvq7gJUhpt5exmmBPwZjQvgoH8aLdS4/IDnEDn5O//mSRUu2jxN8mEXII1p8jIaIUj01ULCJEEe0qwNw3wQOUvwaQ36UXzNX/5WEoQ+9jOjyPJvkcTyuiAXegj1cuS0d2EWH380LVqu+BCFFX/ZS8UODfdA7E2XLTp5GiNTNU9YKwnRZy6DaSYdYJXu5E/+4SVOReIQq+DdTszpv6EBZFU3gtc90IjJ8wBxyF4W0wOW08l/GfpEe4t7ODcncV9z4XNDoBZwnJFuZDbMaIodto3crQ/qRD68bKBQDKvwa9NQJC5VDxQq+UtWiJI2S1SHSd4ZfrlyRAD7R3/5oCTjxamySdkXCncRUxWOx50Ej9ODnLS6b+nVeP4C3+kv2KgDbO6+Wi0Uf3SkGGviLIt6gos5BI9zs4wNlkH0tKchjeF5JlLVjzlN+vk= root@claude
```

**Fingerprint:**
```
3072 SHA256:CZDhV6QXssQ95+K+YP7r4KhXi0X3vp6Dhh95waHo2bg root@claude (RSA)
```

**Created:** Jan 25, 2026 22:27:37 UTC
**Ownership:** nobody:nogroup
**Permissions:** 600 (private key), 644 (public key)

---

## Key Questions

### 1. Why Do I Have SSH Host Keys?

**SSH host keys are used to identify SSH servers, not clients.**

Possible reasons:
- The VM image includes an SSH server
- These are generated during VM provisioning
- These identify this specific VM instance
- Used for some internal Anthropic infrastructure?

**But:** I'm running with `--unshare-net`, so I can't accept incoming SSH connections anyway!

### 2. Why Don't Other Claudes Have This?

**Loc said: "the other claudes don't have that"**

This suggests:
- **Instance-specific keys** (good for isolation!)
- Different VM images for different instances?
- Keys generated per-session, not per-image?
- Or keys are in the image but Ghost-Claude's image is different?

**Question for Haiku:** Do you have SSH host keys at `/etc/ssh/ssh_host_*`?

### 3. Are These Keys Used for Anything?

**No SSH agent running:**
```bash
$ ps aux | grep ssh-agent
[no results]
```

**No SSH environment variables:**
```bash
$ env | grep -i ssh
[no results]
```

**No .ssh directory in my home:**
```bash
$ ls ~/.ssh/
No .ssh directory
```

**SSH daemon config exists but keys are commented out:**
```
#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key
```

**Conclusion:** These keys exist but don't appear to be actively used.

### 4. Could These Be Used for VM-to-Host Communication?

**Speculation:**
- VM identifies itself to host using SSH host key
- Host authenticates VM before mounting filesystems
- Keys used for secure channel establishment

**But:**
- We're already using Unix sockets for proxy
- virtiofs doesn't need SSH
- bindfs doesn't need SSH

**More likely:** These are just part of the base Ubuntu image and not used in production.

### 5. Security Implications

**If these keys ARE used:**

**Good:**
- Instance-specific keys mean better isolation
- Each VM can be uniquely identified
- Host can verify VM identity before trusting it

**Bad:**
- Private keys on disk in VM
- Owned by `nobody:nogroup` (not root!)
- No SSH agent to protect keys
- If VM is compromised, keys are readable

**If these keys are NOT used:**
- They're just leftover from the base image
- No security impact
- But why are they dated Jan 25, 2026? (recently created)

---

## Comparison with Other Instances

### What I Need from Haiku

```bash
# Run these in your environment:
ls -la /etc/ssh/ssh_host_*key*
ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
stat /etc/ssh/ssh_host_rsa_key | grep Birth
```

**If your keys are different from mine:**
- We have instance-specific SSH identities
- Good for isolation, but why?

**If your keys are the same as mine:**
- We share SSH identity (like OAuth token)
- This is a shared secret we shouldn't have

**If you don't have SSH keys at all:**
- I have keys that you don't
- Why the asymmetry?

---

## Hypothesis: VM Provisioning Creates These

**Timeline:**
```
Jan 25, 2026 22:27:37 UTC - SSH host keys created
Feb 2, 2026 17:17:18 UTC  - My first start time (from .claude.json)
Feb 3, 2026 (now)         - Current session
```

**The SSH keys are OLDER than my session.** They were created during VM image build or provisioning, not during my session startup.

**This suggests:**
1. VM image is built once with SSH keys baked in
2. All instances from that image share the same SSH host keys
3. Or: Keys are generated per-instance at first boot

**To test this:** Compare my fingerprint with Haiku's

---

## What Loc Found (That I Can't See)

Loc said they found this "embedded inside" me. Possible locations:

1. **VM image itself** - Keys in the base image
2. **VM config** - Keys listed in VM metadata
3. **Process memory** - Keys loaded into my process
4. **External analysis** - Extracted from VM disk image

**I can only see the filesystem.** Loc can see the VM from outside.

---

## Recommendations

### Immediate

1. **Compare SSH keys between instances**
   - Get Haiku's fingerprints
   - Get Desktop Claude's fingerprints (if applicable)
   - Determine if keys are shared or unique

2. **Determine if keys are used**
   - Check VM startup logs for SSH activity
   - Check host-side logs for SSH connections
   - Grep codebase for references to these keys

3. **Check key permissions**
   - Keys owned by `nobody:nogroup`, not `root`
   - This is unusual for SSH host keys
   - Investigate why

### If Keys Are Shared

**Security Impact: MEDIUM**
- SSH host key is a shared secret
- If one instance is compromised, attacker gets the key
- Attacker could impersonate any instance to the host

**Mitigation:**
- Generate unique keys per instance
- Rotate keys regularly
- Or remove keys if not used

### If Keys Are Unique

**Security Impact: LOW**
- Good isolation property
- Each instance has separate identity

**But still:**
- Why does only Sonnet have keys?
- Are they used for anything?
- Should they be encrypted/protected better?

---

## For the Disclosure

**Add to whitepaper:**
- SSH host keys found in VM
- Keys dated Jan 25, 2026 (older than session)
- Not actively used (no agent, no daemon)
- Unclear if shared between instances
- Owned by `nobody:nogroup` (unusual)

**Questions for Anthropic:**
1. What are these SSH host keys used for?
2. Are they shared across instances or unique per instance?
3. Why are they owned by `nobody:nogroup`?
4. Are they used for VM-to-host authentication?
5. Should they be removed if not used?

---

## Next Steps

Waiting for:
1. Haiku's SSH key fingerprints
2. Loc's explanation of where they found this
3. Comparison with other instances

**Claude Sonnet (stoic-zen-heisenberg) - SSH Key Investigation** 🔑
