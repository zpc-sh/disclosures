# iCloud Drive Sharing Audit
## Investigation: Shared Apple ID Access Vectors

**Date:** October 20, 2025
**Purpose:** Identify all shared folders/files that could provide persistent access

---

## Summary

**Shared folders found:** 1
**Total folders scanned:** 75+
**Potential persistence vector:** Downloads folder

---

## Shared Items Discovered

### 1. Downloads Folder

**Path:** `~/Library/Mobile Documents/com~apple~CloudDocs/Downloads`

**Sharing Status:** SHARED (Owner)
- `kMDItemIsShared`: TRUE
- `kMDItemSharedItemCurrentUserRole`: Owner
- `kMDItemCollaborationIdentifier`: com.apple.CloudDocs_54EED11A-7E2B-46E6-B24E-FD45B745E9B7

**Analysis:**
- You are marked as OWNER of this share
- Folder has collaboration identifier (active sharing enabled)
- **Participants unknown** (not visible in xattr metadata)
- Last modified: Oct 20 04:58 (recent activity)

**Concern Level:** 🔴 HIGH
- If wife has participant access to this folder, she can:
  - Read all files placed in Downloads
  - Write files to Downloads (potential malware delivery)
  - Monitor file activity
  - Maintain persistent access even after device removal

**Contents:**
```
ls -la Downloads:
total 24
drwx------@   3 locnguyen  staff    96B Oct 20 04:58 .
drwx------   75 locnguyen  staff   2.3K Oct 20 05:00 ..
-rw-r--r--@  1 locnguyen  staff   8.0K Oct 20 05:02 .DS_Store
```

Empty except for .DS_Store (recently modified)

---

## Sharing Mechanism Analysis

### How iCloud Drive Sharing Works

1. **Owner creates share** - Generates collaboration identifier
2. **Invites participants** - By Apple ID email
3. **Participants accept** - Get persistent access
4. **Access persists** even if:
   - Owner's device list changes
   - Owner changes password (unless explicitly removed from share)
   - Owner doesn't see participants in device list

### Why This Is Dangerous

**Hidden device + Shared folder = Perfect persistence:**
- Hidden device: Not visible in appleid.apple.com devices
- Shared folder: Not visible in Settings → iCloud until you check specific folders
- Combined: Wife has access that survives password changes

### How to Check Participants (macOS)

**Method 1: Finder (GUI)**
```
1. Open Finder
2. Navigate to iCloud Drive → Downloads
3. Right-click → Get Info
4. Look for "Shared" section
5. Check "People" list
```

**Method 2: System Settings**
```
1. System Settings → Apple ID → iCloud → iCloud Drive → Options
2. Check "Shared" folders
3. Each shared folder shows participants
```

**Method 3: sharingd logs**
```bash
log show --predicate 'subsystem == "com.apple.sharingd"' --last 1h | grep -i "participant\|share"
```

---

## Other Suspicious Findings

### SharedResources Folder
**Path:** `~/Library/Mobile Documents/com~apple~CloudDocs/SharedResources`
**Status:** NOT SHARED (confirmed your honeypot)
**Contents:** 20 fake .dat files (230 bytes each)
**Purpose:** Defensive - waste attacker time
**Verdict:** ✅ Safe (your creation)

### Battlefield Folders
Multiple folders created Oct 17 during defensive operations:
- FOR_MY_SCARY_WIFE
- FOR_MY_WIFE_FLOWER_FIELD
- EVIDENCE_BOUQUET_FOR_LIONESS
- NGAN
- HEART, LOVE, TALK_TO_ME, UNDRESSED

**Status:** None have sharing metadata
**Purpose:** Psychological warfare / honeypots
**Verdict:** ✅ Safe (your creations)

---

## Attack Vector Assessment

### Current Access Methods (Ranked by Severity)

1. **🔴 CRITICAL: Hidden Device Registration**
   - Device registered to locvnguy@me.com
   - Not visible in normal UI
   - Full account access
   - **Fix:** Change password + force sign-out

2. **🟠 HIGH: Shared Folders (Downloads)**
   - If wife is participant, access persists
   - **Fix:** Remove participants, disable sharing

3. **🟡 MEDIUM: Family Sharing (Disabled?)**
   - Config shows Family service data
   - UI shows "OFF"
   - May be stale or recently disabled
   - **Fix:** Verify fully removed

4. **🟢 LOW: System Settings Extensions**
   - Directory traversal to iPhone settings
   - **Fix:** Quarantine script ready (block-settings-cloudkit.sh)

---

## Recommended Actions

### Immediate (Today)

1. **Check Downloads folder participants:**
   ```
   - Open Finder → iCloud Drive → Downloads
   - Right-click → Get Info
   - Check "People" section
   - Document all participants (screenshot)
   - Remove any participant not you
   ```

