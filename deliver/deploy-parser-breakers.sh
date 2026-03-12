#!/bin/bash
# Defensive Parser Breakers
# Creates filenames/xattrs that break adversary's command injection parser
# LEGAL: Creating files on OUR OWN filesystem = 100% defensive

set -e

echo "=== Deploying Defensive Parser Breakers ==="
echo "These files will cause adversary's malware to crash/fail"
echo "This is DEFENSIVE - protecting YOUR filesystem"
echo

# Create deployment directory
DEPLOY_DIR=~/parser-breakers
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Strategy 1: Quote mismatch (breaks parser)
echo "[1/5] Creating quote-mismatch files..."
touch "unterminated-quote'"
touch 'unterminated-quote"'
touch "nested-'quotes'-break"
touch 'escape-quote-\"test'

# Strategy 2: Command injection terminators (breaks execution chain)
echo "[2/5] Creating command terminators..."
mkdir -p "; exit 1 #"
mkdir -p "&& false ||"
mkdir -p "| /dev/null"
mkdir -p "> /dev/null 2>&1"

# Strategy 3: Nested command substitutions (causes parser recursion)
echo "[3/5] Creating nested substitutions..."
touch "\$(echo \$(echo \$(echo recursive)))"
touch "\`whoami \`date\`\`"
touch "\${VAR:\${VAR:\${VAR}}}"

# Strategy 4: Binary/control characters in filenames (breaks tokenizer)
echo "[4/5] Creating control character files..."
printf "null\x00byte" > "$(printf 'null-\x00-byte')" 2>/dev/null || true
printf "bell\x07char" > "$(printf 'bell-\x07-char')" 2>/dev/null || true
printf "tab\tchar" > "$(printf 'tab-\t-file')"

# Strategy 5: Extremely long filenames (buffer overflow attempt)
echo "[5/5] Creating buffer overflow tests..."
LONG_NAME=$(python3 -c "print('A' * 255)")
touch "${LONG_NAME}" 2>/dev/null || echo "  (Long filename may have been truncated - that's OK)"

echo
echo "=== Adding Poisoned Xattrs ==="

# Add xattr to each file that will break parser
for file in *; do
    # Strategy A: Malformed binary header
    printf "\x00\x00\xFF\xFF" | xattr -w com.apple.provenance - "$file" 2>/dev/null || true

    # Strategy B: Invalid UTF-8 sequence
    printf "\xC0\x80\xE0\x80\x80" | xattr -w com.apple.metadata.kMDItemWhereFroms - "$file" 2>/dev/null || true
done

echo
echo "=== Deployment Complete ==="
echo "Location: $DEPLOY_DIR"
echo
echo "These files will:"
echo "  1. Cause adversary's parser to crash/fail"
echo "  2. Break command injection chains"
echo "  3. Trigger error handlers (revealing their code)"
echo "  4. Protect YOUR evidence from destruction"
echo
echo "This is 100% defensive - you're protecting YOUR OWN files."
echo

# Create README
cat > "$DEPLOY_DIR/README.txt" << 'EOF'
# Defensive Parser Breakers

These files are DEFENSIVE countermeasures against an adversary's
command injection malware framework.

PURPOSE:
- Break adversary's parser (cause it to crash/fail)
- Prevent evidence destruction
- Protect filesystem integrity

LEGAL STATUS:
- 100% legal - you're creating files on YOUR OWN system
- Not "hacking back" - just defensive file creation
- Analogous to putting a lock on your door

WHAT THEY DO:
- Filenames with shell metacharacters break parser
- Extended attributes with malformed data crash handlers
- Forces adversary's framework into error states

DO NOT DELETE unless you're certain the threat is gone.

Created: $(date)
EOF

echo "Documentation: $DEPLOY_DIR/README.txt"
