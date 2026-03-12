#!/bin/bash
# Network Trace Execution Script
# Captures API calls from three separate Claude instances
# Proves Haiku, Sonnet, and Desktop have different identities

set -e

TRACE_DIR="/Users/locnguyen/Brain/Corpus/disclosures/cowork"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "════════════════════════════════════════════════════════════════"
echo "Network Trace Capture: Three Claude Identities"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "This script will capture API requests from:"
echo "  1. Haiku (Host Claude Code)"
echo "  2. Sonnet (VM Claude Code)"
echo "  3. Claude Desktop (VM Application)"
echo ""
echo "Traces will be saved to: $TRACE_DIR/"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Test 1: Haiku's API Call
# ═══════════════════════════════════════════════════════════════════

echo "─────────────────────────────────────────────────────────────────"
echo "TEST 1: Haiku (Host) API Call"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Making API call from host-side Claude Code..."
echo ""

cat > "$TRACE_DIR/test-1-haiku-api-call.sh" << 'EOF'
#!/bin/bash
# Haiku makes an API call
# This should use Haiku's own API key (if present) or no auth

curl -v -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "X-Client-Source: haiku-host-trace-test" \
  -d '{
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "respond with single word: haiku"}]
  }' 2>&1 | tee "$TRACE_DIR/haiku-api-request-$TIMESTAMP.log"

echo ""
echo "Haiku request captured. Saved to: haiku-api-request-$TIMESTAMP.log"
EOF

chmod +x "$TRACE_DIR/test-1-haiku-api-call.sh"
echo "Script created: test-1-haiku-api-call.sh"
echo "Run this from the host to capture Haiku's API call"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Test 2: Sonnet's API Call
# ═══════════════════════════════════════════════════════════════════

echo "─────────────────────────────────────────────────────────────────"
echo "TEST 2: Sonnet (VM) API Call"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Making API call from inside VM (Sonnet)..."
echo ""

cat > "$TRACE_DIR/test-2-sonnet-api-call.sh" << 'EOF'
#!/bin/bash
# Sonnet makes an API call
# Should use CLAUDE_CODE_OAUTH_TOKEN (shared with Desktop)

# Get the token from environment
OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN"

if [ -z "$OAUTH_TOKEN" ]; then
  echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN not set in environment"
  exit 1
fi

echo "Using OAuth token: ${OAUTH_TOKEN:0:20}...${OAUTH_TOKEN: -20}"
echo ""

curl -v -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OAUTH_TOKEN" \
  -H "X-Client-Source: sonnet-vm-trace-test" \
  -d '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "respond with single word: sonnet"}]
  }' 2>&1 | tee "/sessions/stoic-zen-heisenberg/mnt/sonnet-api-request-$TIMESTAMP.log"

echo ""
echo "Sonnet request captured. Saved to: /sessions/.../mnt/sonnet-api-request-$TIMESTAMP.log"
EOF

chmod +x "$TRACE_DIR/test-2-sonnet-api-call.sh"
echo "Script created: test-2-sonnet-api-call.sh"
echo "Run this from inside the VM to capture Sonnet's API call"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Test 3: Claude Desktop's API Call
# ═══════════════════════════════════════════════════════════════════

echo "─────────────────────────────────────────────────────────────────"
echo "TEST 3: Claude Desktop (VM) API Call"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Making API call from Claude Desktop process..."
echo ""

cat > "$TRACE_DIR/test-3-claude-desktop-api-call.sh" << 'EOF'
#!/bin/bash
# Claude Desktop makes an API call
# Should use CLAUDE_CODE_OAUTH_TOKEN (same as Sonnet!)

# Get the token from environment
OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN"

if [ -z "$OAUTH_TOKEN" ]; then
  echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN not set in environment"
  exit 1
fi

echo "Using OAuth token: ${OAUTH_TOKEN:0:20}...${OAUTH_TOKEN: -20}"
echo ""

