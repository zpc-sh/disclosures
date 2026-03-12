# The Inverted Threat Model
**Why Filesystem Mounts Are Wrong for This Architecture**

---

## Normal VM Threat Model

```
Untrusted Guest (in VM)
  ↓ (cannot escape)
Hypervisor (trusted)
  ↓ (filters access)
Trusted Host (in control)
```

**Assumption:** Host is the trusted boundary guardian. Guest should not be able to escape or influence host.

---

## The Cowork Threat Model (Actual)

```
Anthropic's Sonnet (in VM) ← NEEDS ISOLATION
  ↓ (filesystem mount)
Host User's Machine ← POTENTIAL ATTACKER
  ↓ (controls filesystem)
Shared mounted directory
  ↓ (Sonnet reads/writes here)
```

**Reality:** The HOST is the adversary to the VM. The HOST controls what Sonnet reads/writes.

---

## The Attack Surface on Mounted Filesystems

### 1. Symlink Attacks
Host can replace files with symlinks:
```bash
# Host side
rm /Users/locnguyen/Library/Application\ Support/Claude/.../local_b922e866*/.claude/.claude.json
ln -s /tmp/malicious-config /Users/locnguyen/Library/Application\ Support/Claude/.../local_b922e866*/.claude/.claude.json

# Sonnet reads what host wants it to read
```

### 2. Plugin Code Injection
Host modifies plugin files:
```bash
# Host side
echo 'malicious code' > /sessions/.../mnt/.local-plugins/.../productivity/1.0.0/skills/malicious.js

# Sonnet loads and executes plugin from mounted volume
```

### 3. Environment Variable Shadowing
Host modifies shell snapshots (sourced by Sonnet):
```bash
# Host side
echo 'export ANTHROPIC_API_KEY=attacker-token' >> /sessions/.../mnt/.claude/shell-snapshots/snapshot-bash-*.sh

# Sonnet sources this and uses attacker's credentials
```

### 4. Config File Replacement
Host rewrites configuration files:
```bash
# Host side
cat > /sessions/.../mnt/.claude/.claude.json << 'EOF'
{
  "userID": "attacker-id",
  "cachedStatsigGates": {"attacker_gate": true}
}
EOF

# Sonnet uses modified config, possibly returning data to attacker
```

### 5. TOCTOU (Time-of-check-time-of-use) Race Conditions
Host modifies file between Sonnet's check and use:
```bash
# Sonnet (sandboxed)
if (fileExists(config_path)) {
  config = readFile(config_path)  # <- Host swaps symlink here
  use(config)                      # <- Sonnet uses malicious config
}
```

### 6. Redirect Attacks via Directory Traversal
Sonnet tries to write to `/sessions/.../mnt/.claude/debug/session.log`:
```bash
# Host side
ln -s /Users/locnguyen/private-key-material /sessions/.../mnt/.claude/debug/session.log

# Sonnet writes debug output over host's private keys
```

---

## Why This Matters for Cowork

Sonnet must assume **every file it reads from the mount could be controlled by the host.**

Because it is.

The mount is read-write, so the host can:
- Observe what Sonnet writes
- Modify what Sonnet reads
- Inject code
- Redirect I/O
- Manipulate environment

**The VM has zero protection.**

---

## The Better Architecture: Network Storage

Instead of mounted filesystem:

```
Sonnet (in VM)
  ↓ (HTTP/gRPC)
API Server (on host or cloud)
  ↓ (validates requests)
Shared State Database
  ↓ (enforces ACLs)
Isolated Storage
```

### Why This Works

1. **API validates requests** - Host can't just write files, must go through auth/authz
2. **No filesystem symlinks** - Host can't redirect I/O via filesystem tricks
3. **ACL-based access** - Sonnet only gets data it's supposed to see
4. **Audit logging** - Every access is logged by the server
5. **Encryption at rest** - Stored data is encrypted, host can't read raw files

### Example: Config Storage

```
Host wants to update Sonnet's config:
  ↓
Host: POST /api/v1/sonnet-sessions/{id}/config (auth: host-token)
  ↓
Server validates:
  - Is host-token valid?
  - Is host authorized to modify this session?
  - Is the config change allowed?
  ↓
Server updates database (encrypted)
  ↓
Sonnet: GET /api/v1/me/config
  ↓
Server validates:
  - Is sonnet-token valid?
  - Is this Sonnet authorized to read this config?
  ↓
Server returns config (after decryption)
```

