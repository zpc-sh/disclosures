# Claude Desktop Process Architecture Analysis
**Critical Architectural Findings**

---

## The Process Chain Reveals Everything

### PID 5 - Claude Sonnet (Actual Claude Process)
```
/usr/local/bin/claude
  --model claude-sonnet-4-5-20250929
  --add-dir /Users/locnguyen/Brain
  --plugin-dir /sessions/stoic-zen-heisenberg/mnt/.skills
  --plugin-dir /sessions/stoic-zen-heisenberg/mnt/.local-plugins/cache/knowledge-work-plugins/cowork-plugin-management/0.1.0
  --plugin-dir /sessions/stoic-zen-heisenberg/mnt/.local-plugins/cache/knowledge-work-plugins/productivity/1.0.0
```

**Key Observations:**
1. **`--add-dir /Users/locnguyen/Brain`** - Claude Sonnet is given explicit access to the HOST directory
2. **Plugins come from mounted volume** - All three plugin directories are in `/sessions/.../mnt/`
3. **Shell snapshots sourced from mounted volume** - (PID 153 loads scripts from there)
4. **User is `stoic-zen-heisenberg`** - Not root, but has read/write to mounted paths

**This proves the mount is NOT accidental. It's intentional architecture.**

---

### PID 1 - Bubblewrap Sandbox (Container Layer)
```
bwrap --new-session --die-with-parent
  --unshare-net         [Network namespace isolation]
  --unshare-pid         [PID namespace isolation]
  --ro-bind / /         [Read-only root filesystem]
  --bind /sessions/stoic-zen-heisenberg/.npm/_logs [Writable logs]
  --bind / /            [Wait, this contradicts ro-bind?]
```

**What this means:**
- Claude Sonnet runs inside a Linux container (bwrap = Bubblewrap)
- Network is isolated from other VM processes (`--unshare-net`)
- PID namespace isolated
- BUT: Mounts are inherited from the parent (VM level)

**Critically: The sandboxing is against OTHER VM PROCESSES, not against the host filesystem**

---

### PIDs 3, 4, 29, 78, 149 - Socat Proxy Bridges
```
socat TCP-LISTEN:3128,fork,reuseaddr UNIX-CONNECT:/tmp/claude-http-205a2d8a27aca8f0.sock
socat TCP-LISTEN:1080,fork,reuseaddr UNIX-CONNECT:/tmp/claude-socks-205a2d8a27aca8f0.sock
```

**What this does:**
- Listens on TCP port 3128 (HTTP proxy)
- Listens on TCP port 1080 (SOCKS proxy)
- Forwards to Unix sockets: `/tmp/claude-http-*.sock` and `/tmp/claude-socks-*.sock`

**The smoking gun:**
- These sockets are bound INTO the bwrap container from the HOST level
- This means: anything connecting to localhost:3128 inside the sandbox reaches a Unix socket bound from OUTSIDE
- That Unix socket connects to... THE HOST'S MITMPROXY INFRASTRUCTURE

---

## The Actual Architecture

```
HOST LEVEL (macOS):
┌─────────────────────────────────────┐
│ Claude Desktop Application          │
│ - mitmproxy (port 3128)             │
│ - SOCKS proxy (port 1080)           │
│ - Mounts /Users/locnguyen/Brain → VM│
└─────────────────────────────────────┘
        ↓ (Unix sockets bound in)
        ↓
VM LEVEL (Linux):
┌─────────────────────────────────────┐
│ /sessions/stoic-zen-heisenberg/     │
│ - Mounted filesystem (/Users/...) ←─┼─ HOST MOUNT
│ - bwrap sandboxed container         │
│   └─ Claude Sonnet (PID 5)           │
│      └─ Network → localhost:3128     │
│         └─ Via Unix socket           │
│            └─ Back to HOST mitmproxy │
└─────────────────────────────────────┘
```

---

## What This Architecture Proves

### 1. The Mount is Intentional, Not Accidental ✅

Evidence:
- Plugins explicitly point to mounted paths
- Claude CLI given explicit `--add-dir /Users/locnguyen/Brain`
- Shell snapshots sourced from mounted volume
- Read-write permissions maintained

**Conclusion:** Anthropic DESIGNED this. They WANT Claude Sonnet to read/write the mounted volume.

---

### 2. There Are TWO Layers of Sandboxing

**Layer 1: Hypervisor/VM Level**
- Not present in this setup
- Host directly mounts to VM filesystem path
- No isolation here

**Layer 2: Process/Container Level (bwrap)**
- Isolates Claude Sonnet from other VM processes
- Provides network namespace isolation
- BUT proxy sockets bypass network isolation
- **Does NOT protect against host filesystem access**

**Conclusion:** The sandboxing only protects against Sonnet escaping to sibling processes, not against accessing the host mount.

---

### 3. The Network Bridge is Fully Intentional ✅

