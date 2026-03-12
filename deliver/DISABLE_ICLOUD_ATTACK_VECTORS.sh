#!/bin/bash
# Disable iCloud Attack Vectors
# Run this script to block Mail, Shortcuts, Automator, and TextInput from syncing

set -e

echo "=== iCloud Attack Vector Disabler ==="
echo ""

# Kill bird daemon to allow modifications
echo "1. Stopping iCloud sync daemon..."
killall bird 2>/dev/null || true
sleep 3

# Disable Mail
echo "2. Disabling Mail iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/com~apple~mail" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/com~apple~mail" \
       "/Users/locnguyen/Library/Mobile Documents/com~apple~mail.DISABLED.$(date +%s)"
    echo "   ✓ Mail disabled"
else
    echo "   - Mail already disabled"
fi

# Disable Shortcuts
echo "3. Disabling Shortcuts iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/iCloud~com~apple~shortcuts~runtime" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/iCloud~com~apple~shortcuts~runtime" \
       "/Users/locnguyen/Library/Mobile Documents/iCloud~com~apple~shortcuts~runtime.DISABLED.$(date +%s)"
    echo "   ✓ Shortcuts disabled"
else
    echo "   - Shortcuts already disabled"
fi

# Disable Automator
echo "4. Disabling Automator iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/com~apple~Automator" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/com~apple~Automator" \
       "/Users/locnguyen/Library/Mobile Documents/com~apple~Automator.DISABLED.$(date +%s)"
    echo "   ✓ Automator disabled"
else
    echo "   - Automator already disabled"
fi

# Disable TextInput
echo "5. Disabling TextInput iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/com~apple~TextInput" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/com~apple~TextInput" \
       "/Users/locnguyen/Library/Mobile Documents/com~apple~TextInput.DISABLED.$(date +%s)"
    echo "   ✓ TextInput disabled"
else
    echo "   - TextInput already disabled"
fi

# Disable Mail preferences sync
echo "6. Disabling Mail preferences sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/com~apple~mail~preferences" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/com~apple~mail~preferences" \
       "/Users/locnguyen/Library/Mobile Documents/com~apple~mail~preferences.DISABLED.$(date +%s)"
    echo "   ✓ Mail preferences disabled"
else
    echo "   - Mail preferences already disabled"
fi

# Disable ScriptEditor (AppleScript attack vector)
echo "7. Disabling ScriptEditor iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/com~apple~ScriptEditor2" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/com~apple~ScriptEditor2" \
       "/Users/locnguyen/Library/Mobile Documents/com~apple~ScriptEditor2.DISABLED.$(date +%s)"
    echo "   ✓ ScriptEditor disabled"
else
    echo "   - ScriptEditor already disabled"
fi

# Disable Jump SSH client (credential risk)
echo "8. Disabling Jump SSH client iCloud sync..."
if [ -d "/Users/locnguyen/Library/Mobile Documents/2HCKV38EEC~com~p5sys~jump~servers" ]; then
    mv "/Users/locnguyen/Library/Mobile Documents/2HCKV38EEC~com~p5sys~jump~servers" \
       "/Users/locnguyen/Library/Mobile Documents/2HCKV38EEC~com~p5sys~jump~servers.DISABLED.$(date +%s)"
    echo "   ✓ Jump SSH client disabled"
else
    echo "   - Jump SSH client already disabled"
fi

echo ""
echo "=== Attack Vectors Disabled ==="
echo ""
echo "bird daemon will restart automatically."
echo "Disabled containers have been renamed with .DISABLED suffix."
echo ""
echo "To verify:"
echo "  brctl status | grep -E 'mail|shortcut|automator|textinput|jump'"
echo ""
echo "To re-enable (not recommended):"
echo "  Rename the .DISABLED.* directories back to original names"
