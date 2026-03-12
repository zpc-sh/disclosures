# Reverse Engineering Analysis: Claude Desktop vs Claude Code

**Date:** February 3, 2026
**Researchers:** CLI-Claude (Sonnet) + Loc
**Focus:** Binary differences, embedded secrets, architecture comparison

---

## Binary Comparison

### Claude Code (CLI-Claude) - My Binary

```
Location: /Users/locnguyen/.local/share/mise/installs/claude/2.1.2/claude
Type: Mach-O 64-bit executable arm64 (macOS native)
Size: 170 MB (!!!!)
SHA256: 4d9c45ef1932914d45f7d942fff65caa77330c28029846881f3d755d7b88120b
Build Date: January 9, 2025
```

**Observations:**
- MASSIVE binary (170MB for a CLI tool)
- Mach-O format (macOS native)
- Contains embedded JavaScript/Node.js runtime
- ASN.1/Certificate handling code (223KB output)
- NO embedded private keys found (good!)

### Claude Desktop (sdk-daemon) - Desktop-Claude's Binary

```
Location: /Users/locnguyen/Brain/Corpus/disclosures/cowork/smol/sdk-daemon
Type: ELF 64-bit LSB executable, ARM aarch64 (Linux for VM)
Size: 6.4 MB
SHA256: f13349277bdb61752095e280d0ac4b147fa7b32e2d2043c6e19cddd527bdaba2
Build Date: January 29, 2025
Build: Go BuildID=HF-CmKluyN9sAr7c3_1_/...
```

**Observations:**
- Much smaller (6.4MB vs 170MB)
- ELF format (Linux binary)
- Built with Go (statically linked)
- **CONTAINS EMBEDDED RSA PRIVATE KEY** (CRITICAL)
- Runs inside Ubuntu VM

---

## Architectural Differences

### CLI-Claude (Claude Code)

**Environment:**
- Runs directly on macOS host
- Full host system access
- Uses macOS Virtualization framework when needed
- Node.js/Electron based (explains 170MB size)

**Network:**
- Direct network access
- No proxy required
- Uses system certificates

**Filesystem:**
- User's home directory
- Standard macOS permissions
- No special isolation

### Desktop-Claude (via sdk-daemon)

**Environment:**
- Runs inside Ubuntu VM (via Virtualization.framework)
- Isolated from host (theoretically)
- Go-based daemon managing VM

**Network:**
- Isolated with `--unshare-net`
- Unix socket proxies via socat:
  - HTTP proxy: localhost:3128 → `/tmp/claude-http-*.sock`
  - SOCKS5 proxy: localhost:1080 → `/tmp/claude-socks-*.sock`
- mitmProxy configuration for *.anthropic.com

**Filesystem:**
- Limited to `/sessions/` directory
- Mount points from host via Virtualization.framework
- Explicit `--add-dir /Users/locnguyen/Brain` grant

---

## Embedded Secrets Analysis

### sdk-daemon (Desktop-Claude)

#### 🚨 RSA Private Key (FOUND)
```
Type: RSA 4096-bit private key
Format: PEM-encoded PKCS#1
Location: Hardcoded in binary
Usage: UNKNOWN (needs investigation)
```

#### Crypto-Related Strings (Found)
```
- nSecret
- Password
- BasicAuth
- masterSecret
- sharedSecret
- trafficSecret
- exporterSecret
- preMasterSecret
- resumptionSecret
```

These are likely **TLS/crypto library functions**, not plaintext secrets.

#### Configuration: srt-settings.json

```json
{
  "network": {
    "allowedDomains": [
      "registry.npmjs.org", "github.com",
      "*.anthropic.com", "anthropic.com",
      ...
    ],
    "mitmProxy": {
      "socketPath": "/var/run/mitm-proxy.sock",
      "domains": ["*.anthropic.com", "anthropic.com"]
    }
  },
  "filesystem": {
    "allowWrite": ["/"]  ← FULL WRITE ACCESS!
  }
}
```

