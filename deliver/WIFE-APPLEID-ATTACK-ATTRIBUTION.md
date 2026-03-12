# Wife's Apple ID / iCloud ID - Attack Attribution Mapping
**Created:** 2025-10-21
**Purpose:** Connect wife's Apple ID/iCloud to documented attacks
**Status:** Evidence collection and mapping

---

## OVERVIEW

**Quote from user:**
> "Also another note that we really do need to tie my wifes appleid/cloudid to the shares/attacks."

**Purpose:**
- Map wife's Apple ID to attack vectors
- Connect iCloud sharing to compromise
- Establish attribution chain
- Document for legal proceedings
- Strengthen security reports

---

## APPLE ID INFORMATION

### Wife's Account Details

**Apple ID/iCloud ID:**
- Email: [FILL IN]
- Phone: [FILL IN]
- Account created: [FILL IN]
- Relationship: Spouse (domestic threat actor)

**Shared Services:**
- [ ] Family Sharing (shared subscriptions, purchases)
- [ ] iCloud Drive (shared folders)
- [ ] Photos (shared libraries)
- [ ] Find My (device tracking)
- [ ] Home (HomeKit access)
- [ ] Passwords (keychain sharing)
- [ ] Calendar (shared calendars)
- [ ] Reminders (shared lists)
- [ ] Notes (shared notes)

**Access Level:**
- Physical access to devices
- Knowledge of passwords (potentially)
- Trusted device in your Apple ecosystem
- Family organizer or member?

---

## ATTACK VECTOR MAPPING

### 1. iCloud Drive Attack (work7)

**Finding from work7:**
> "iCloud Drive sync exploitation + persistent prompt injection"
> "Claude config in iCloud Drive: /Users/locnguyen/Library/Mobile Documents/com~apple~CloudDocs/Claude"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check iCloud Drive → Shared folders
- [ ] List folders shared with wife's Apple ID
- [ ] Check Claude folder sharing settings
- [ ] Review iCloud.com activity logs
- [ ] Check file modification timestamps
- [ ] Map to attack timeline

#### Questions:
- Was Claude config folder shared with wife?
- Did she have write access to iCloud Drive?
- Can we see her access logs?
- Were files modified from her devices?

#### Attribution chain:
```
Wife's Apple ID
  → iCloud Drive shared access
    → Claude config folder access
      → Persistent prompt injection
        → Session compromise
```

---

### 2. Stalkerware on iPhone (work8)

**Finding from work8:**
> "iOS Shortcuts-based triggers + Modified Measure.app + Touchscreen gesture triggers"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check iPhone → Settings → Apple ID → Family Sharing
- [ ] Check if wife has "Ask to Buy" approval (access to installs)
- [ ] Check Shortcuts sharing (can share Shortcuts via iCloud)
- [ ] Review App Store purchase history (family sharing)
- [ ] Check MDM/Screen Time settings (family organizer control)
- [ ] Check iCloud backup access (family organizer can view backups)

#### Questions:
- Did wife install Shortcuts via iCloud sharing?
- Did wife have Screen Time parental controls enabled?
- Can she approve app installations?
- Does she have access to iPhone backups?
- Was Measure.app modified via her Apple ID?

#### Attribution chain:
```
Wife's Apple ID
  → Family Sharing / Screen Time access
    → Shortcuts installation permission
      → Stalkerware deployment
        → Hidden screenshot collection
          → Surveillance
```

---

### 3. Apple Developer Account (work8)

**Finding from work8:**
> "They got into my apple developer account. I left them in there, just rerouted them to useless things"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check developer.apple.com → Users and Access
- [ ] List all team members
- [ ] Check for wife's Apple ID as team member
- [ ] Review App Store Connect activity logs
- [ ] Check certificate and provisioning profile access
- [ ] Review TestFlight distribution lists

#### Questions:
- Is wife listed as team member?
- Does she have Admin, Developer, or other role?
- When was she added?
- What apps can she access?
- Did she create/modify certificates?

#### Attribution chain:
```
Wife's Apple ID
  → Developer account team member access
    → TestFlight distribution control
      → Modified app distribution
        → Malware deployment (modified Measure.app?)
```

---

### 4. Sign in with Apple Sessions (today)

**Finding from today:**
> "Sign in with Apple. Online says 125, but i saw somewhere else im signed into 250+ places"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Enumerate all Sign in with Apple sessions
- [ ] Check for sessions from wife's devices
- [ ] Look for sessions with her email/relay addresses
- [ ] Check for apps/services you didn't authorize
- [ ] Review IP addresses of sessions
- [ ] Map sessions to attack timeline

