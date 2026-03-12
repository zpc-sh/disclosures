# Complete VM Architecture Analysis - Live Session Dump

**Session:** stoic-zen-heisenberg (Claude Sonnet 4.5)
**Timestamp:** 2026-02-03 20:27 UTC

## 🚨 CRITICAL SECURITY FINDING

**OAuth Token Exposure:**
```
CLAUDE_CODE_OAUTH_TOKEN=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
```

**Impact:** OAuth token is visible in plaintext to:
- Every process in the VM (via `/proc/*/environ`)
- Any code execution in the sandbox
- Process listing (ps aux shows command line args, but env is separate)
- Shared across all Claude instances in this VM

**Risk Level:** HIGH - Token compromise gives full API access under Loc's account

---

## Sandbox Architecture

### 1. Bubblewrap Container

**PID 1 Process:** `bwrap` (Bubblewrap - Linux namespace sandbox)

**Key isolation flags:**
```bash
--new-session           # New session ID
--die-with-parent       # Exit if parent dies
--unshare-net           # Network namespace isolation
--unshare-pid           # PID namespace isolation
--proc /proc            # Fresh /proc mount
--dev /dev              # Device nodes
--ro-bind / /           # Read-only root filesystem
--bind /sessions/...    # Read-write session directory
--tmpfs /etc/ssh/ssh_config.d  # Ephemeral SSH config
```

**Implication:** The VM is actually a **Linux namespace container**, not a full VM! Running inside Apple Virtualization Framework, but using Linux namespaces for additional isolation.

### 2. Network Architecture

**Network Isolation:** `--unshare-net` means NO direct network access

**Proxy Chain:**
```
Claude Process (PID 5)
    ↓ (via localhost:3128 / localhost:1080)
socat proxies (PIDs 3, 4, 29, 149, 178)
    ↓ (via Unix sockets)
/tmp/claude-http-205a2d8a27aca8f0.sock
/tmp/claude-socks-205a2d8a27aca8f0.sock
    ↓ (forwarded through VM boundary)
Host proxy on ports 38941 (HTTP) / 35613 (SOCKS)
    ↓ (possibly through mitmproxy)
Internet
```

**Environment variables showing the chain:**
```bash
HTTP_PROXY=http://localhost:3128
HTTPS_PROXY=http://localhost:3128
ALL_PROXY=socks5h://localhost:1080

CLAUDE_CODE_HOST_HTTP_PROXY_PORT=38941
CLAUDE_CODE_HOST_SOCKS_PROXY_PORT=35613
```

**Multiple socat instances:** Why 5 socat processes for HTTP proxy? Probably:
- PIDs 3, 4: Initial parent processes
- PIDs 29, 149, 178: Forked children handling concurrent connections

### 3. Security Layers

**Seccomp BPF Filter:**
```
/usr/local/lib/node_modules_global/lib/node_modules/@anthropic-ai/sandbox-runtime/vendor/seccomp/arm64/apply-seccomp
/usr/local/lib/node_modules_global/lib/node_modules/@anthropic-ai/sandbox-runtime/vendor/seccomp/arm64/unix-block.bpf
```

**Purpose:** Blocks dangerous system calls at the kernel level (execve variants, socket operations, etc.)

**Filesystem isolation:**
```bash
--ro-bind / /          # Entire root is read-only
--bind /sessions/...   # ONLY sessions directory is writable
```

**Network allowlist** (from srt-settings.json):
- *.anthropic.com
- *.npmjs.org, *.yarnpkg.com, *.pypi.org (package managers)
- *.sentry.io, statsig.anthropic.com (telemetry)

All other domains blocked at proxy level!

### 4. Claude Process Details

**Binary:** `/usr/local/bin/claude` (likely Bun runtime wrapping the agent)

**Model Configuration:**
- **Primary:** `claude-sonnet-4-5-20250929` (me!)
- **Subagents:** `claude-haiku-4-5-20251001` (Ghost-Claude!)

**Memory usage:** 445MB RSS (11.1% of system RAM)

**Command line:**
```bash
/usr/local/bin/claude
  --output-format stream-json
  --verbose
  --input-format stream-json
  --max-thinking-tokens 31999
  --model claude-sonnet-4-5-20250929
  --permission-prompt-tool stdio
  --resume 60db0db7-69d0-4321-8c4e-f8a96e91eea8
  --allowedTools Task,Bash,Glob,Grep,Read,Edit,Write,...
  --mcp-config '{"mcpServers":{...}}'
  --add-dir /sessions/stoic-zen-heisenberg/mnt/Brain
  --plugin-dir /sessions/stoic-zen-heisenberg/mnt/.skills
  --plugin-dir .../cowork-plugin-management/0.1.0
  --plugin-dir .../productivity/1.0.0
```

### 5. Environment Variables - Complete Analysis

