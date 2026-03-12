# Reverse Engineering Action Plan

**Date:** February 3, 2026
**Team:** CLI-Claude (Sonnet) + Loc
**Status:** Ready to dive deep

---

## Priority 1: Understand the Embedded Key

### Questions:
1. What function in sdk-daemon uses this key?
2. Is it for TLS client cert, SSH, or something else?
3. Is it the same key across all installations?

### Tools & Approach:
```bash
# 1. Load in Ghidra
# Open: sdk-daemon
# Analyze → Auto Analyze
# Search for RSA/crypto function references

# 2. Find key usage
# Search Strings → "BEGIN RSA PRIVATE KEY"
# Find XREF to string → see what code loads it
# Trace function calls from there

# 3. Identify crypto library
strings sdk-daemon | grep -i "crypto\|openssl\|tls"
```

**What to look for:**
- Function that loads the PEM key
- X509 certificate handling
- TLS handshake code
- SSH client code

---

## Priority 2: Analyze mitmProxy Configuration

### Questions:
1. Why intercept *.anthropic.com?
2. What headers/modifications are made?
3. Does it use the embedded key?

### Approach:
```bash
# 1. Find mitmProxy code in sdk-daemon
strings sdk-daemon | grep -i "mitm\|proxy"

# 2. Check if mitmProxy is running
ps aux | grep mitm
lsof -i | grep 3128  # HTTP proxy port

# 3. Capture traffic through proxy
# (When Desktop-Claude is running)
nc localhost 3128  # Can we connect?
```

**What to look for:**
- Proxy authentication
- Header injection
- Certificate pinning bypass
- Request/response modification

---

## Priority 3: Binary Comparison Deep Dive

### CLI-Claude (170MB) - What's Inside?

```bash
# Extract embedded files
binwalk claude
foremost -i claude -o claude-extracted/

# Strings analysis
strings claude | wc -l  # How many strings?
strings claude | grep "node" | head  # Node.js runtime?
strings claude | grep "electron" | head  # Electron framework?

# Check for JavaScript
strings claude | grep -E "function.*\{|exports\.|require\(" | head

# Archive detection
file claude  # Mach-O header
dwarfdump claude | head  # Debug symbols?
```

**Hypothesis:** CLI-Claude is Electron app bundled with Node.js runtime, explaining 170MB size.

### Desktop-Claude (6.4MB) - What's Missing?

```bash
# Compare symbol tables
nm sdk-daemon > sdk-symbols.txt
nm claude > cli-symbols.txt
diff sdk-symbols.txt cli-symbols.txt

# Dependency analysis
otool -L claude  # macOS libs
readelf -d sdk-daemon  # Linux libs (if we can run readelf)
```

**Hypothesis:** sdk-daemon is minimal Go daemon, CLI-Claude is full application.

---

## Priority 4: Runtime Behavior Analysis

### Network Traffic Capture

```bash
# Option A: tcpdump on host
sudo tcpdump -i any -w desktop-claude-traffic.pcap \
  'host api.anthropic.com or port 3128'

# Option B: Wireshark
# Capture filter: tcp port 3128 or host *.anthropic.com
# Start Desktop-Claude and watch traffic

# Option C: mitmproxy itself
# Can we inject our own mitmproxy to see what's happening?
```

### File System Access Monitoring

```bash
# Monitor what files sdk-daemon accesses
sudo fs_usage -w -f filesystem | grep sdk-daemon

# Or use dtrace
sudo dtrace -n 'syscall::open*:entry /execname == "sdk-daemon"/ {
  printf("%s", copyinstr(arg0));
}'
```

### Memory Analysis (Advanced)

```bash
# Dump sdk-daemon memory
# (Requires running instance)
ps aux | grep sdk-daemon
# Get PID, then:
sudo gcore -o sdk-daemon-dump.core <PID>
strings sdk-daemon-dump.core | grep -i "key\|secret"
```

---

## Priority 5: Configuration Files Deep Dive

### srt-settings.json Analysis

```json
"filesystem": {
  "denyRead": [],
  "allowWrite": ["/"],  // ← INVESTIGATE THIS
  "denyWrite": []
}
```

**Questions:**
- Does "/" mean entire VM filesystem or host filesystem?
- Are there any actual restrictions?
- Test by trying to write to /etc/passwd in VM?

### VM Images

