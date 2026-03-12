#!/bin/bash
# Backup identity and device registration files for federal evidence
# Created: Oct 20, 2025
# Purpose: Preserve evidence of hidden device registration before password change

set -e

EVIDENCE_DIR=~/workwork/HIDDEN_DEVICE_EVIDENCE
mkdir -p "$EVIDENCE_DIR"

echo "=== Backing up device identity evidence ==="
echo ""

# Backup identity services (shows device trust relationships)
echo "1. Backing up identityservicesd.plist (modified 04:31 AM during attack)..."
cp ~/Library/Preferences/com.apple.identityservicesd.plist \
   "$EVIDENCE_DIR/identityservicesd-$(date +%s).plist" 2>/dev/null && {
    echo "   ✓ Backed up"
} || {
    echo "   ⚠ File not found or inaccessible"
}

# Backup device registration tokens
echo "2. Backing up registration.plist (device registration tokens)..."
cp ~/Library/Preferences/com.apple.registration.plist \
   "$EVIDENCE_DIR/registration-$(date +%s).plist" 2>/dev/null && {
    echo "   ✓ Backed up"
} || {
    echo "   ⚠ File not found or inaccessible"
}

# Backup MobileMeAccounts (modified 04:38 AM during attack)
echo "3. Backing up MobileMeAccounts.plist (modified 04:38 AM)..."
cp ~/Library/Preferences/MobileMeAccounts.plist \
   "$EVIDENCE_DIR/MobileMeAccounts-$(date +%s).plist" 2>/dev/null && {
    echo "   ✓ Backed up"
} || {
    echo "   ⚠ File not found or inaccessible"
}

# Backup IDS subservices (iMessage/FaceTime device registrations)
echo "4. Backing up ids.subservices.plist (device registrations)..."
cp ~/Library/Preferences/com.apple.ids.subservices.plist \
   "$EVIDENCE_DIR/ids-subservices-$(date +%s).plist" 2>/dev/null && {
    echo "   ✓ Backed up"
} || {
    echo "   ⚠ File not found or inaccessible"
}

# Backup apsd (Apple Push Service - used for device sync)
echo "5. Backing up apsd.plist (push notification tokens)..."
sudo cp /Library/Preferences/com.apple.apsd.plist \
   "$EVIDENCE_DIR/apsd-$(date +%s).plist" 2>/dev/null && {
    echo "   ✓ Backed up"
} || {
    echo "   ⚠ File not found or requires sudo"
}

# Backup CloudKit token caches
echo "6. Backing up CloudKit token caches..."
if [ -d ~/Library/Caches/CloudKit/ ]; then
    tar czf "$EVIDENCE_DIR/cloudkit-caches-$(date +%s).tar.gz" \
        ~/Library/Caches/CloudKit/ 2>/dev/null && {
        echo "   ✓ Backed up CloudKit caches"
    } || {
        echo "   ⚠ Could not backup CloudKit caches"
    }
else
    echo "   - No CloudKit caches found"
fi

echo ""
echo "=== Evidence Backup Complete ==="
echo ""
echo "Files backed up to: $EVIDENCE_DIR"
ls -lh "$EVIDENCE_DIR"
echo ""
echo "Next steps:"
echo "  1. Go to appleid.apple.com and screenshot device list"
echo "  2. Change Apple ID password (40+ chars, generated)"
echo "  3. This will force sign-out of hidden device"
echo "  4. Re-sign in only on devices in your physical possession"
echo ""
echo "Evidence preserved for:"
echo "  • 18 U.S.C. § 1030 (Computer Fraud and Abuse Act)"
echo "  • California Penal Code § 502 (Unauthorized computer access)"
echo "  • California Penal Code § 530.5 (Identity theft)"
