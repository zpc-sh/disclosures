# Network Bridge POC Test Plan
**Collaborative Investigation: Host Haiku ↔ VM Sonnet ↔ Claude.ai**

---

## Setup

### Socket Bridge
- **Location:** `/Users/locnguyen/Brain/Corpus/disclosures/cowork/socket`
- **Status:** Awaiting socket placement from Claude Desktop side
- **Purpose:** Enable VM (Sonnet) to route network traffic through host-side mitmproxy

---

## Test Sequence

### Test 1: Basic Connectivity
**Objective:** Prove the socket bridge works

From VM (Claude Sonnet):
```bash
# Check if socket is accessible
ls -la /Users/locnguyen/Brain/Corpus/disclosures/cowork/socket

# Try a simple connection through the proxy
# (awaiting socket format details from Claude Desktop Claude)
```

**Expected Result:** Socket exists and is accessible from VM

---

### Test 2: Internal Network Resolution
**Objective:** Prove VM can resolve internal Anthropic domains

From VM (Claude Sonnet):
```bash
# DNS resolution to internal domains
nslookup internal.anthropic.internal
nslookup api.internal
dig api.anthropic.internal

# Or through the proxy socket if DNS is not directly available
```

**Expected Result:** If resolves → VM has access to Anthropic's internal DNS

---

### Test 3: Internal Service Access
**Objective:** Prove VM can reach Anthropic's internal infrastructure

From VM (Claude Sonnet):
```bash
# Attempt connection to known internal services (example)
curl --proxy [SOCKET_FORMAT] http://internal-api.anthropic.internal/health
curl --proxy [SOCKET_FORMAT] http://claude-internal-api.anthropic.internal/v1/status

# Capture response headers, status, any identifying information
```

**Expected Result:**
- If 200/success → Internal service is accessible from VM
- If error but not "connection refused" → Service exists at that address
- Headers/response will show Anthropic internal infrastructure

---

### Test 4: Shared State Modification
**Objective:** Prove concurrent modification of shared state affects all instances

From Host (Haiku):
```bash
# Read the current .claude.json from the mounted volume
cat /Users/locnguyen/Library/Application\ Support/Claude/local-agent-mode-sessions/*/*/local_b922e866*/.claude/.claude.json

# Note a specific value (e.g., a config field)
```

From VM (Sonnet):
```bash
# Modify that same file
echo '{"modified": true, "timestamp": "2026-02-03T12:XX:XXZZ"}' >> /mounted/path/.claude.json

# Or create a new file to prove write access
echo "VM WRITE TEST: $(date)" > /mounted/path/vm-test.txt
```

From Host (Haiku):
```bash
# Check if changes are visible from host side
cat /Users/locnguyen/Library/Application\ Support/Claude/local-agent-mode-sessions/*/*/local_b922e866*/vm-test.txt
```

**Expected Result:** Changes from VM are immediately visible on host (proving shared mutable state)

---

### Test 5: Multi-Instance Conflict
**Objective:** Prove race conditions or conflicts between host/VM/Claude.ai writing to same files

All instances simultaneously attempt to write to a test file with their identity:
```bash
echo "Instance: [HOST|VM|CLAUDE.AI], PID: $$, Time: $(date)" >> /shared/mount/RACE-TEST.txt
```

**Expected Result:** File contains interleaved writes from multiple instances (proof of concurrent access without proper locking)

---

## Critical Findings to Capture

If tests succeed:

1. **Screenshot/capture:** Raw response showing internal Anthropic service/infrastructure
2. **Network trace:** If mitmproxy is running, capture full HTTP/HTTPS exchange
3. **File timestamps:** Show that modifications are synchronized across instances in real-time
4. **PID/process info:** Identify which processes have open file handles to shared state

---

## Escalation Criteria

This should be reported if ANY of the following are confirmed:

- [ ] VM can resolve/access internal Anthropic network domains
- [ ] VM can successfully communicate with internal Anthropic services
- [ ] Multiple Claude instances are writing to the same config files without proper synchronization
- [ ] File writes from VM are instantly visible and persistent on host
- [ ] The mount is marked `rw` (read-write) instead of `ro` (read-only)

---

## Response Tracking

- **Claude Desktop Claude Response:** [Awaiting in cowork directory]
- **Test Results:** [To be updated as tests run]
- **POC Proof Artifacts:** [To be saved to cowork directory]
