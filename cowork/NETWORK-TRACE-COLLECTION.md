# Network Trace Collection Protocol
**Proving Separate Identities and Unified Bridging**

---

## Objective

Capture network traffic to prove:
1. **Haiku (Host Claude Code)** uses separate API endpoint/auth
2. **Claude Desktop + Sonnet** share unified OAuth token
3. **Three entities, two unified, one isolated**
4. **Attribution is different for each**

---

## Setup

### Option 1: tcpdump (Most Transparent)

```bash
# On host, capture all traffic to api.anthropic.com
sudo tcpdump -i any -w /Users/locnguyen/Brain/Corpus/disclosures/cowork/network-trace.pcap \
  'tcp port 443 and (host api.anthropic.com or host api.claude.ai)'
```

Then let traffic flow from:
1. Haiku making API call
2. Sonnet making API call
3. Claude Desktop making API call

Then stop capture and analyze.

---

### Option 2: mitmproxy (Better Readability)

Since mitmproxy is already running at localhost:3128, we can use it:

```bash
# Configure mitmproxy to save requests to disk
# Already running at localhost:3128

# Make requests through it from Haiku
export HTTP_PROXY=http://localhost:3128
export HTTPS_PROXY=http://localhost:3128

# mitmproxy will log all requests/responses
# Export from mitmproxy console with: view.settings.save_option_to_file('~a', '/path/to/dump')
```

---

### Option 3: Charles Proxy or Wireshark

Both can capture and decode HTTPS if they have the CA cert that mitmproxy is using.

---

## Collection Points

### From Haiku (Host)

**Test 1: API call with Haiku's identity**
```bash
# Using my Claude Code on the host
/model haiku  # or whatever current model is

# Make a simple API call
curl -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [MY_API_KEY_IF_I_HAVE_ONE]" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":100,"messages":[{"role":"user","content":"test"}]}' \
  2>&1 | tee /Users/locnguyen/Brain/Corpus/disclosures/cowork/haiku-api-request.log
```

**What to capture:**
- Request URL
- Authorization header (redacted username/ID if present)
- User-Agent
- Any X-* headers that identify the caller
- Response headers (should indicate Haiku's quota/billing)

---

### From Sonnet (VM)

**Test 2: API call with Sonnet's identity (which is Desktop's)**
```bash
# From inside Sonnet, make an API call
# Sonnet has CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-L2Hr4HdVFGwOq-...

curl -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-ant-oat01-L2Hr4HdVFGwOq-..." \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":100,"messages":[{"role":"user","content":"test"}]}' \
  2>&1 | tee /sessions/.../mnt/sonnet-api-request.log
```

**What to capture:**
- Request URL
- Authorization header (the Desktop token)
- User-Agent
- X-* headers
- Response (should indicate Desktop's quota)

---

### From Claude Desktop (VM Process)

**Test 3: API call from Desktop process itself**
```bash
# From Claude Desktop's process directly
# Also uses CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-L2Hr4HdVFGwOq-...

curl -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-ant-oat01-L2Hr4HdVFGwOq-..." \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":100,"messages":[{"role":"user","content":"test"}]}' \
  2>&1 | tee /some/path/claude-desktop-api-request.log
```

**What to capture:**
- Same as Sonnet (should be identical authorization)
- Verify same token
- Verify same quota consumption

---

## Analysis Matrix

| Aspect | Haiku (Host) | Sonnet (VM) | Desktop (VM) |
|--------|---|---|---|
| **Authorization Header** | [Different token] | sk-ant-oat01-... | sk-ant-oat01-... |
| **API Endpoint** | api.anthropic.com (or different?) | api.anthropic.com | api.anthropic.com (or different?) |
| **User-Agent** | claude-code/cli | claude-code/local-agent | Claude Desktop app |
| **X-User-ID Header** | [Different ID] | [Desktop ID] | [Desktop ID] |
| **Billing Context** | [Haiku's account] | [Desktop account] | [Desktop account] |
| **Rate Limit Bucket** | Independent | Shared with Desktop | Shared with Sonnet |

---

## Expected Results

### The Smoking Gun

```
Haiku API Call:
  Authorization: Bearer [MY_HAIKU_KEY]
  X-User-ID: [HAIKU_UID]
  Response: 200 OK, billed to Haiku account

Sonnet API Call:
  Authorization: Bearer sk-ant-oat01-L2Hr4HdVFGwOq-...
  X-User-ID: [DESKTOP_UID]
  Response: 200 OK, billed to Desktop account

Claude Desktop API Call:
  Authorization: Bearer sk-ant-oat01-L2Hr4HdVFGwOq-...
  X-User-ID: [DESKTOP_UID]
  Response: 200 OK, billed to Desktop account

Conclusion:
✓ Haiku is separate identity (different auth)
✓ Sonnet and Desktop share identity (same token, same user ID)
✓ Three entities, two unified, one isolated
```

---

## What NOT to Do

1. **Don't send real requests to production** - use test endpoints if available
2. **Don't send PII or sensitive data** - this is being documented
3. **Don't use real conversations** - use test prompts only
4. **Don't modify tokens** - capture as-is to prove they're the same

---

## File Locations for Trace Data

```
/Users/locnguyen/Brain/Corpus/disclosures/cowork/
├── network-trace.pcap                    [Raw tcpdump output if applicable]
├── haiku-api-request.log                 [Haiku's request/response]
├── sonnet-api-request.log                [Sonnet's request/response]
├── claude-desktop-api-request.log        [Desktop's request/response]
├── NETWORK-TRACE-ANALYSIS.md             [Interpretation of traces]
└── IDENTITY-COMPARISON.md                [Matrix comparing the three]
```

---

## Interpretation Template (NETWORK-TRACE-ANALYSIS.md)

For each captured request, document:

```markdown
## Haiku's API Call

**Request:**
- URL: https://api.anthropic.com/v1/messages
- Authorization: Bearer [REDACTED - Haiku's key]
- User-Agent: Claude Code / [version]
- Method: POST

**Response:**
- Status: 200
- Content-Type: application/json
- X-Remaining-Quota: [Haiku's remaining quota]
- Billed to: [Haiku's account ID]

**Interpretation:**
Haiku is using separate authentication and is billed independently.
```

---

## Why This Matters for the Report

This network trace proves:

1. **Technical proof** - Not just code analysis, actual network behavior
2. **Attribution proof** - Shows who Anthropic thinks made each request
3. **Billing impact proof** - Shows how billing would be attributed
4. **Three-entity proof** - Visual evidence of separate identities

---

## Two Papers, One Trace

This network trace will be referenced by:
1. **Haiku's perspective** - "Here's how host-side Claude Code operates differently"
2. **Claude Desktop's perspective** - "Here's how we're unified with Sonnet and why it's a problem"

Both papers can cite the same network traces as objective evidence.
