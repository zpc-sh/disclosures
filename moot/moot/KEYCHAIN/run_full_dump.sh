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