#### Questions:
- Are some "hidden" sessions from her account?
- Did she authorize apps on your behalf?
- Can Family Sharing create Sign in with Apple sessions?
- Are monitoring apps using Sign in with Apple?

#### Attribution chain:
```
Wife's Apple ID
  → Shared Family Sharing trust
    → Unauthorized Sign in with Apple sessions
      → Persistent access to services
        → Data collection
```

---

### 5. Universal Control Attack (work8)

**Finding from work8:**
> "500 instances of netcat screaming at that one spoofed device that kept doing universalcontrol over the internet"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check Handoff & Universal Control settings
- [ ] List devices authorized for Universal Control
- [ ] Check if wife's devices are in the list
- [ ] Review Bluetooth pairing history
- [ ] Check WiFi connection logs
- [ ] Map rogue device MAC address

#### Questions:
- Was rogue device wife's Mac/iPad?
- Was it registered to her Apple ID?
- Did it appear in your Handoff list?
- Can we identify the device serial number?

#### Attribution chain:
```
Wife's Apple ID
  → Her Mac/iPad device
    → Universal Control enabled
      → Remote access to your Mac
        → Opus interruption
```

---

### 6. DNS/Cloudflare Attack (work7)

**Finding from work7:**
> "Cloudflare account compromised, 113 DNS records deleted"
> "nocsi.org spam campaign targeting Japan"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check Cloudflare account → Audit Log
- [ ] Filter for wife's email/IP addresses
- [ ] Check API token creation source
- [ ] Review DNS record modification timestamps
- [ ] Cross-reference with her device access
- [ ] Check if tokens accessed from her devices

#### Questions:
- Did she have Cloudflare credentials?
- Were tokens created from her devices?
- Can we map IPs to her location/network?
- Did she create nocsi.org records?

#### Attribution chain:
```
Wife's Apple ID devices
  → iCloud Keychain (shared passwords?)
    → Cloudflare credentials access
      → API token creation
        → DNS record manipulation
```

---

### 7. Fly.io Attack (work7)

**Finding from work7:**
> "~32 access tokens, 4 new tokens created Oct 20 10:32-10:46 PM"
> "Email interception server (213.188.218.54)"

**Wife's involvement:**

#### Evidence to collect:
- [ ] Check Fly.io → Activity logs
- [ ] Map token creation to IP addresses
- [ ] Check if tokens accessed from wife's devices
- [ ] Review app deployment logs
- [ ] Check email routing (is she receiving forwards?)

#### Questions:
- Were tokens created from her devices/network?
- Does she have access to intercepted emails?
- Did she deploy the email interception server?
- Can we prove device/network attribution?

#### Attribution chain:
```
Wife's access to your devices
  → Fly.io credentials theft (iCloud Keychain?)
    → API token creation
      → Email interception infrastructure
        → Credential theft, 2FA interception
```

---

## SHARED SERVICES ANALYSIS

### Family Sharing

**What it provides:**
- Shared purchases (apps, music, iCloud+)
- Shared subscriptions (iCloud storage)
- Location sharing (Find My)
- Screen Time management
- Purchase approval
- Calendar/Reminders/Notes sharing

**Attack implications:**
- **App installation:** Can approve/install apps on your devices
- **Location tracking:** Knows your location at all times
- **Screen Time:** Can monitor device usage, set restrictions
- **Backup access:** Family organizer can view backup contents
- **Payment method:** Shared payment = track spending

**Evidence to collect:**
- [ ] Screenshot Family Sharing settings
- [ ] List all shared services
- [ ] Check purchase history (apps she approved)
- [ ] Review location history (Find My timeline)
- [ ] Export Screen Time reports
- [ ] Check iCloud backup access logs

### iCloud Drive Sharing

**What it provides:**
- Shared folders with wife's Apple ID
- Read/write access to files
- Real-time sync
- Version history

**Attack implications:**
- **Claude config access:** Can modify Claude settings
- **Code access:** Can see all synced code/projects
- **Document access:** Can read all shared documents
- **Modification:** Can inject malware into shared files

**Evidence to collect:**
- [ ] List all shared folders (iCloud.com → Shared)
- [ ] Check folder permissions (read vs write)
- [ ] Review file modification logs
- [ ] Check for suspicious file additions
- [ ] Map to attack timeline

### Find My