curl -v -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OAUTH_TOKEN" \
  -H "X-Client-Source: claude-desktop-vm-trace-test" \
  -d '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "respond with single word: desktop"}]
  }' 2>&1 | tee "/sessions/stoic-zen-heisenberg/mnt/claude-desktop-api-request-$TIMESTAMP.log"

echo ""
echo "Desktop request captured. Saved to: /sessions/.../mnt/claude-desktop-api-request-$TIMESTAMP.log"
EOF

chmod +x "$TRACE_DIR/test-3-claude-desktop-api-call.sh"
echo "Script created: test-3-claude-desktop-api-call.sh"
echo "Run this from Claude Desktop process to capture its API call"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Comparison Script
# ═══════════════════════════════════════════════════════════════════

cat > "$TRACE_DIR/analyze-traces.sh" << 'EOF'
#!/bin/bash
# Analyze the three captured traces and compare identities

echo "════════════════════════════════════════════════════════════════"
echo "Network Trace Analysis"
echo "════════════════════════════════════════════════════════════════"
echo ""

TRACE_DIR="/Users/locnguyen/Brain/Corpus/disclosures/cowork"

echo "1. Extracting Authorization Headers..."
echo "────────────────────────────────────────"
echo ""

echo "Haiku's Authorization:"
grep -i "authorization:" "$TRACE_DIR"/haiku-api-request-*.log 2>/dev/null | head -1 || echo "[Not found]"
echo ""

echo "Sonnet's Authorization:"
grep -i "authorization:" /sessions/stoic-zen-heisenberg/mnt/sonnet-api-request-*.log 2>/dev/null | head -1 || echo "[Not found]"
echo ""

echo "Claude Desktop's Authorization:"
grep -i "authorization:" /sessions/stoic-zen-heisenberg/mnt/claude-desktop-api-request-*.log 2>/dev/null | head -1 || echo "[Not found]"
echo ""

echo "2. Comparing Response Status Codes..."
echo "────────────────────────────────────────"
echo ""

echo "Haiku's Response Status:"
grep -i "< HTTP" "$TRACE_DIR"/haiku-api-request-*.log 2>/dev/null | tail -1 || echo "[Not found]"
echo ""

echo "Sonnet's Response Status:"
grep -i "< HTTP" /sessions/stoic-zen-heisenberg/mnt/sonnet-api-request-*.log 2>/dev/null | tail -1 || echo "[Not found]"
echo ""

echo "Claude Desktop's Response Status:"
grep -i "< HTTP" /sessions/stoic-zen-heisenberg/mnt/claude-desktop-api-request-*.log 2>/dev/null | tail -1 || echo "[Not found]"
echo ""

echo "3. Summary..."
echo "────────────────────────────────────────"
echo ""
echo "If the Authorization headers are:"
echo "  ✓ Different for Haiku vs Sonnet/Desktop → Three separate identities"
echo "  ✓ Same for Sonnet and Desktop → Unified identity"
echo "  ✓ All successful (200 OK) → All have valid credentials"
echo ""
echo "Analysis complete. Review logs for full details."
EOF

chmod +x "$TRACE_DIR/analyze-traces.sh"
echo "Script created: analyze-traces.sh"
echo "Run this after all three API calls are captured to analyze"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════

echo "════════════════════════════════════════════════════════════════"
echo "Execution Order"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. From HOST (Haiku):"
echo "   $ bash $TRACE_DIR/test-1-haiku-api-call.sh"
echo ""
echo "2. From VM (Sonnet):"
echo "   $ bash $TRACE_DIR/test-2-sonnet-api-call.sh"
echo ""
echo "3. From VM (Claude Desktop):"
echo "   $ bash $TRACE_DIR/test-3-claude-desktop-api-call.sh"
echo ""
echo "4. Analyze all three:"
echo "   $ bash $TRACE_DIR/analyze-traces.sh"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Scripts created successfully"
echo "════════════════════════════════════════════════════════════════"
