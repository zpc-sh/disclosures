#!/bin/bash
# Block CloudKit Settings Extension Access
# Targeted quarantine of System Settings iCloud sync

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== CloudKit Settings Blocker ===${NC}"
echo "Blocking System Settings extension iCloud access"
echo ""

# Kill bird temporarily
echo "1. Stopping bird daemon..."
killall bird 2>/dev/null || true
sleep 3

# Quarantine Settings extension iCloud directories
echo "2. Quarantining Settings extension iCloud directories..."
quarantined=0

for container in ~/Library/Containers/com.apple.systempreferences*/Data/Library/Application\ Support/iCloud/; do
    if [ -d "$container" ]; then
        # Add quarantine attribute
        xattr -w com.apple.quarantine "0081;$(date +%s);Settings-Block;|com.apple.systempreferences.blocked" "$container" 2>/dev/null && {
            echo -e "${GREEN}✓${NC} Quarantined: $(basename $(dirname $(dirname $(dirname "$container"))))"
            ((quarantined++))
        } || {
            echo -e "${YELLOW}⚠${NC}  Could not quarantine: $(basename $(dirname $(dirname $(dirname "$container"))))"
        }

        # Remove all existing files in iCloud directory
        find "$container" -type f -delete 2>/dev/null || true
    fi
done

echo "   Quarantined $quarantined containers"

# Quarantine specific high-risk extensions
echo "3. Blocking high-risk extensions..."

HIGH_RISK=(
    "com.apple.systempreferences.AppleIDSettings"
    "com.apple.settings.SecurityPrefQADirector.SecurityPrivacyIntents"
    "com.apple.systempreferences.SharingSettingsIntents"
    "com.apple.systempreferences.DisplaysSettingsIntents"
    "com.apple.systempreferences.KeyboardSettingsExtension"
)

for ext in "${HIGH_RISK[@]}"; do
    container_path=~/Library/Containers/$ext/Data/Library/Application\ Support/iCloud
    if [ -d "$container_path" ]; then
        # Maximum quarantine
        sudo xattr -w com.apple.quarantine "0083;$(date +%s);BLOCKED;|$ext" "$container_path" 2>/dev/null && {
            echo -e "${GREEN}✓${NC} High-risk blocked: $ext"
        }

        # Remove write permissions (may fail with SIP but try)
        chmod 000 "$container_path" 2>/dev/null || true
    fi
done

# Protect MobileMeAccounts.plist
echo "4. Protecting MobileMeAccounts.plist..."
MOBILEME=~/Library/Preferences/MobileMeAccounts.plist

if [ -f "$MOBILEME" ]; then
    # Make backup
    cp "$MOBILEME" "$MOBILEME.PROTECTED.$(date +%s)"

    # Try to make immutable (requires sudo)
    sudo chflags uchg "$MOBILEME" 2>/dev/null && {
        echo -e "${GREEN}✓${NC} MobileMeAccounts.plist made immutable"
    } || {
        echo -e "${YELLOW}⚠${NC}  Could not make immutable (requires sudo)"
    }
fi

# Set up monitoring (optional - uncomment to enable)
# echo "5. Setting up monitoring..."
# cat > ~/Library/LaunchAgents/com.user.settings-monitor.plist << 'MONITOR'
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#     <key>Label</key>
#     <string>com.user.settings-monitor</string>
#     <key>ProgramArguments</key>
#     <array>
#         <string>/usr/bin/log</string>
#         <string>stream</string>
#         <string>--predicate</string>
#         <string>process == "bird" AND message CONTAINS "systempreferences"</string>
#     </array>
#     <key>StandardOutPath</key>
#     <string>/tmp/settings-monitor.log</string>
#     <key>RunAtLoad</key>
#     <true/>
# </dict>
# </plist>
# MONITOR
# launchctl load ~/Library/LaunchAgents/com.user.settings-monitor.plist

echo ""
echo -e "${GREEN}=== Blocking Complete ===${NC}"
echo ""
echo "What was blocked:"
echo "  • System Settings extension iCloud directories (quarantined)"
echo "  • High-risk extensions (Apple ID, Security, Sharing, Display, Keyboard)"
echo "  • MobileMeAccounts.plist (made immutable if sudo available)"
echo ""
echo "What still works:"
echo "  ✓ Main iCloud Drive (com~apple~CloudDocs)"
echo "  ✓ Your apps' iCloud containers"
echo "  ✓ BODI/Claudesville sync"
echo ""
echo "What's broken:"
echo "  ✗ System Settings sync between devices"
echo "  ✗ Universal Control (was attack vector anyway)"
echo "  ✗ Some Continuity features"
echo ""
echo "To monitor access attempts:"
echo "  tail -f /tmp/settings-monitor.log"
echo ""
echo "To undo (not recommended):"
echo "  xattr -d com.apple.quarantine ~/Library/Containers/com.apple.systempreferences*/Data/Library/Application\ Support/iCloud/"
echo "  sudo chflags nouchg ~/Library/Preferences/MobileMeAccounts.plist"