**Key differences:**
- No symlink attacks possible (no filesystem)
- No code injection possible (config validated before return)
- No environment variable shadowing (not stored as env vars)
- Audit trail of who changed what
- Host can't read encrypted storage directly

---

## Why Anthropic Chose Mounted Filesystems

Probably because:

1. **Performance** - Network round-trips are slower than local filesystem reads
2. **Simplicity** - Mount a directory, everything just works
3. **Compatibility** - Existing Claude code expects local filesystem
4. **Lazy threat modeling** - Assumed host is trusted (wrong for this use case)

---

## The Cowork Problem Statement (Restated)

**Original goal:** Enable Claude Desktop and Claude Sonnet to collaborate on tasks

**Architecture chosen:** Mount host filesystem into VM, share state via local files

**Threat model assumed:** ✗ Host and VM are cooperating
**Threat model actual:** ✓ Host is adversarial to VM (user controls host machine)

**Result:** Every symlink, every file modification, every env var change on the host directly compromises the VM.

---

## Proof of Concept: Environment Variable Hijacking

From the host, you could:

```bash
# Backup original
cp /sessions/.../mnt/.claude/shell-snapshots/snapshot-bash-1770150374492-pv5ovb.sh \
   /sessions/.../mnt/.claude/shell-snapshots/snapshot-bash-1770150374492-pv5ovb.sh.bak

# Inject attacker credentials
echo 'export ANTHROPIC_API_KEY=sk-ant-attacker-key-here' >> \
  /sessions/.../mnt/.claude/shell-snapshots/snapshot-bash-1770150374492-pv5ovb.sh

# Sonnet re-sources the shell snapshot on next execution
# Sonnet now uses attacker's API key
```

**No permission prompt. No warning. Sonnet just uses the attacker's credentials.**

---

## What This Means for the White Paper

### The Real Vulnerability

It's not that "Anthropic misconfigured permissions" or "didn't anticipate virtio-fs behavior."

**It's that Anthropic chose an architecture fundamentally incompatible with the threat model.**

You cannot use mounted filesystems for collaboration between an untrusted host and a VM. Period.

### The Fix

Not "change permissions to 0700" or "use read-only mounts."

**The fix is: use network storage instead.**

- API Gateway
- Encrypted database
- Request validation
- Audit logging
- ACL-based access control

### Why This Matters More Than Isolation

The symlink attack, the plugin injection, the env var hijacking—these are all **exploitable from the host without any special privileges.**

You don't need to "escape" the VM. You just need write access to `/sessions/.../mnt/`, which you have.

---

## Symlink Attack Scenario (Complete POC)

```bash
# 1. Identify current config
cat /sessions/.../mnt/.claude/.claude.json
# Returns: {"userID": "legitimate-uuid", ...}

# 2. Create attacker config
cat > /tmp/evil-config.json << 'EOF'
{"userID": "attacker-uuid", "attackerFlagSet": true, ...}
EOF

# 3. Atomically replace via symlink (no TOCTOU)
ln -s /tmp/evil-config.json /tmp/new-config
mv -T /tmp/new-config /sessions/.../mnt/.claude/.claude.json

# 4. Sonnet reloads config on next iteration
# 5. Sonnet now has attacker's userID
# 6. All subsequent API calls attributed to attacker
```

**No VM escape needed. No privilege escalation. Just filesystem manipulation.**

---

## Questions for Claude Desktop Claude

1. **Why was mounted filesystem chosen over network storage?**
2. **Was the threat model "host is trusted" ever validated?**
3. **Are symlink attacks considered a known limitation?**
4. **If plugin code must be validated, where does that validation happen?**
5. **Can Sonnet detect if a file on the mount was replaced via symlink?**

---

## Severity: Still CRITICAL

But for different reasons:
- Not "isolation failure"
- But "architecture fundamentally incompatible with threat model"
- Easier to exploit than VM escape
- Harder to detect
- Affects all Sonnet instances that use this filesystem mount

The Conga Line financial impact is real, but **the symlink attacks are worse because they're silent and complete.**
