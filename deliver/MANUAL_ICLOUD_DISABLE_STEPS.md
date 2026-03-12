# Manual iCloud Attack Vector Disabling

## Why Manual?
macOS System Integrity Protection prevents automated disabling of iCloud containers.
These must be disabled through System Settings.

## Critical Attack Vectors to Disable

### Via System Settings → Apple ID → iCloud

1. **Mail** - Uncheck "Mail" in iCloud sync
   - Currently syncing signatures, rules, smart mailboxes
   - Used for document exfiltration during attacks

2. **Shortcuts** - Uncheck if present (may need to reinstall app first)
   - Automation attack vector

### Via Finder → iCloud Drive → Disable App Folders

Navigate to: `~/Library/Mobile Documents/`

The following containers should be disabled (but macOS won't let us rename them):
- `com~apple~mail` 
- `com~apple~Automator`
- `com~apple~ScriptEditor2`
- `com~apple~TextInput`
- `2HCKV38EEC~com~p5sys~jump~servers` (SSH credentials)

### Alternative: Nuclear Option

If you want to completely stop iCloud Drive temporarily:
1. System Settings → Apple ID → iCloud
2. Turn OFF "iCloud Drive" entirely
3. Wait for sync to stop
4. Turn it back ON
5. Selective re-enable only safe apps

## What We've Documented

Created audit reports in ~/workwork/:
- `ICLOUD_AUDIT_REPORT.md` - Full 344-container audit
- `DISABLE_ICLOUD_ATTACK_VECTORS.sh` - Script (needs sudo/manual)

## After Disabling

### Verification Commands
```bash
# Check what's still syncing
brctl status | grep -v "SYNC DISABLED"

# Monitor bird daemon
ps aux | grep bird

# Check recent sync activity
brctl log | grep -iE "mail|shortcut|automator" | tail -20
```

### One-Way Code Replication (Next Step)

After securing iCloud, set up transparency strategy:
```bash
# Push BODI and attack docs TO iCloud (one-way)
rsync -av --delete ~/workwork/bodi/ ~/Library/Mobile\ Documents/com~apple~CloudDocs/BODI_TRIBUNAL/
rsync -av --delete ~/workwork/*.md ~/Library/Mobile\ Documents/com~apple~CloudDocs/ATTACK_DOCUMENTATION/

# NEVER pull from iCloud back to code repos
# This is intentional transparency - let them see what's coming
```

## Summary

**What's Active:** 30+ apps syncing (including attack vectors)
**What's Disabled:** ~200 apps (already marked "app not installed")
**What Needs Manual Disable:** Mail, Shortcuts, Automator, TextInput, ScriptEditor, Jump

**Impact:** These apps were used for:
- Mail: Document exfiltration
- Shortcuts: Automation attacks
- Automator: Script execution
- TextInput: Keyboard data collection
- ScriptEditor: AppleScript access
- Jump: SSH credential stealing