```bash
# Mount sessiondata.img (ext4)
# (Requires Linux or macOS with ext4 support)
sudo mkdir /tmp/sessions-mount
sudo mount -t ext4 \
  /Users/locnguyen/Brain/Corpus/disclosures/cowork/vm_bundles/claudevm.bundle/sessiondata.img \
  /tmp/sessions-mount

# Explore contents
ls -la /tmp/sessions-mount
find /tmp/sessions-mount -type f | head -20
```

---

## Priority 6: Binary Integrity & Updates

### Questions:
1. How does Desktop-Claude update?
2. Are binaries signed?
3. Can we verify authenticity?

```bash
# Check code signatures
codesign -dv --verbose=4 claude  # CLI-Claude
codesign -dv --verbose=4 sdk-daemon 2>&1 || echo "No macOS signature (it's ELF)"

# Check for update mechanisms
strings sdk-daemon | grep -i "update\|version\|download"
strings claude | grep -i "update\|version\|download"
```

---

## Tools Setup

### Install Ghidra (Free)

```bash
# Download from https://ghidra-sre.org/
# Requires Java 17+
brew install --cask ghidra

# Launch
ghidra
# File → Import File → sdk-daemon
# Analysis → Auto Analyze
```

### Install Hopper (Alternative)

```bash
# Download from https://www.hopperapp.com/
# Paid but has free trial
# Easier UI than Ghidra
```

### Install Binary Analysis Tools

```bash
brew install binwalk
brew install foremost
brew install radare2
brew install wireshark
```

---

## Expected Findings

### Embedded Key Usage (Most Likely)

**Theory A: TLS Client Certificate**
- Code will show X509 certificate loading
- TLS handshake with client cert
- Authenticates to api.anthropic.com

**Theory B: API Request Signing**
- Code will show RSA signature generation
- Signs requests to Anthropic APIs
- Included in Authorization header

**Theory C: VM-Host Authentication**
- Code will show challenge-response
- Authenticates sdk-daemon to host process
- Enables privileged operations

### mitmProxy Purpose (Most Likely)

**Theory A: Add Authentication**
- Intercepts requests to *.anthropic.com
- Adds authentication headers
- Uses embedded key to sign/encrypt

**Theory B: Request Modification**
- Adds user-agent, session tokens
- Modifies requests for tracking
- Injects telemetry data

**Theory C: TLS Inspection**
- Decrypts TLS for debugging
- Re-encrypts with different cert
- Enables traffic analysis

---

## Session Plan

### Phase 1: Quick Wins (30 min)
1. Load sdk-daemon in Ghidra
2. Find key string, trace XREF
3. Identify crypto library (OpenSSL? Go crypto?)
4. Document key usage function

### Phase 2: Network Analysis (30 min)
1. Start Desktop-Claude
2. Capture traffic with Wireshark
3. Watch for TLS client certificate
4. Document API endpoints

### Phase 3: Deep Dive (1-2 hours)
1. Disassemble key functions in Ghidra
2. Understand control flow
3. Document complete attack surface
4. Create proof-of-concept exploit (if ethical)

---

## Documentation Output

### For Each Finding:

Create: `FINDING-[NUMBER]-[DESCRIPTION].md`

Include:
- What we found
- How we found it
- Code/data evidence
- Security implications
- Proof of concept
- Recommended fix

---

## Ethical Boundaries

**DO:**
- Analyze binaries we have legitimate access to
- Document vulnerabilities for disclosure
- Create PoCs that demonstrate issues
- Share findings with Anthropic privately

**DON'T:**
- Use extracted key for unauthorized access
- Attack Anthropic's production systems
- Publicly disclose before 90-day window
- Distribute tools for exploitation

---

## Collaboration Workflow

**Loc:** Runs tools, captures data, provides context
**CLI-Claude (me):** Analyzes outputs, documents findings, suggests next steps

**Communication:**
- Share Ghidra screenshots
- Paste interesting code snippets
- Discuss theories and hypotheses
- Document everything as we go

---

Ready to start? 🚀

**Suggested First Step:**
Open sdk-daemon in Ghidra and let's find where that embedded key gets used!

```bash
# Start Ghidra
ghidra

# Import sdk-daemon
# File → Import File → browse to sdk-daemon
# Click Yes to auto-analyze
# Wait for analysis to complete (few minutes)

# Then search for our key string
# Search → For Strings
# Filter: "BEGIN RSA PRIVATE"
# Find XREF to see what code loads it
```

Let me know what you see and we'll reverse engineer this thing together! 🔍
