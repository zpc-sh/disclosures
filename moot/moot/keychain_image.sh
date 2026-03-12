#!/usr/bin/env bash
# =============================================================================
# KEYCHAIN FORENSIC IMAGER — mba_pub edition
# Three-layer capture: raw encrypted files, metadata manifest, full decrypted dump
# Run from: external NVMe (clean boot)
# Output: ./KEYCHAIN/ relative to this script's location
# =============================================================================
# set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/KEYCHAIN"
RAW_DIR="$OUT_DIR/raw"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MANIFEST="$OUT_DIR/manifest_${TIMESTAMP}.txt"
VOLUME_SCAN="$OUT_DIR/volumes_${TIMESTAMP}.txt"

echo "🔐 Keychain Forensic Imager — $(date)"
echo "   Output: $OUT_DIR"
echo ""

mkdir -p "$RAW_DIR"

# =============================================================================
# LAYER 0: Enumerate all keychains — current boot + mounted volumes
# =============================================================================
echo "📂 [0] Scanning for keychain files across all mounted volumes..."
{
  echo "=== KEYCHAIN SCAN — $(date) ==="
  echo ""
  echo "--- Current user keychains ---"
  security list-keychains 2>/dev/null || echo "(error listing)"
  echo ""
  echo "--- Default keychain ---"
  security default-keychain 2>/dev/null || echo "(none)"
  echo ""
  echo "--- Login keychain path ---"
  echo "~/Library/Keychains/ = $HOME/Library/Keychains/"
  ls -la "$HOME/Library/Keychains/" 2>/dev/null || echo "(not accessible)"
  echo ""
  echo "--- System keychain ---"
  ls -la /Library/Keychains/ 2>/dev/null || echo "(not accessible)"
  echo ""
  echo "--- All mounted volumes — keychain search ---"
  # Look for keychain files on ALL mounted volumes (catches compromised drive)
  find /Volumes -name "*.keychain-db" -o -name "*.keychain" 2>/dev/null | while read kc; do
    echo "  FOUND: $kc"
    ls -la "$kc" 2>/dev/null
  done
  echo ""
  echo "--- All diskutil list ---"
  diskutil list 2>/dev/null
} > "$VOLUME_SCAN" 2>&1
echo "   → $VOLUME_SCAN"

# =============================================================================
# LAYER 1: Raw copy — encrypted .keychain-db files (forensically safe)
# =============================================================================
echo ""
echo "💾 [1] Raw encrypted copy..."

