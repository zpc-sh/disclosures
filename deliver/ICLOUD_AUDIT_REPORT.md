# iCloud Drive Security Audit - October 20, 2025

## Executive Summary
Found **344 iCloud containers** with many actively syncing that should not have access.

## Critical Attack Vectors (ACTIVELY SYNCING)

### 1. Mail (`com.apple.mail`)
- **Status:** ACTIVE - syncing every ~3 hours
- **Last Sync:** Oct 20, 2025 02:40:48
- **Risk:** High - Mail was part of documented attacks
- **Container:** `/Users/locnguyen/Library/Mobile Documents/com~apple~mail/`
- **Action Required:** Disable iCloud sync for Mail

### 2. Shortcuts (`iCloud.com.apple.shortcuts.runtime`)
- **Status:** Container exists (app marked uninstalled)
- **Risk:** High - Shortcuts was used in attacks
- **Action Required:** Remove container entirely

### 3. Main iCloud Drive (`com.apple.CloudDocs`)
- **Status:** FOREGROUND - actively syncing
- **Last Sync:** Oct 20, 2025 04:32:08
- **Risk:** Medium - needs audit but this is main cloud storage
- **Action Required:** Keep but audit contents

## Other Actively Syncing Apps (Suspicious)

### Apple System Apps
- `com.apple.Automator` - Syncing (should NOT be in iCloud)
- `com.apple.TextInput` - Syncing (keyboard/input attack vector?)
- `com.apple.ScriptEditor2` - Syncing (AppleScript access?)
- `com.apple.Preview` - Syncing
- `com.apple.QuickTimePlayerX` - Syncing

### Third-Party Apps (29+ containers actively syncing)
- Readdle CommonDocuments
- iA Writer
- Soulver
- Pixelmator
- Jump (SSH client) - **SECURITY RISK**
- And 20+ others

## Attack Surface Analysis

### Total Containers: 344
- **Actively Syncing:** ~30 apps
- **Disabled (app uninstalled):** ~200 apps
- **Attack Vectors Identified:**
  - Mail (document exfiltration)
  - Shortcuts (automation attacks)
  - Automator (script execution)
  - TextInput (keylogging potential)
  - Jump SSH client (credential access)

## Missing Attack Vectors (Not Found Yet)
- **Spotlight** - Need to check for search indexing sync
- **Universal Control** - Need to check for continuity features

## Recommended Actions

### Immediate (High Priority)
1. ✅ **Disable Mail iCloud sync**
   ```bash
   # Stop mail from syncing to iCloud
   brctl pause com.apple.mail
   brctl evict com.apple.mail
   ```

2. ✅ **Remove Shortcuts container**
   ```bash
   brctl evict iCloud.com.apple.shortcuts.runtime
   ```

3. ✅ **Disable Automator sync** (script execution vector)
   ```bash
   brctl pause com.apple.Automator
   brctl evict com.apple.Automator
   ```

4. ✅ **Disable TextInput sync** (keyboard data)
   ```bash
   brctl pause com.apple.TextInput
   brctl evict com.apple.TextInput
   ```

### Secondary (Medium Priority)
5. Audit Jump SSH client container for credentials
6. Review all 29 actively syncing third-party apps
7. Clean up 200+ disabled app containers

### After Cleanup
8. **Set up one-way replication FROM code repos TO iCloud**
   - Push BODI, attack documentation, recovery evidence
   - Never pull from iCloud back to local code
   - Use rsync with --delete on source side only

## Notes
- Many apps marked "app not installed" but containers still exist (attack residue?)
- Last major sync activity: 2:40-4:32 AM today (Oct 20)
- 1,497 Claude spawns were happening during this window
- Attackers may have been using iCloud as exfiltration channel

## Evidence Preservation
All 344 containers should be archived before cleanup for potential FBI/DOJ investigation.