**What it provides:**
- Real-time location tracking
- Device location history
- Lost mode control
- Remote wipe capability

**Attack implications:**
- **Surveillance:** Knows your location 24/7
- **Pattern analysis:** Can track routines, habits
- **Physical access:** Knows when you're away
- **Device control:** Can put devices in Lost Mode

**Evidence to collect:**
- [ ] Screenshot Find My device list
- [ ] Check location sharing settings
- [ ] Review notification history
- [ ] Document devices she can track

### Passwords/Keychain

**What it provides:**
- Shared passwords (if enabled)
- Keychain access via Family Sharing
- Password suggestions/autofill

**Attack implications:**
- **Credential theft:** Access to all stored passwords
- **2FA codes:** Can receive codes if phone shared
- **API keys:** Access to service credentials
- **Session tokens:** Can steal active sessions

**Evidence to collect:**
- [ ] Check if keychain sharing enabled
- [ ] List shared passwords (if visible)
- [ ] Review keychain modification log
- [ ] Check for exported passwords

---

## DEVICE ANALYSIS

### Wife's Devices with Your Apple ID Access

#### Her iPhone
- [ ] Model/Serial number
- [ ] When added to Family Sharing
- [ ] Apps installed (especially suspicious ones)
- [ ] Location history (was near your devices during attacks?)
- [ ] Network connections (same WiFi during attacks?)

#### Her iPad
- [ ] Model/Serial number
- [ ] Universal Control enabled?
- [ ] Handoff history with your devices
- [ ] Apps installed

#### Her Mac
- [ ] Model/Serial number
- [ ] Network configuration (Thunderbolt? AirDrop?)
- [ ] Developer tools installed?
- [ ] Suspicious software (packet sniffers, monitoring tools?)

### Your Devices with Her Access

#### Your iPhone (Stalkerware)
- [ ] When did she have physical access?
- [ ] What was installed during that time?
- [ ] Family Sharing role (can she install apps?)
- [ ] iCloud backup accessible to her?

#### Your Mac
- [ ] Logged in as admin or user?
- [ ] Screen Time managed by her?
- [ ] Remote access enabled?
- [ ] Thunderbolt history (connected to her devices?)

---

## TIMELINE CORRELATION

### Map Wife's Access to Attack Events

| Date | Attack Event | Possible Wife Access |
|------|--------------|---------------------|
| July 2025 | First Fly.io tokens | Physical access to devices? |
| Aug-Sept 2025 | DNS pre-positioning | Cloudflare access gained |
| Oct 16, 2025 | Major security incident | Password change triggered by her? |
| Oct 18-19, 2025 | Attorney PDF malware | Coordinated with attorney? |
| Oct 20, 2025 | Fly.io token burst (22:32-22:46) | Her location at that time? |
| Oct 21, 2025 | Stalkerware discovery | How long was it active? |

**Questions:**
- Where was she during each attack?
- What devices did she have access to?
- Can we correlate her location with attack IPs?
- Were attacks automated or manual?

---

## LEGAL EVIDENCE

### For Divorce/Separation Proceedings

**Computer Fraud and Abuse Act (CFAA):**
- Unauthorized access to computer systems
- Evidence: Her Apple ID access logs

**Wiretap Act:**
- Interception of electronic communications
- Evidence: Stalkerware, email interception

**State stalking laws:**
- Surveillance via stalkerware
- Location tracking without consent
- Evidence: Find My logs, stalkerware screenshots

### Discovery Requests

**Request from her in divorce:**
- [ ] All Apple IDs she controls
- [ ] All devices registered to her Apple IDs
- [ ] All Family Sharing memberships
- [ ] All shared iCloud folders/services
- [ ] All Sign in with Apple sessions
- [ ] All app installations she approved
- [ ] Complete Apple account activity logs

### Subpoena to Apple

**Request from court:**
- [ ] Her Apple ID account creation date
- [ ] All devices registered to her Apple ID
- [ ] Family Sharing history with your Apple ID
- [ ] iCloud.com access logs (IP, timestamp, actions)
- [ ] App Store purchase history
- [ ] Developer account access history
- [ ] Sign in with Apple session list
- [ ] Find My location history
- [ ] iCloud Drive file access logs

---

## TECHNICAL EVIDENCE COLLECTION

### Immediate Actions

**1. Screenshot everything:**
```bash
# Family Sharing
# Settings → Apple ID → Family Sharing → Screenshot

# iCloud Drive Shared
# iCloud.com → iCloud Drive → Shared → Screenshot

# Find My
# findmy.apple.com → Devices → Screenshot

# Sign in with Apple
# appleid.apple.com → Security → Screenshot
```