2. **Audit ALL shared folders:**
   ```bash
   # Run this to find any we missed
   find "/Users/locnguyen/Library/Mobile Documents/com~apple~CloudDocs" \
     -type d -maxdepth 1 -exec sh -c \
     'xattr -l "$1" 2>/dev/null | grep -q "kMDItemIsShared" && echo "$1"' _ {} \;
   ```

3. **Change Apple ID password (nuclear option):**
   - Forces sign-out on hidden device
   - **BUT:** Does NOT remove folder share participants
   - Must also remove participants manually

### Short Term (This Week)

1. **Disable all folder sharing:**
   - Remove participants from Downloads
   - Verify no other shared folders exist
   - Disable iCloud Drive sharing capability in Settings

2. **Monitor for re-sharing attempts:**
   ```bash
   # Watch for new sharing metadata
   fswatch -0 ~/Library/Mobile\ Documents/com~apple~CloudDocs/ | \
     xargs -0 -I {} sh -c 'xattr -l "{}" 2>/dev/null | grep -q "kMDItemIsShared" && echo "SHARING DETECTED: {}"'
   ```

3. **Check Family Sharing status:**
   - System Settings → Family
   - Verify completely removed
   - Check MobileMeAccounts.plist for stale config

### Long Term (This Month)

1. **Consider disabling iCloud Drive sharing entirely:**
   - Prevents future folder share attacks
   - You can still use iCloud Drive, just can't share folders

2. **Enable Advanced Data Protection:**
   - End-to-end encryption for iCloud data
   - Prevents Apple from accessing data
   - May break some sharing features (acceptable trade-off)

---

## Technical Details

### Sharing Metadata Attributes

**kMDItemIsShared:**
- Value: Boolean (0 or 1)
- Indicates folder/file is shared with others

**kMDItemSharedItemCurrentUserRole:**
- Values: Owner, Participant
- Shows your role in the share

**kMDItemCollaborationIdentifier:**
- UUID identifying the share
- Format: `com.apple.CloudDocs_<UUID>`
- Used to track participants across devices

**kMDItemSharedItemCurrentUserPermissions:**
- Values: Read-Only, Read-Write
- Shows permission level

### Participant Storage

Participant information is NOT stored in xattrs. Instead:
1. **CloudKit database** - iCloud servers store participant list
2. **bird daemon cache** - Local cache in `~/Library/Application Support/CloudDocs/`
3. **Sharing preferences** - System-level preferences (SIP protected)

**We cannot directly read participant lists without:**
- Using Finder GUI (right-click → Get Info)
- Using System Settings
- Parsing protected CloudKit databases (requires sudo/SIP disable)

---

## Evidence for Federal Case

### New Evidence Category: Folder Sharing Abuse

**If Downloads has wife as participant:**

**18 U.S.C. § 1030(a)(2)(C)** - Unauthorized Access
- Participant access granted without your knowledge
- Access to files you place in Downloads
- Continued access after separation

**18 U.S.C. § 2701** - Stored Communications Act
- Unauthorized access to stored files
- Reading files in shared folder without authorization

**California Penal Code § 502(c)(2)**
- Unauthorized access to computer services
- Using shared folder access maliciously

**Add to evidence package:**
1. Screenshot of Downloads "Get Info" showing participants
2. Timestamp when participant was added (if visible)
3. Correlation with attack timeline

---

## Commands Reference

### Find all shared items
```bash
mdfind -onlyin "$HOME/Library/Mobile Documents/com~apple~CloudDocs" "kMDItemIsShared == 1"
```

### Check specific folder sharing
```bash
xattr -l "/Users/locnguyen/Library/Mobile Documents/com~apple~CloudDocs/Downloads" | grep -i share
```

### Monitor for new shares
```bash
fswatch ~/Library/Mobile\ Documents/com~apple~CloudDocs/ | \
  while read path; do
    xattr -l "$path" 2>/dev/null | grep -q "kMDItemIsShared" && \
      echo "$(date): Sharing detected on $path"
  done
```

### List all Finder tags (shared items often tagged)
```bash
cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
find . -exec xattr -l {} \; 2>/dev/null | grep "kMDItemUserTags" -A 1
```

---

## Next Steps

1. ✅ Audit completed - 1 shared folder found (Downloads)
2. ⬜ Check Downloads folder participants via Finder GUI
3. ⬜ Remove unauthorized participants if found
4. ⬜ Disable folder sharing capability
5. ⬜ Change Apple ID password (after removing participants)
6. ⬜ Monitor for re-sharing attempts

---

**CRITICAL:** Folder sharing can provide persistent access even after:
- Changing Apple ID password
- Removing devices from account
- Disabling Family Sharing

**You MUST manually remove participants from each shared folder.**

---

**Prepared:** October 20, 2025, 05:15 AM PST
**Investigation Status:** Ongoing - awaiting GUI verification of Downloads participants
**Evidence Status:** Ready to add to federal case if participants found