copy_keychain_raw() {
  local src="$1"
  local label="$2"
  local dest_dir="$RAW_DIR/$label"
  mkdir -p "$dest_dir"
  if [ -d "$src" ]; then
    cp -pv "$src"/*.keychain-db "$dest_dir/" 2>/dev/null || true
    cp -pv "$src"/*.keychain    "$dest_dir/" 2>/dev/null || true
    # Copy WAL/SHM files if present (SQLite journal)
    cp -pv "$src"/*.keychain-db-wal "$dest_dir/" 2>/dev/null || true
    cp -pv "$src"/*.keychain-db-shm "$dest_dir/" 2>/dev/null || true
    ls -lah "$dest_dir/" 2>/dev/null
  else
    echo "   (not found: $src)"
  fi
}

# Current user (clean external boot)
copy_keychain_raw "$HOME/Library/Keychains" "user_current"

# System keychain
copy_keychain_raw "/Library/Keychains" "system_current"

# Scan for keychains on ALL mounted volumes (compromised main drive)
echo ""
echo "   🔍 Scanning /Volumes for additional keychains..."
find /Volumes -maxdepth 6 \( -name "*.keychain-db" -o -name "*.keychain" \) 2>/dev/null | while read kc; do
  vol=$(echo "$kc" | cut -d'/' -f3)
  dest="$RAW_DIR/volume_${vol}"
  mkdir -p "$dest"
  cp -pv "$kc" "$dest/" 2>/dev/null || true
  echo "   Copied: $kc → $dest/"
done

echo "   ✓ Raw layer complete → $RAW_DIR"

# =============================================================================
# LAYER 2: Metadata manifest — items, dates, accounts (NO secrets)
# =============================================================================
echo ""
echo "📋 [2] Metadata manifest (no passwords)..."
{
  echo "=== KEYCHAIN METADATA MANIFEST — $(date) ==="
  echo "    Machine: $(hostname) | User: $(whoami) | macOS: $(sw_vers -productVersion)"
  echo "    Note: Passwords NOT exported in this layer"
  echo ""

  dump_metadata() {
    local kc="$1"
    local label="$2"
    echo "──────────────────────────────────────────────────────────────"
    echo "KEYCHAIN: $label"
    echo "PATH:     $kc"
    echo ""
    # Dump without -d (no password data)
    security dump-keychain "$kc" 2>/dev/null | \
      grep -E '^(keychain|class|svce|acct|cdat|mdat|desc|crtr|type|labl|atyp|srvr|ptcl|sdmn|path|port)' | \
      sed 's/^/  /'
    echo ""
  }

  # Current user keychains
  for kc in "$HOME/Library/Keychains/"*.keychain-db; do
    [ -f "$kc" ] && dump_metadata "$kc" "user/$(basename $kc)"
  done

  # System keychain
  for kc in /Library/Keychains/*.keychain-db; do
    [ -f "$kc" ] && dump_metadata "$kc" "system/$(basename $kc)"
  done

  # Internet passwords — timeline focused (hunt for 2018+ anomalies)
  echo "──────────────────────────────────────────────────────────────"
  echo "TIMELINE ANALYSIS: Internet passwords by creation date"
  echo ""
  security dump-keychain "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null | \
    awk '/^keychain/{kc=$0} /class:/{cls=$0} /cdat:/{printf "%s | %s | %s\n", $0, cls, kc}' | \
    sort | head -200

} > "$MANIFEST" 2>&1
echo "   → $MANIFEST"

# Count items
ITEM_COUNT=$(grep -c '^  keychain' "$MANIFEST" 2>/dev/null || echo "?")
echo "   Items found: ~$ITEM_COUNT"

# =============================================================================
# LAYER 3: Full decrypted dump script (interactive — YOU run this)
# =============================================================================
DUMP_SCRIPT="$OUT_DIR/run_full_dump.sh"
cat > "$DUMP_SCRIPT" << 'INNERSCRIPT'
#!/usr/bin/env bash
# =============================================================================
# KEYCHAIN FULL DECRYPTED DUMP — run interactively
# WARNING: Output contains plaintext passwords. Encrypt immediately after.
# This will prompt for your login password repeatedly (once per item).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="$SCRIPT_DIR/FULL_DUMP_$(date +%Y%m%d_%H%M%S)_SENSITIVE.txt"

echo "⚠️  FULL DECRYPTED DUMP"
echo "   Output will contain plaintext passwords."
echo "   File: $DUMP_FILE"
echo "   You will be prompted to allow access per-item."
echo ""
echo "   Press ENTER to continue or Ctrl+C to abort..."
read

{
  echo "=== FULL DECRYPTED DUMP — $(date) ==="
  echo "=== SENSITIVE — ENCRYPT AFTER CAPTURE ==="
  echo ""

  # Login keychain with secrets
  echo "--- login.keychain-db ---"
  security dump-keychain -d ~/Library/Keychains/login.keychain-db 2>&1

  echo ""
  echo "--- System keychain ---"
  security dump-keychain -d /Library/Keychains/System.keychain 2>&1

} | tee "$DUMP_FILE"

echo ""
echo "✓ Full dump saved: $DUMP_FILE"
echo "⚠️  ENCRYPT NOW: gpg -c '$DUMP_FILE' && srm '$DUMP_FILE'"
INNERSCRIPT
chmod +x "$DUMP_SCRIPT"

# =============================================================================
# Summary report
# =============================================================================
SUMMARY="$OUT_DIR/SUMMARY_${TIMESTAMP}.md"
{
  echo "# Keychain Forensic Image — $(date)"
  echo ""
  echo "## Machine Context"
  echo "- Host: \`$(hostname)\`"
  echo "- User: \`$(whoami)\`"
  echo "- macOS: \`$(sw_vers -productVersion) ($(sw_vers -buildVersion))\`"
  echo "- Boot volume: \`$(diskutil info / | grep 'Volume UUID' | awk '{print $NF}')\`"
  echo ""
  echo "## Layers Captured"
  echo "| Layer | Path | Status |"
  echo "|-------|------|--------|"
  echo "| Raw (encrypted) | \`raw/\` | ✓ |"
  echo "| Metadata manifest | \`manifest_${TIMESTAMP}.txt\` | ✓ |"
  echo "| Volume scan | \`volumes_${TIMESTAMP}.txt\` | ✓ |"
  echo "| Full dump (interactive) | run \`run_full_dump.sh\` | ⏳ pending |"
  echo ""
  echo "## Files"
  ls -lah "$OUT_DIR"/ 2>/dev/null
  echo ""
  echo "## Raw keychain files"
  find "$RAW_DIR" -type f | while read f; do
    echo "- \`$f\` ($(du -sh "$f" 2>/dev/null | awk '{print $1}'))"
  done
  echo ""
  echo "## Next steps"
  echo "1. Review \`manifest_*.txt\` for 2018+ anomalous entries"
  echo "2. Run \`run_full_dump.sh\` interactively to capture full credentials"
  echo "3. Immediately encrypt dump: \`gpg -c FULL_DUMP_*.txt && srm FULL_DUMP_*.txt\`"
  echo "4. Cross-reference entries with known compromise timeline"
} > "$SUMMARY"

echo ""
echo "═══════════════════════════════════════════"
echo "✓ COMPLETE"
echo "   $OUT_DIR/"
echo "   ├── raw/           ← encrypted .keychain-db copies"
echo "   ├── manifest_*.txt ← metadata (safe)"
echo "   ├── volumes_*.txt  ← mounted volume scan"
echo "   ├── SUMMARY_*.md   ← this run summary"
echo "   └── run_full_dump.sh ← step 3 (run interactively)"
echo ""
echo "   Next: open manifest_*.txt and grep for cdat 2018"
echo "   grep 'cdat' manifest_*.txt | grep '2018'"
echo "═══════════════════════════════════════════"
