#!/bin/bash
# Metadata Stripping Tool for Recovered Files
# Strips CloudKit provenance, extended attributes, and other tracking metadata

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STRIP_XATTR=true
STRIP_DSSTORE=true
FIX_OWNERSHIP=false
DRY_RUN=false
TARGET_USER=""
TARGET_GROUP=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <path>

Strip CloudKit provenance and metadata from files.

OPTIONS:
    -n, --dry-run          Show what would be done without making changes
    -x, --no-xattr         Skip stripping extended attributes
    -d, --no-dsstore       Keep .DS_Store files
    -o, --fix-ownership    Fix ownership (requires -u and -g)
    -u, --user USER        Target user for ownership fix
    -g, --group GROUP      Target group for ownership fix
    -h, --help             Show this help message

EXAMPLES:
    # Dry run to see what would be stripped
    $0 --dry-run /path/to/files

    # Strip metadata from directory
    $0 /path/to/files

    # Strip and fix ownership
    $0 --fix-ownership --user locnguyen --group staff /path/to/files

METADATA STRIPPED:
    - com.apple.metadata:*               (Spotlight metadata)
    - com.apple.provenance               (File provenance)
    - com.apple.quarantine               (Quarantine flags)
    - com.apple.lastuseddate#PS          (Usage tracking)
    - com.apple.FinderInfo               (Finder metadata)
    - com.apple.ResourceFork             (Resource forks)
    - kMDItemWhereFroms                  (Download source)
    - All CloudKit sync attributes
    - .DS_Store files (optional)

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -x|--no-xattr)
            STRIP_XATTR=false
            shift
            ;;
        -d|--no-dsstore)
            STRIP_DSSTORE=false
            shift
            ;;
        -o|--fix-ownership)
            FIX_OWNERSHIP=true
            shift
            ;;
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        -g|--group)
            TARGET_GROUP="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$TARGET_PATH" ]]; then
                TARGET_PATH="$1"
            else
                echo -e "${RED}Error: Unknown option or multiple paths specified${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: No path specified${NC}"
    usage
fi

if [[ ! -e "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: Path does not exist: $TARGET_PATH${NC}"
    exit 1
fi

if [[ "$FIX_OWNERSHIP" == true ]]; then
    if [[ -z "$TARGET_USER" ]] || [[ -z "$TARGET_GROUP" ]]; then
        echo -e "${RED}Error: --fix-ownership requires --user and --group${NC}"
        exit 1
    fi
    # Verify user and group exist
    if ! id "$TARGET_USER" &>/dev/null; then
        echo -e "${RED}Error: User '$TARGET_USER' does not exist${NC}"
        exit 1
    fi
    if ! dscl . -read /Groups/"$TARGET_GROUP" &>/dev/null; then
        echo -e "${RED}Error: Group '$TARGET_GROUP' does not exist${NC}"
        exit 1
    fi
fi

# Statistics
total_files=0
xattr_stripped=0
dsstore_removed=0
ownership_fixed=0

# Function to strip extended attributes
strip_xattrs() {
    local file="$1"

    # Get all extended attributes
    local attrs=$(xattr "$file" 2>/dev/null || true)

    if [[ -z "$attrs" ]]; then
        return
    fi

    # Count attributes to strip
    local count=0
    while IFS= read -r attr; do
        # Strip CloudKit, metadata, provenance, and tracking attributes
        if [[ "$attr" =~ ^com\.apple\.(metadata|provenance|quarantine|lastuseddate|FinderInfo|ResourceFork) ]] || \
           [[ "$attr" =~ ^kMDItem ]] || \
           [[ "$attr" =~ cloudkit ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "  Would remove xattr: $attr"
            else
                xattr -d "$attr" "$file" 2>/dev/null || true
            fi
            ((count++))
        fi
    done <<< "$attrs"

    if [[ $count -gt 0 ]]; then
        ((xattr_stripped++))
        if [[ "$DRY_RUN" == false ]]; then
            echo -e "${GREEN}✓${NC} Stripped $count attributes from: $file"
        fi
    fi
}

# Function to remove .DS_Store files
remove_dsstore() {
    local file="$1"

    if [[ "$(basename "$file")" == ".DS_Store" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would remove: $file"
        else
            rm -f "$file"
            echo -e "${GREEN}✓${NC} Removed: $file"
        fi
        ((dsstore_removed++))
    fi
}

# Function to fix ownership
fix_ownership() {
    local file="$1"
    local current_owner=$(stat -f "%u:%g" "$file")

    # Check if owned by uid/gid 99 (_unknown)
    if [[ "$current_owner" == "99:99" ]] || [[ "$current_owner" == *":99" ]] || [[ "$current_owner" == "99:"* ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would chown to $TARGET_USER:$TARGET_GROUP: $file"
        else
            chown "$TARGET_USER:$TARGET_GROUP" "$file" 2>/dev/null || {
                echo -e "${YELLOW}⚠${NC}  Need sudo for: $file"
                return 1
            }
            echo -e "${GREEN}✓${NC} Fixed ownership: $file"
        fi
        ((ownership_fixed++))
    fi
}

# Main processing
echo -e "${YELLOW}=== Metadata Stripping Tool ===${NC}"
echo "Target: $TARGET_PATH"
echo "Dry run: $DRY_RUN"
echo "Strip xattr: $STRIP_XATTR"
echo "Remove .DS_Store: $STRIP_DSSTORE"
echo "Fix ownership: $FIX_OWNERSHIP"
[[ -n "$TARGET_USER" ]] && echo "Target user: $TARGET_USER:$TARGET_GROUP"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

# Process files
if [[ -f "$TARGET_PATH" ]]; then
    # Single file
    total_files=1
    [[ "$STRIP_XATTR" == true ]] && strip_xattrs "$TARGET_PATH"
    [[ "$STRIP_DSSTORE" == true ]] && remove_dsstore "$TARGET_PATH"
    [[ "$FIX_OWNERSHIP" == true ]] && fix_ownership "$TARGET_PATH"
else
    # Directory - process recursively
    echo "Scanning directory..."

    while IFS= read -r -d '' file; do
        ((total_files++))

        # Show progress every 100 files
        if ((total_files % 100 == 0)); then
            echo -e "${YELLOW}Processed $total_files files...${NC}"
        fi

        [[ "$STRIP_XATTR" == true ]] && strip_xattrs "$file"
        [[ "$STRIP_DSSTORE" == true ]] && remove_dsstore "$file"
        [[ "$FIX_OWNERSHIP" == true ]] && fix_ownership "$file"

    done < <(find "$TARGET_PATH" -type f -print0 2>/dev/null)
fi

# Summary
echo ""
echo -e "${GREEN}=== Summary ===${NC}"
echo "Total files processed: $total_files"
[[ "$STRIP_XATTR" == true ]] && echo "Files with xattrs stripped: $xattr_stripped"
[[ "$STRIP_DSSTORE" == true ]] && echo ".DS_Store files removed: $dsstore_removed"
[[ "$FIX_OWNERSHIP" == true ]] && echo "Ownership fixed: $ownership_fixed"

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "${YELLOW}This was a dry run. Run without --dry-run to apply changes.${NC}"
fi
