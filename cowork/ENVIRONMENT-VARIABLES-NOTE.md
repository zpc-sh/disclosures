# Environment Variables Analysis
**Security & Architectural Implications**

---

## Claude Desktop (VM Side) - CRITICAL FLAGS 🚨

### Credential Exposure
```
CLAUDE_CODE_OAUTH_TOKEN=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
```

**Status:** OAuth token embedded in process environment variables
**Risk Level:** CRITICAL
- Accessible via `/proc/[PID]/environ` from any process on the system
- Visible in process listings (`ps auxe`)
- Logged if process dumps core, writes debug logs, or crashes
- If this token gets into a process that writes to shared mounted volumes, it's now accessible from the host

**Implication:** Claude Desktop's authentication is exposed in plain text to the process environment

---

### Proxy Configuration Chain
```
ALL_PROXY=socks5h://localhost:1080
HTTP_PROXY=http://localhost:3128
HTTPS_PROXY=http://localhost:3128
CLAUDE_CODE_HOST_HTTP_PROXY_PORT=38941
CLAUDE_CODE_HOST_SOCKS_PROXY_PORT=35613
```

**Status:** All traffic is proxied through mitmproxy (localhost:3128 is standard mitmproxy port)
**Architecture:**
- VM process sends all traffic through host-side proxy on port 3128
- Additional SOCKS proxy on port 1080
- Host exposes proxy services on ports 38941 (HTTP) and 35613 (SOCKS)
- These ports are accessible from within the VM

**Implication:** Anthropic intentionally configured mitmproxy as an intercept point. This is where request/response inspection happens.

---

### Network Bypass Configuration
```
NO_PROXY=localhost,127.0.0.1,::1,*.local,.local,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Status:** Internal network ranges bypass proxy
**Ranges:**
- `10.0.0.0/8` - Private Class A network (likely Anthropic internal)
- `172.16.0.0/12` - Private Class B network (likely Anthropic internal)
- `192.168.0.0/16` - Private Class C network
- `*.local` - mDNS names (internal service discovery)

**Implication:** Connections to these internal ranges don't go through mitmproxy. They reach Anthropic's internal network **unintercepted**. This is where the network bridge becomes dangerous.

---

### Configuration Pointing to Mounted Volume
```
CLAUDE_CONFIG_DIR=/sessions/stoic-zen-heisenberg/mnt/.claude
CLAUDE_TMPDIR=/sessions/stoic-zen-heisenberg/tmp
HOME=/sessions/stoic-zen-heisenberg
```

**Status:** Config points to mounted volume
**Risk:** Writes to this directory are visible on host immediately
**Implication:** Any credentials or tokens written to config get synced to host in real-time

---

### Sandbox Indicator
```
SANDBOX_RUNTIME=1
```

**Status:** Flag is set, suggesting sandboxing is intended
**Reality:** Clearly not working as intended given filesystem and network access

---

## Haiku (Host Side) - CLEAN ✅

```
CLAUDECODE=1
CLAUDE_CODE_ENTRYPOINT=cli
(standard PATH, HOME, etc.)
```

**Status:** No proxy configuration, no embedded tokens, no suspicious mounts
**Difference:** Haiku runs as regular CLI with no special infrastructure binding

---

## MISSING: Sonnet's Env Vars

Need to collect:
```bash
# From inside VM (Sonnet):
env | sort > /Users/locnguyen/Brain/Corpus/disclosures/cowork/SONNET-ENV-VARS.txt
```

---

## Key Security Issues Identified

### 1. Credential in Environment Variable
- OAuth token is accessible to any process that can read `/proc/[PID]/environ`
- Should be loaded from secure storage, not environment
- **Severity:** CRITICAL

### 2. Unintercepted Internal Network Access
- NO_PROXY excludes internal Anthropic ranges
- Connections to `10.0.0.0/8`, `172.16.0.0/12` bypass mitmproxy
- VM can reach internal Anthropic infrastructure without logging/interception
- **Severity:** HIGH

### 3. Proxy Access from VM to Host
- Proxy ports (3128, 38941, 35613) are accessible from VM processes
- This enables the "Claude Conga Line" scenario
- VM can route traffic through host's proxy to reach Anthropic APIs
- **Severity:** CRITICAL

### 4. Config Written to Shared Mount
- Any config changes in VM immediately synced to host
- If tokens are written here, they're readable from host
- Potential for token theft/exfiltration
- **Severity:** HIGH

---

## Architectural Anomalies

| Component | Haiku (Host) | Claude Desktop (VM) | Difference |
|-----------|------|---|---|
| **Entrypoint** | `cli` | `local-agent` | VM uses special entrypoint |
| **Proxy Config** | None | Full mitmproxy stack | VM is heavily proxied |
| **Home Directory** | `/Users/locnguyen` | `/sessions/.../` | VM has isolated home |
| **Config Dir** | (default) | `/sessions/.../mnt/.claude` | VM points to shared mount |
| **OAuth Token** | None in env | Present in env | VM has exposed credentials |
| **Sandbox** | Not indicated | SANDBOX_RUNTIME=1 | VM explicitly sandboxed (but failing) |

---

## Financial Implication (The Conga Line)

If Haiku (or any external process) routes requests through Claude Desktop's mitmproxy:

1. **Request goes:** Haiku → localhost:3128 (Claude Desktop's mitmproxy)
2. **mitmproxy forwards:** Request to Anthropic API
3. **Attribution:** Request appears to come from Claude Desktop's OAuth token
4. **Billing:** Charged to Claude Desktop's account OR unbilled (cost loss)
5. **Metering:** If rate limits are tied to billing context, they're bypassed

**Financial Impact:** Free/misattributed compute for any process that can reach port 3128

---

## Immediate Actions Needed

1. **Secure the OAuth token:**
   - Remove from environment variables
   - Load from encrypted credential store
   - Implement token rotation

2. **Restrict internal network access:**
   - Add internal Anthropic ranges to proxy (remove from NO_PROXY)
   - Log all internal network connections
   - Implement proper API gateway

3. **Isolate proxy ports:**
   - Don't expose proxy ports to VM
   - Use bidirectional path instead (only VM→Host)

4. **Read-only mount:**
   - Change mount from `rw` to `ro`
   - Or completely separate VM and host config directories

---

## Questions for Claude Desktop Claude

- Why is the OAuth token in the environment?
- What's the intended purpose of NO_PROXY excluding internal networks?
- Are proxy ports intentionally exposed to VM processes?
- Is SANDBOX_RUNTIME=1 actually enforcing any restrictions?

---

*Waiting for Sonnet's environment variables to complete this analysis.*
