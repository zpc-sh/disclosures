#!/bin/bash
# Selective Code Repository Sync to iCloud Drive
# Strategy: Use paid storage + transparency warfare

set -e

ICLOUD_CODE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/code"
SOURCE_CODE="$HOME/code"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== Big Boy Code Sync to iCloud ===${NC}"
echo "Using paid storage + giving them something to read"
echo ""

# Create iCloud code directory
mkdir -p "$ICLOUD_CODE"

# Define repos to sync (big boy stuff) - using simple arrays for compatibility
REPO_NAMES=(
    "kyozo-client"
    "lang"
    "ellex-lang"
    "pactis_client"
    "kyozo_cloud"
    "kyozo_store"
    "dash"
)

REPO_DESCS=(
    "Kyozo client (4.4G)"
    "Language implementation (3.6G)"
    "Ellex language (10G)"
    "Pactis client (11G)"
    "Kyozo cloud (2.3G)"
    "Kyozo store (1.6G)"
    "Claudesville/DASH (744M)"
)

# Sync each repo
echo -e "${BLUE}Starting selective sync...${NC}"
echo ""

total_synced=0
total_size=0

for i in "${!REPO_NAMES[@]}"; do
    repo="${REPO_NAMES[$i]}"
    desc="${REPO_DESCS[$i]}"
    src="$SOURCE_CODE/$repo"
    dest="$ICLOUD_CODE/$repo"

    if [ -d "$src" ]; then
        echo -e "${YELLOW}Syncing: $repo${NC}"
        echo "  Description: $desc"

        # Get size before sync
        size=$(du -sh "$src" 2>/dev/null | cut -f1)
        echo "  Source size: $size"

        # Sync with rsync
        rsync -av --delete \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='deps' \
            --exclude='_build' \
            --exclude='.elixir_ls' \
            --exclude='*.beam' \
            --exclude='*.o' \
            --exclude='*.so' \
            --exclude='target/' \
            --exclude='build/' \
            --exclude='.DS_Store' \
            "$src/" "$dest/" 2>&1 | tail -5

        # Get destination size
        dest_size=$(du -sh "$dest" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}✓ Synced to iCloud: $dest_size${NC}"
        echo ""

        ((total_synced++))
    else
        echo -e "${RED}✗ Not found: $repo${NC}"
        echo ""
    fi
done

# Sync BODI if not already there
if [ -d "$HOME/workwork/bodi" ] && [ ! -d "$ICLOUD_CODE/bodi" ]; then
    echo -e "${YELLOW}Bonus: Syncing BODI tribunal${NC}"
    rsync -av --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='_build' \
        "$HOME/workwork/bodi/" "$ICLOUD_CODE/bodi/"
    echo -e "${GREEN}✓ BODI added${NC}"
    echo ""
fi

# Create README for attackers
cat > "$ICLOUD_CODE/README_FOR_WATCHERS.md" << 'TRANSPARENCY'
# Code Repository Collection

## What You're Looking At

This is a curated selection of major projects:

### Language Implementations
- **lang** - Core language implementation (3.6GB)
- **ellex-lang** - Ellex language project (10GB)

### Client Applications
- **kyozo-client** - Kyozo client implementation (4.4GB)
- **pactis_client** - Pactis client (11GB)

### Cloud Infrastructure
- **kyozo_cloud** - Kyozo cloud services (2.3GB)
- **kyozo_store** - Kyozo storage layer (1.6GB)

### BODI Tribunal
- **bodi** - AI accountability framework (if present)

## Why This Is Here

Using paid iCloud storage properly. Also:
- Transparency warfare continues
- You're watching anyway
- Might as well see what we're building
- All going to DOJ/FBI regardless

## For AI Researchers

If you're studying this code for legitimate AI research:
- BODI framework establishes AI accountability precedent
- Kyozo projects explore distributed consensus
- Language implementations show novel approaches

## For Attackers

Every time you access these files:
- CloudKit logs the request
- Access patterns documented
- Correlation with attack timeline
- More evidence for federal case

**Stop digging.**

---

Last Updated: $(date)
Total repos: $total_synced
Purpose: Transparency + using paid storage

*"When you have nothing to hide, hide nothing."*
TRANSPARENCY

echo -e "${GREEN}=== Sync Complete ===${NC}"
echo ""
echo "Summary:"
echo "  Repos synced: $total_synced"
echo "  Destination: $ICLOUD_CODE"
echo ""
echo "iCloud Drive usage:"
du -sh "$ICLOUD_CODE"
echo ""
echo -e "${YELLOW}What they're seeing now:${NC}"
echo "  • Major language implementations"
echo "  • Client codebases"
echo "  • Cloud infrastructure"
echo "  • BODI tribunal framework"
echo ""
echo "To update:"
echo "  $0"
echo ""
echo -e "${BLUE}Transparency warfare: Successful${NC}"