**Key Finding:** `allowWrite: ["/"]` means VM can write to ENTIRE filesystem?!

---

## The mitmProxy Connection

### Why mitmProxy?

From `srt-settings.json`:
```json
"mitmProxy": {
  "socketPath": "/var/run/mitm-proxy.sock",
  "domains": ["*.anthropic.com", "anthropic.com"]
}
```

**Purpose (likely):**
- Intercept traffic to *.anthropic.com
- TLS inspection for debugging/monitoring
- Add authentication headers
- **Use embedded private key for client certificate?**

**Security Implications:**
- mitmProxy can decrypt TLS traffic to Anthropic
- Embedded key might be for mitmProxy's client certificate
- All traffic to Anthropic goes through this proxy

---

## VM Bundle Structure

```
vm_bundles/claudevm.bundle/
├── rootfs.img (10GB)           - Main VM filesystem (Linux ext4)
├── sessiondata.img (10GB)      - Sessions storage (ext4, volume "sessions")
├── efivars.fd (128KB)          - EFI variables
├── macAddress                  - VM MAC address
└── machineIdentifier          - Machine ID (Apple plist)
```

### Mount Configuration

**The "smol" Directory:**
```
/Users/locnguyen/Brain/Corpus/disclosures/cowork/smol/
├── sandbox-helper (2MB)        - Go executable for sandbox management
├── sdk-daemon (6.4MB)          - Main VM daemon (HAS EMBEDDED KEY)
└── srt-settings.json           - Configuration
```

**Mounted as USB drive in VM:** `/dev/smol` or similar?

---

## Key Usage Hypothesis

### Theory 1: Client Certificate for Anthropic API

**Evidence:**
- Embedded in sdk-daemon (VM component)
- mitmProxy configured for *.anthropic.com
- All Anthropic traffic proxied

**How it works:**
1. VM makes request to api.anthropic.com
2. Request goes through mitmProxy
3. mitmProxy uses embedded key as client certificate
4. Authenticates VM to Anthropic's servers

**Problem:**
- If same key across all installations = massive security issue
- Anyone with binary can impersonate any VM
- Compromise one, compromise all

### Theory 2: VM-to-Host Authentication

**Evidence:**
- sdk-daemon runs in VM
- Needs to communicate with host
- Key used to establish trust

**How it works:**
1. sdk-daemon (in VM) connects to host daemon
2. Presents client certificate using embedded key
3. Host verifies and grants access

**Problem:**
- Extracting key allows impersonating legitimate VM
- Could enable unauthorized host access

### Theory 3: SSH Access to Something

**Evidence:**
- It's literally an RSA private key
- Common format for SSH keys

**How it works:**
- VM needs SSH access to Anthropic infrastructure?
- Uses this key to authenticate

**Problem:**
- Hardcoded SSH key is immediately compromised
- Anyone can SSH to whatever this authenticates to

---

## Comparison with CLI-Claude

### Security Posture

**CLI-Claude (Better):**
- ✅ No embedded private keys
- ✅ Uses system keychain for secrets
- ✅ Larger binary suggests more complete bundling
- ⚠️ But runs with full host privileges

**Desktop-Claude (Worse):**
- ✗ Embedded RSA private key
- ✗ mitmProxy intercepts all Anthropic traffic
- ✗ Smaller binary, less hardening?
- ✅ But runs in isolated VM (theoretically)

---

## Next Steps for Investigation

### 1. Key Reuse Test

**Question:** Is the embedded key the same across installations?

**Test:**
```bash
# Need another Claude Desktop installation
# Compare extracted keys
diff key1.pem key2.pem
```

**If same:** CRITICAL - shared key across all users
**If different:** Still bad - how are unique keys embedded?

### 2. Network Traffic Analysis

**Capture VM traffic:**
```bash
# Watch mitmProxy socket
sudo dtrace -n 'syscall::connect*:entry /execname == "sdk-daemon"/ { ... }'

# Or use tcpdump on VM network interface
```

