#!/bin/bash
# Detect Spotlight weaponization on external volumes
# Usage: ./detect-spotlight-bombs.sh /Volumes/DRIVENAME

set -e

VOLUME="$1"

if [ -z "$VOLUME" ]; then
    echo "Usage: $0 /Volumes/DRIVENAME"
    exit 1
fi

if [ ! -d "$VOLUME" ]; then
    echo "Error: $VOLUME does not exist"
    exit 1
fi

echo "=== Spotlight Bomb Detection ==="
echo "Volume: $VOLUME"
echo "Started: $(date)"
echo

# 1. Check for symlink bombs
echo "[1/6] Checking for symlink bombs..."
SYMLINK_COUNT=$(find "$VOLUME" -type l 2>/dev/null | wc -l | tr -d ' ')
echo "  Found $SYMLINK_COUNT symlinks"
if [ "$SYMLINK_COUNT" -gt 100 ]; then
    echo "  ⚠️  WARNING: Excessive symlinks detected"
    echo "  Top symlink directories:"
    find "$VOLUME" -type l 2>/dev/null | xargs dirname | sort | uniq -c | sort -rn | head -5
fi

# 2. Check for deep directory nesting
echo
echo "[2/6] Checking for deep directory nesting..."
MAX_DEPTH=0
DEEPEST_PATH=""
while IFS= read -r dir; do
    DEPTH=$(echo "$dir" | tr -cd '/' | wc -c)
    if [ "$DEPTH" -gt "$MAX_DEPTH" ]; then
        MAX_DEPTH=$DEPTH
        DEEPEST_PATH="$dir"
    fi
done < <(find "$VOLUME" -type d 2>/dev/null | head -1000)
echo "  Maximum depth: $MAX_DEPTH levels"
if [ "$MAX_DEPTH" -gt 50 ]; then
    echo "  ⚠️  WARNING: Suspicious deep nesting detected"
    echo "  Deepest path: ${DEEPEST_PATH:0:100}..."
fi

# 3. Check for massive file counts in single directories
echo
echo "[3/6] Checking for directories with excessive file counts..."
echo "  (This may take a while...)"
find "$VOLUME" -type d 2>/dev/null | while read -r dir; do
    COUNT=$(ls -1 "$dir" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 10000 ]; then
        echo "  ⚠️  WARNING: $dir contains $COUNT files"
    fi
done | head -5

# 4. Check for corrupted Spotlight indexes
echo
echo "[4/6] Checking Spotlight index..."
if [ -d "$VOLUME/.Spotlight-V100" ]; then
    SIZE=$(du -sh "$VOLUME/.Spotlight-V100" 2>/dev/null | cut -f1)
    echo "  Spotlight index exists: $SIZE"
    FILE_COUNT=$(find "$VOLUME/.Spotlight-V100" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  Index file count: $FILE_COUNT"
    if [ "$FILE_COUNT" -gt 1000 ]; then
        echo "  ⚠️  WARNING: Spotlight index suspiciously large"
    fi
else
    echo "  No Spotlight index found (clean)"
fi

# 5. Check for Time Machine snapshot bombs
echo
echo "[5/6] Checking Time Machine snapshots..."
if [ -d "$VOLUME/.timemachine" ]; then
    SNAPSHOT_COUNT=$(find "$VOLUME/.timemachine" -name "*.backup" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Found $SNAPSHOT_COUNT snapshots"
    if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
        echo "  Snapshot dates:"
        find "$VOLUME/.timemachine" -name "*.backup" 2>/dev/null | xargs basename -a | while read snap; do
            DATE=$(echo "$snap" | cut -d'.' -f1)
            echo "    - $DATE"
        done
    fi
else
    echo "  No Time Machine snapshots found"
fi

# 6. Check for APFS sparse files
echo
echo "[6/6] Checking for suspicious sparse files..."
find "$VOLUME" -type f -size +1G 2>/dev/null | while read -r file; do
    APPARENT_SIZE=$(stat -f%z "$file" 2>/dev/null)
    REAL_SIZE=$(du -k "$file" 2>/dev/null | cut -f1)
    REAL_SIZE_BYTES=$((REAL_SIZE * 1024))
    if [ "$APPARENT_SIZE" -gt "$((REAL_SIZE_BYTES * 10))" ]; then
        echo "  ⚠️  WARNING: Sparse file detected: $file"
        echo "      Apparent size: $(numfmt --to=iec-i --suffix=B $APPARENT_SIZE 2>/dev/null || echo $APPARENT_SIZE)"
        echo "      Real size: $(numfmt --to=iec-i --suffix=B $REAL_SIZE_BYTES 2>/dev/null || echo $REAL_SIZE_BYTES)"
    fi
done | head -5

echo
echo "=== Detection Complete ==="
echo "Finished: $(date)"