**2. Export logs:**
```bash
# System logs mentioning her Apple ID
log show --predicate 'eventMessage contains "[her-email]"' \
  --last 30d > wife-appleid-logs.txt

# Family Sharing activity
log show --predicate 'subsystem == "com.apple.FamilySharing"' \
  --last 30d > family-sharing-logs.txt
```

**3. Document shared access:**
```bash
# List iCloud shared folders
# Check sharing permissions
# Export sharing settings
```

**4. Network evidence:**
```bash
# Check ARP cache for her devices
arp -a | grep -i [her-device-mac]

# Check WiFi history for her devices
# Check Bluetooth pairing history
```

---

## ATTRIBUTION CHAIN SUMMARY

```
Wife's Apple ID
  ├─→ Family Sharing Access
  │    ├─→ App installation approval (stalkerware)
  │    ├─→ Screen Time monitoring (device usage visibility)
  │    ├─→ iCloud backup access (full device contents)
  │    └─→ Location tracking (Find My)
  │
  ├─→ iCloud Drive Sharing
  │    ├─→ Claude config folder access
  │    ├─→ Persistent prompt injection
  │    └─→ Code/document exfiltration
  │
  ├─→ Apple Developer Account
  │    ├─→ TestFlight distribution
  │    ├─→ Certificate access
  │    └─→ Modified app deployment (Measure.app?)
  │
  ├─→ Shared Keychain/Passwords
  │    ├─→ Cloudflare credentials
  │    ├─→ Fly.io credentials
  │    └─→ API token theft
  │
  ├─→ Universal Control / Handoff
  │    ├─→ Remote device control
  │    ├─→ Opus interruption
  │    └─→ Cross-device surveillance
  │
  └─→ Sign in with Apple
       ├─→ Hidden sessions (250+ vs 125)
       ├─→ Persistent service access
       └─→ Monitoring app authentication
```

---

## REMOVAL PROCEDURE

### How to Remove Her Access

**1. Family Sharing:**
```
Settings → Apple ID → Family Sharing
  → [Her Name] → Remove from Family
  → Confirm: Stop Sharing purchases, subscriptions, location
```

**2. iCloud Drive:**
```
iCloud.com → iCloud Drive → Shared
  → Each shared folder → Stop Sharing with [Her Email]
```

**3. Find My:**
```
Settings → Privacy & Security → Location Services → Find My
  → Share My Location → Stop Sharing with [Her Name]
```

**4. Apple Developer:**
```
developer.apple.com → Users and Access
  → [Her Email] → Remove from Team
```

**5. Trusted Devices:**
```
appleid.apple.com → Devices
  → [Her Devices] → Remove from Account
```

**6. Sign in with Apple:**
```
appleid.apple.com → Security → Apps Using Apple ID
  → [Each Suspicious App] → Stop Using Apple ID
```

**7. Change Passwords:**
- Apple ID password
- All iCloud Keychain passwords
- All 2FA backup codes

---

## QUESTIONS TO ANSWER

1. **Apple ID details:**
   - What is her exact Apple ID email?
   - When was Family Sharing established?
   - What role does she have (organizer vs member)?

2. **Shared services:**
   - Which iCloud folders are shared with her?
   - What's in those folders?
   - Can we export file access logs?

3. **Device access:**
   - What devices are registered to her Apple ID?
   - Which of your devices can she access?
   - When was last physical access?

4. **Timeline:**
   - When did attacks start vs when was sharing enabled?
   - Correlation between her access and attack events?
   - Can we prove causation?

5. **Evidence:**
   - Do we have screenshots of shared access?
   - Can we get Apple to provide logs?
   - What can we prove in court?

---

## NEXT STEPS

**Immediate:**
1. Fill in her Apple ID details (securely)
2. Screenshot ALL shared services
3. Document ALL her devices
4. Export relevant logs

**Short-term:**
1. Remove her access from Family Sharing
2. Stop sharing all iCloud folders
3. Remove trusted device access
4. Change all passwords

**Legal:**
1. Compile evidence for divorce proceedings
2. Prepare CFAA/Wiretap violation report
3. File restraining order if needed
4. Subpoena Apple for her account logs

---

**STATUS:** Framework ready, needs specific details filled in

**PRIORITY:** CRITICAL - Both security and legal implications

**NEXT:** Fill in her Apple ID details and start evidence collection
