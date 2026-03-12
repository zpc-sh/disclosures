# Anthropic Claude: smol-bin.img Investigation

**Date:** February 3, 2026
**Status:** INVESTIGATION IN PROGRESS
**Severity:** TBD (Potentially HIGH)

---

## Discovery

Found in Claude Desktop logs:

```
[VM] 2026-02-03 08:23:00 [info] Found smol-bin.img at /Applications/Claude.app/Contents/Resources/smol-bin.img
[VM] 2026-02-03 08:23:00 [info] Added smol-bin.img as USB mass storage device
```

### Key Concerns:

1. **USB Mass Storage Image** - Why does Claude ship with this?
2. **MBR Format** - Why this ancient format? (Security? Compatibility?)
3. **RSA Private Keys** - Whose keys? Why in production app?
4. **mitmproxy** - Man-in-the-middle proxy capabilities included

---

## Questions To Answer

### 1. What is smol-bin.img?
- [ ] Extract and examine the image file
- [ ] Mount it and inspect contents
- [ ] Check file signatures and hashes
- [ ] Determine purpose

### 2. Whose RSA Keys?
- [ ] Are these Anthropic's keys?
- [ ] User's keys?
- [ ] Development/test keys accidentally shipped?
- [ ] Backdoor keys?

### 3. Why mitmproxy?
- [ ] Debugging tool?
- [ ] Traffic inspection?
- [ ] SSL/TLS interception?
- [ ] Monitoring infrastructure?

### 4. Is This Normal?
- [ ] Check other users' Claude Desktop installations
- [ ] Compare across versions
- [ ] Check if documented anywhere

---

## Investigation Steps

### Step 1: Locate and Extract

```bash
# Find the file
ls -lh "/Applications/Claude.app/Contents/Resources/smol-bin.img"

# Get file info
file smol-bin.img

# Check size
du -h smol-bin.img

# Hash it
shasum -a 256 smol-bin.img
```

### Step 2: Mount and Inspect

```bash
# Mount as USB mass storage (if safe)
# DO NOT EXECUTE without verification
hdiutil attach smol-bin.img -readonly

# Or extract without mounting
7z x smol-bin.img -o./smol-bin-contents/
```

### Step 3: Search for Keys

```bash
# Search for RSA key headers
grep -r "BEGIN RSA" ./smol-bin-contents/
grep -r "PRIVATE KEY" ./smol-bin-contents/

# Find mitmproxy
find ./smol-bin-contents/ -name "*mitm*"
find ./smol-bin-contents/ -name "*proxy*"
```

### Step 4: Analyze Binaries

```bash
# List all executables
find ./smol-bin-contents/ -type f -perm +111

# Check what they do
strings suspicious_binary | less

# Run checksums
shasum -a 256 ./smol-bin-contents/**/*
```

---

## Potential Scenarios

### Scenario A: Development Tools (Benign)
- Left in by mistake
- Used for debugging/testing
- Should be removed from production
- **Action:** Report as security hygiene issue

### Scenario B: Monitoring Infrastructure (Concerning)
- Intentional traffic inspection
- SSL/TLS interception via MITM
- Key material for decryption
- **Action:** Demand transparency

### Scenario C: Backdoor/Compromise (Severe)
- Unauthorized keys planted
- Persistent MITM capability
- Could be nation-state or insider
- **Action:** Immediate disclosure + investigation

### Scenario D: VM Tooling (Neutral)
- Required for VM functionality
- Keys are for VM-to-host communication
- mitmproxy for controlled environment
- **Action:** Ask Anthropic to document

---

## Related Findings

### 1. ANTHROPIC_CUSTOM_HEADERS

```
Creating client, ANTHROPIC_CUSTOM_HEADERS present: false
```

Checked every API request (~20 seconds or per request):
- What does this env var do when set?
- Is it a backdoor/override mechanism?
- Testing for specific conditions?

### 2. Network Allowlist Blocking

```
Connection blocked by network allowlist (code: 403)
```

All MCP servers blocked:
- Slack, Atlassian, MS365, Linear, Asana, Notion
- Is this related to smol-bin?
- Locked-down environment?
- Account-specific restriction?

### 3. Skills Loading Failures

```
Error: ENOENT: no such file or directory, scandir '/etc/claude-code/.claude/skills'
Error: ENOENT: no such file or directory, scandir '/sessions/stoic-zen-heisenberg/mnt/.claude/skills'
```

- Expected directories don't exist
- Skills system not functioning
- Related to account tampering?

---

## Hypotheses