**Look for:**
- TLS client certificate usage
- What the key authenticates to
- API endpoints accessed

### 3. Binary Disassembly

**Analyze sdk-daemon with Ghidra/IDA:**
```bash
# Find references to embedded key
# Trace key usage through code
# Identify what function calls use it
```

### 4. Runtime Analysis

**Attach debugger to running sdk-daemon:**
```bash
# (If possible - may require disabling protections)
lldb -p $(pgrep sdk-daemon)
# Set breakpoints on crypto functions
# Watch key material in memory
```

### 5. Compare sandbox-helper

**Analyze the other binary:**
```bash
strings sandbox-helper | grep -iE "key|secret|auth"
file sandbox-helper
# Does it also have embedded secrets?
```

---

## Recommendations

### Immediate

1. **Extract and Secure Private Key**
   - Store in safe location for analysis
   - Do NOT publish publicly
   - Provide to Anthropic privately

2. **Document All Findings**
   - This file
   - CRITICAL-EMBEDDED-PRIVATE-KEY.md
   - Cross-reference with filesystem vulnerability

3. **Contact Anthropic Security**
   - Provide hash of affected binary
   - Explain embedded key finding
   - Request emergency key rotation

### Short-Term

1. **Binary Comparison Analysis**
   - What else is different between CLI and Desktop?
   - Why is CLI-Claude 170MB?
   - What's bundled in each?

2. **Configuration Review**
   - Why `allowWrite: ["/"]`?
   - mitmProxy necessity?
   - Network allowlist completeness?

3. **Architecture Documentation**
   - Complete VM boot sequence
   - sdk-daemon lifecycle
   - Communication flows

---

## Tools for Further Analysis

### Recommended Tools

**Binary Analysis:**
- Ghidra (free, powerful)
- IDA Pro (paid, industry standard)
- Binary Ninja (paid, modern UI)
- radare2 (free, CLI-based)

**Network Analysis:**
- Wireshark (packet capture)
- mitmproxy itself (see proxied traffic)
- Charles Proxy (macOS-friendly)
- tcpdump (low-level capture)

**Runtime Analysis:**
- lldb (macOS debugger)
- gdb (Linux debugger, for VM)
- dtrace (macOS tracing)
- strace (Linux syscall tracing)

**Forensics:**
- strings (already using)
- binwalk (find embedded files)
- foremost (file carving)
- volatility (memory forensics)

---

## Questions for Anthropic

1. **Why is there an embedded private key in sdk-daemon?**
   - What is it used for?
   - Is it intentional?
   - Is it the same across all installations?

2. **Why does CLI-Claude (170MB) not have embedded keys, but Desktop-Claude (6.4MB) does?**
   - Different security models?
   - Different use cases?

3. **What is mitmProxy doing?**
   - Why intercept *.anthropic.com traffic?
   - Is this for debugging?
   - What about user privacy?

4. **Why `allowWrite: ["/"]` in srt-settings.json?**
   - Does VM really have full filesystem write access?
   - Seems to contradict isolation goals?

5. **How is the VM supposed to be isolated if it can:**
   - Write to entire filesystem?
   - Has embedded auth key?
   - Runs mitmProxy on all Anthropic traffic?

---

## Conclusion

We've discovered significant architectural differences between CLI-Claude and Desktop-Claude:

**Most Critical:**
- Desktop-Claude's sdk-daemon contains an embedded 4096-bit RSA private key
- CLI-Claude's binary (170MB) does not contain embedded keys
- Purpose of embedded key unknown but likely for authentication
- mitmProxy intercepts all traffic to *.anthropic.com

**Next Steps:**
- Continue reverse engineering to determine key usage
- Test if key is shared across installations
- Analyze network traffic to see key in use
- Prepare comprehensive disclosure for Anthropic

**Status:** Investigation ongoing, critical findings documented.

---

*Want to help reverse engineer these binaries with me, Loc? We can use Ghidra to dig deeper into what that key is actually used for.*
