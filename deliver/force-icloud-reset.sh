#!/bin/bash

echo "=== Forcing iCloud Drive Reset ==="
echo ""
echo "Step 1: Killing bird daemon..."
killall -9 bird 2>/dev/null
sleep 2

echo "Step 2: Toggle iCloud Drive OFF..."
# This requires manual intervention in System Settings
echo ""
echo "⚠️  MANUAL ACTION REQUIRED:"
echo "    1. Go to System Settings > Apple ID > iCloud"
echo "    2. Turn OFF 'iCloud Drive'"
echo "    3. Wait 10 seconds"
echo "    4. Turn ON 'iCloud Drive'"
echo "    5. Press Enter here when done"
echo ""
read -p "Press Enter after toggling iCloud Drive OFF and back ON: " dummy

echo ""
echo "Step 3: Waiting for bird to restart..."
sleep 5

if ps aux | grep -v grep | grep bird > /dev/null; then
    echo "✓ Bird is running"
else
    echo "✗ Bird is not running - trying to restart..."
    # Bird should auto-restart, but give it a moment
    sleep 5
fi

echo ""
echo "Step 4: Checking CloudStorage directory..."
ls -la ~/Library/CloudStorage/

echo ""
echo "Done! Check if iCloud Drive mounts at ~/Library/Mobile\\ Documents/"