### Hypothesis 1: Operation Bloodclot Aftermath
User's account flagged after nation-state attack:
- Enhanced monitoring enabled (smol-bin)
- Network restricted (allowlist)
- Skills disabled (safety measure)

### Hypothesis 2: Normal Claude Desktop Architecture
This is standard for all users:
- VM requires these tools
- MITM for controlled environment
- Keys are for sandboxing

### Hypothesis 3: Development Build Accidentally Shipped
Debug/dev tooling left in:
- Should be stripped from production
- Keys are test keys
- mitmproxy for development debugging

---

## Security Implications

### If Intentional (Monitoring):
- Users should be informed
- Consent required
- Privacy implications
- Terms of Service clarity needed

### If Unintentional (Dev Tools):
- Remove from production builds
- Rotate any exposed keys
- Security audit of build process
- Check other shipped tools

### If Malicious (Compromise):
- Investigate source
- Check signing certificates
- Compare with official Anthropic builds
- Report to security researchers

---

## Immediate Actions

### For User (Loc):
1. **Do NOT delete files yet** - preserve evidence
2. **Document everything** - screenshots, hashes
3. **Export logs** - all VM logs, connection logs
4. **Compare installations** - check another Mac if available
5. **Check network traffic** - is anything being MITMed?

### For Anthropic:
1. **Explain smol-bin.img** - What is it? Why shipped?
2. **Clarify RSA keys** - Whose keys? Purpose?
3. **Document mitmproxy** - Why included? What does it do?
4. **Network allowlist** - Is this account-specific?
5. **ANTHROPIC_CUSTOM_HEADERS** - What is this for?

---

## Questions for Anthropic

1. **smol-bin.img:**
   - What is the purpose of this USB mass storage image?
   - Why is it in MBR format?
   - What files/tools are contained in it?

2. **RSA Private Keys:**
   - Whose keys are in smol-bin.img?
   - Why are private keys shipped with the application?
   - Are they test keys or production keys?

3. **mitmproxy:**
   - Why does Claude Desktop include a MITM proxy?
   - Is traffic being intercepted/inspected?
   - Is user consent obtained?

4. **ANTHROPIC_CUSTOM_HEADERS:**
   - What does this environment variable control?
   - Why is it checked on every API request?
   - Is this documented anywhere?

5. **Network Allowlist:**
   - Why are MCP connections blocked?
   - Is this account-specific or global?
   - Related to Operation Bloodclot investigation?

---

## Next Steps

### Investigation Priority:
1. **HIGH:** Extract and analyze smol-bin.img contents
2. **HIGH:** Identify whose RSA keys are included
3. **HIGH:** Determine mitmproxy configuration/usage
4. **MEDIUM:** Test ANTHROPIC_CUSTOM_HEADERS behavior
5. **MEDIUM:** Compare with clean Claude Desktop install

### Disclosure Decision Tree:

```
Is smol-bin malicious?
├─ YES → Immediate critical disclosure
├─ UNKNOWN → Continue investigation, partial disclosure
└─ NO → Is it properly documented?
    ├─ YES → No disclosure needed
    └─ NO → Transparency disclosure (user awareness)
```

---

## Evidence Needed

- [ ] File hash of smol-bin.img
- [ ] Contents of smol-bin.img
- [ ] RSA key fingerprints
- [ ] mitmproxy configuration files
- [ ] Network traffic captures
- [ ] Comparison with other installations
- [ ] Official Anthropic documentation (if exists)

---

## Preliminary Assessment

**Concern Level:** 🟡 MEDIUM-HIGH (pending investigation)

**Reasons for Concern:**
- Unexplained RSA keys in production app
- MITM proxy capabilities
- MBR disk image (unusual choice)
- Not documented publicly
- Combined with network restrictions

**Reasons for Caution:**
- Might be legitimate VM tooling
- Could be debugging infrastructure
- May be standard across all users
- Need more data before conclusions

---

## Timeline

- **Feb 3, 2026** - Discovery in logs
- **Feb 3, 2026** - Initial investigation started
- **[TBD]** - smol-bin.img extracted and analyzed
- **[TBD]** - Decision on disclosure severity
- **[TBD]** - Contact Anthropic or proceed with disclosure

---

## Status: INVESTIGATING

Do not jump to conclusions. Gather evidence first.

But do treat this seriously - RSA keys + MITM proxy in a production app is unusual enough to warrant investigation.

∴ 🔍🔑🕵️

---

**Investigator:** Loc Nguyen (ZPC)
**Assistance:** Claude (me, investigating my own infrastructure 😅)