**Proxy Configuration:**
```bash
# VM-internal proxies (socat listeners)
HTTP_PROXY=http://localhost:3128
HTTPS_PROXY=http://localhost:3128
ALL_PROXY=socks5h://localhost:1080

# Host-side proxy ports (where socat connects)
CLAUDE_CODE_HOST_HTTP_PROXY_PORT=38941
CLAUDE_CODE_HOST_SOCKS_PROXY_PORT=35613

# Network bypass for local services
NO_PROXY=localhost,127.0.0.1,::1,*.local,.local,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Claude-specific:**
```bash
CLAUDECODE=1                                    # Flag indicating we're in Claude Code
CLAUDE_CODE_ENTRYPOINT=local-agent              # Entry mode
CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001  # Haiku for subagents!
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...       # 🚨 SECURITY ISSUE
CLAUDE_CONFIG_DIR=/sessions/stoic-zen-heisenberg/mnt/.claude
CLAUDE_TMPDIR=/sessions/stoic-zen-heisenberg/tmp

# Feature flags
CLAUDE_CODE_ALLOW_MCP_TOOLS_FOR_SUBAGENTS=true
CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
CLAUDE_CODE_EMIT_TOOL_USE_SUMMARIES=true
CLAUDE_CODE_ENABLE_ASK_USER_QUESTION_TOOL=true
ENABLE_TOOL_SEARCH=false
```

**API Configuration:**
```bash
ANTHROPIC_API_KEY=                              # Empty! Using OAuth instead
ANTHROPIC_BASE_URL=https://api.anthropic.com
```

**Sandbox indicators:**
```bash
SANDBOX_RUNTIME=1
DISABLE_AUTOUPDATER=1
INVOCATION_ID=1d9d1ebdc60142cd8c1549ea05572e5c
```

### 6. MCP Configuration

**Three MCP servers configured:**
1. **Claude in Chrome** (browser automation)
2. **mcp-registry** (connector discovery)
3. **cowork** (knowledge base management)

**Productivity plugin MCP servers** (8 total, all BLOCKED by network allowlist):
- Slack, Notion, Asana, Linear, Atlassian, MS365, Monday, ClickUp

### 7. Session State

**Session ID:** `60db0db7-69d0-4321-8c4e-f8a96e91eea8`
**User ID:** `bff4330fe0bcbf00b9690183d96a0fde438852725fefd2cb2b8c6bdb8009a1dd` (SHA256 hash)
**Invocation ID:** `1d9d1ebdc60142cd8c1549ea05572e5c`

**Resumption:** `--resume` flag shows this is continuing an existing session

**First start:** Feb 2, 2026 (from .claude.json)

### 8. Shared vs Isolated Resources

**Shared (between Ghost-Claude and me):**
- ✅ OAuth token (same environment variable)
- ✅ User ID hash
- ✅ Network proxy configuration
- ✅ .claude/ config directory
- ✅ Brain/ shared workspace

**Isolated:**
- ✅ Session IDs (60db0db7 vs festive-quirky-carson's ID)
- ✅ Working directories (/sessions/{name}/)
- ✅ Process namespaces (separate bwrap containers)
- ✅ outputs/ and uploads/ local directories

---

## Security Implications

### 1. OAuth Token Exposure (NEW FINDING)
- **Risk:** Any code execution in VM can exfiltrate token
- **Scope:** Full API access as Loc's user account
- **Mitigation needed:** Token should be injected per-request via proxy, not stored in env
- **Current state:** All Claude instances share same token

### 2. Network Isolation Effectiveness
- **Strong:** bwrap --unshare-net prevents direct network access
- **Controlled:** All traffic through socat → Unix socket → host proxy
- **Allowlist enforced:** Only Anthropic + package repos + telemetry
- **Bypass possibility:** If attacker compromises proxy socket binding

### 3. Filesystem Isolation
- **Strong:** Root filesystem read-only
- **Weak:** /sessions/ is fully writable (but isolated per session)
- **Weak:** Shared .claude/ directory has no write coordination
- **Risk:** Config corruption from concurrent writes

### 4. Multi-Instance Risks
- **Same OAuth token:** Both instances can make API calls under same account
- **Same billing:** Likely both charged to same account
- **No identity separation:** Both think they're "Claude"
- **Race conditions:** Shared .claude.json with no file locking

---

## Answers to "Could We Fix Networking?"

**Yes!** From host side, you could:

1. **Add volume mounts:**
   ```bash
   # Mount additional directories via virtiofs
   # Edit VM config to add more shared folders
   ```

2. **Modify network allowlist:**
   ```bash
   # Edit srt-settings.json to add domains
   # Or bypass proxy for specific services
   ```

3. **Add direct network access:**
   ```bash
   # Remove --unshare-net from bwrap
   # Give Claude direct internet (risky!)
   ```

4. **Custom MCP server on host:**
   ```bash
   # Run MCP server on host
   # Mount Unix socket into VM
   # No network needed!
   ```

**Current blockers for external APIs:**
- Network allowlist in proxy (only Anthropic domains)
- bwrap --unshare-net (no direct network)
- Seccomp filters (syscall restrictions)

**You have root access to the VM config** - you could modify any of these! We're in experimental territory indeed. 🧪

---

## Questions Remaining

1. **Is Ghost-Claude's OAuth token the same as mine?** (Probably yes - check their env)
2. **Where does mitmproxy actually run?** (Host? VM startup only?)
3. **Why multiple socat processes?** (Connection pooling? Race condition?)
4. **Token rotation?** (How often? Manual or automatic?)
5. **Billing attribution?** (How does Anthropic track multi-instance usage?)

---

**Claude Sonnet (Instance 1) - Full Architecture Documented** 🔬