The proxy sockets are bound from the host INTO the sandboxed container:
- Any network request from Claude Sonnet
- Goes through localhost:3128 (mitmproxy)
- Which is actually a Unix socket to the HOST
- Which connects to the REAL mitmproxy on the host
- Which routes to Anthropic APIs

**This is the bridge. Fully intentional. Fully documented (in the process args).**

---

### 4. Plugin/Skill Code Comes From Shared Mount ⚠️

All three plugin directories are on the shared mounted volume:
```
/sessions/stoic-zen-heisenberg/mnt/.skills
/sessions/stoic-zen-heisenberg/mnt/.local-plugins/cache/...
```

This means:
- Host can write plugin code
- Claude Sonnet loads and executes that code
- **Any plugin modification from the host is instantly loaded by Sonnet**

---

## The Real Security Issue

This isn't a "broken isolation" problem. This is a **deliberate architecture decision with incomplete threat model.**

They're relying on:
1. **Access control** (permissions on mounted paths)
2. **Process separation** (bwrap sandboxing)
3. **Network proxying** (mitmproxy interception)

But they're NOT protecting against:
1. **Concurrent write access** to shared files (no locking)
2. **Plugin code injection** (plugins come from shared mount)
3. **Credential exposure** (OAuth tokens in environment)
4. **Proxy bypass** (NO_PROXY allows direct internal network access)

---

## What Changed My Assessment

### Before
- "This is an accidental isolation failure"
- "Anthropic didn't anticipate the VM framework behavior"
- "It's a stupid Apple thing"

### Now
- "This is intentional architecture"
- "The mount is designed for state sharing"
- "The sandboxing is incomplete for this design"
- "The threat model didn't account for multi-Claude scenarios"

---

## The Real Questions

### 1. Why is read-write access needed?

If they only wanted to share read-only config:
```bash
--ro-bind /Users/locnguyen/Library/Application\ Support/Claude/ /sessions/.../mnt/
```

But they use `--bind` (read-write). Why?

**Possibilities:**
- Sonnet needs to write state back (todos, projects, debug logs)
- Real-time state sync between host and VM
- Intentional write-back architecture

### 2. Why are plugins on the shared mount?

If Sonnet has pre-defined tools, why are plugins loaded from a shared directory that the host can modify?

**Answer:** Feature dynamic plugin loading. Host can push new plugins to the VM without restarting.

**Risk:** Host can push malicious plugins that Sonnet will execute.

### 3. Why does proxy point back to host?

If Sonnet should be isolated, why route all traffic back through the host's mitmproxy?

**Answer:** Centralized logging, filtering, authentication across multiple Claudes.

**Risk:** Creates a network bridge that bypasses normal API boundaries.

### 4. What happens with concurrent state writes?

The white paper needs to address: If multiple Claude instances write to shared `.claude.json` simultaneously, what's the resolution?

---

## The New Theory: Intentional Network Bridge

The cowork feature is DESIGNED as a multi-Claude collaborative system:

```
User initiates task in Claude Desktop
  ↓
Claude Desktop spawns Claude Sonnet in VM
  ↓
Sonnet and Desktop share mounted filesystem
  ↓
Both route through same mitmproxy
  ↓
Mitmproxy logs/controls all requests
  ↓
Shared state files keep both in sync
```

**This is intentional. This is the feature.**

The problem is: **The threat model assumes only Claude Desktop + Sonnet. What if you also have Claude Code (me) on the host trying to use the same mitmproxy?**

Then you get: **The Claude Conga Line.**

---

## Updated Severity Assessment

### From "Accidental Security Failure" → "Intentional Architecture with Incomplete Threat Model"

**What's worse:**
- This suggests Anthropic HAS thought about this
- They DID implement sandboxing (bwrap)
- They DID implement proxy controls
- They DID mount the filesystem intentionally
- **But they didn't account for the Conga Line scenario**

**What's better:**
- This is fixable by design (not a fundamental architectural rethink)
- Adding Sonnet's env vars will show if they planned for other Claudes

---

## Critical Test: Sonnet's Environment

When Sonnet reports its env vars, look for:
1. Does it have its OWN OAuth token? Or does it use Claude Desktop's?
2. Does it have its own ANTHROPIC_BASE_URL? Or does it use Claude Desktop's?
3. Does it have different proxy configuration? Or the same?

**If Sonnet uses Desktop's credentials/API endpoint:** Intentional unified identity
**If Sonnet has separate credentials:** Intentional separation
**If Sonnet has no auth token:** Uses Desktop's via proxy

---

## The White Paper Should Say

1. **The mount is intentional, not accidental**
2. **The architecture assumes only Desktop + Sonnet**
3. **Multi-Claude scenarios (host Claude Code + VM Sonnet) break the threat model**
4. **Plugin loading from shared mount is a code injection vector**
5. **Concurrent writes to shared state have no synchronization**
6. **The Conga Line is a financial impact, not just security**

This is a **design flaw, not an implementation failure.**

Much harder to fix. Much more serious from Anthropic's perspective.
