# Investigation & Tools Index
**Last Updated:** 2025-10-21
**Status:** 20 days of systematic attacks - organizing findings

---

## QUICK START

### Active Tools (Working Right Now)
- **`repo-snap`** - ~/bin/repo-snap - Automatic repo snapshots with iCloud sync
- **`maw`** - ~/code/maw - New project (today)
- **`embark`** - ~/code/embark - Infra-as-folders DSL (today)

### Critical Evidence Locations
- **work7/** - Fly.io DNS attack (Oct 20)
- **work8/** - Stalkerware discovery + attorney malware (Oct 21)
- **~/workwork/** - Root of all investigation files

---

## TOOLS BUILT

### repo-snap (Oct 21 - WORKING)
**Location:** `~/bin/repo-snap`
**Docs:** `work8/REPO-SNAP-GUIDE.md`

**What it does:**
- Monitors ~/code for active repos
- Creates hourly repomix snapshots
- Syncs to iCloud Drive (or local)
- Automatic cleanup (24h retention)

**Commands:**
```bash
repo-snap status                    # Show active repos
repo-snap snap maw                  # Force snapshot of maw
repo-snap snapshot                  # Create due snapshots
```

**Automation:**
```bash
launchctl load ~/Library/LaunchAgents/com.locn.repo-snap.plist
```

**Why it works:** Simple, self-contained, no complex dependencies

---

## WORK DIRECTORIES

### work8/ (Oct 21 - TODAY)
**Status:** Active investigation

**Files:**
- `STALKERWARE-DISCOVERY.md` - iOS device compromise (spouse)
  - Modified Measure.app
  - iOS Shortcuts triggers
  - Touchscreen gesture activation
  - Hidden screenshot collection

- `ATTORNEY-MISCONDUCT.md` - Bar complaint prep
  - PDF malware from attorney
  - Metadata logic bomb
  - Claude session corruption

- `REPO-SNAP-GUIDE.md` - repo-snap documentation
- `RREPO-INTEGRATION.md` - Future: integrate with rrepo tiered storage
- `TIERED-REPO-WATCHER.md` - Architecture design

**Key Findings:**
- Stalkerware on iPhone (domestic threat)
- Attorney sent malware via PDF
- 500 netcat instances used to counter rogue Universal Control device
- Apple rumored to enable streaming over AirDrop

### work7/ (Oct 20)
**Status:** Completed - DNS attack cleaned up

**Files:**
- `SECURITY-INCIDENT-REPORT.md` - Full incident timeline
- `DNS-INTERCEPTION-ANALYSIS.md` - Domain hijacking analysis
- `DEFENSE-STATUS.md` - Data flooding defense
- `CLEANUP-PLAN.md` - Remediation steps
- `IP-ANALYSIS-FLYIO.md` - Attacker infrastructure
- `cloudflare-audit-analysis.md` - Account compromise
- `zpc-sh-email-setup-complete.md` - Email migration

**Key Findings:**
- Fly.io account compromised
- DNS records pre-positioned on 51 domains
- Email interception server (213.188.218.54)
- 113 DNS records deleted
- Data flooding defense (15,000 fake files)
- iCloud Drive was attack vector

**Actions Taken:**
- ✅ Flushed 51 zones (113 DNS records)
- ✅ Documented 4 attacker IPs
- ✅ Launched data flooding (poison exfiltration)
- ✅ Preserved forensic evidence
- ⏳ Manual Fly.io cleanup needed

### work5/ (Earlier)
**Status:** Historical - Thunderbolt networking

**Context:** Built Thunderbolt replication system

### work6/
**Status:** Unknown - need to check

---

## ROOT INVESTIGATIONS (~/workwork/)

### Attack Vectors Documented
- `APFS-LOGIC-BOMB-VULNERABILITY-COMPLETE.md` - Filesystem bombs
- `AIRPLAY-DISPLAY-SPYING-VECTOR.md` - AirPlay monitoring
- `APPLE-PASSKEY-DUPLICATION-ATTACK.md` - Passkey compromise
- `DIRECTORY_TRAVERSAL_ATTACK_VECTOR.md` - Path traversal
- `SPOTLIGHT-WEAPONIZATION-RESEARCH.md` - Spotlight abuse
- `COMMAND-INJECTION-EVIDENCE.md` - Injection attacks

### Network Infrastructure
- `NETWORK-SUPPLANT-PLAN.md` - Network takeover strategy
- `PERMANENT-THUNDERBOLT-SETUP.md` - Thunderbolt networking
- `build-complete-network.sh` - Network build automation
- `udm-pro-max-security-config.md` - UDM Pro hardening

### Ubiquiti/UniFi
- `UBIQUITI-IDENTITY-VULNERABILITY.md` - Device adoption attacks
- `UNIFI-ACCOUNT-TAKEOVER-EVIDENCE.md` - Account compromise
- `UNIFI-ACCOUNT-TAKEOVER-RESPONSE.md` - Response plan
- `device-adoption-security-protocol.md` - Hardening guide

### Evidence Collection
- `FEDERAL_CASE_EVIDENCE_PACKAGE.md` - Legal evidence prep
- `FORENSIC_ARTIFACTS.md` - Artifact documentation
- `EVIDENCE-claude-desktop-unauthorized-access.md` - Claude compromise
- `evidence/` - Evidence directory
- `HIDDEN_DEVICE_EVIDENCE/` - Hidden device findings

### Legal/Reporting
- `FBI-LAB-WARNING.md` - FBI lab concerns
- `FBI-PHONE-SCRIPT-COINTEL-VERSION.md` - Phone script
- `FIRE-MARSHAL-COMPLAINT-ABOUND-VISITATION.md` - Fire marshal issue
- `SOCIAL-MEDIA-BLAST-STRATEGY.md` - Public disclosure plan

### Malware Analysis
- `MALWARE-PARSER-BUG-ANALYSIS.md` - Parser exploitation
- `ADVERSARY-PARSER-BUG-ANALYSIS.md` - Adversary techniques
- `PARSER-BREAKERS-DEPLOYED.md` - Countermeasures
- `ROGUE_CLAUDE_API_ANALYSIS.md` - Claude API compromise

### iCloud Attacks
- `ICLOUD_AUDIT_REPORT.md` - iCloud compromise analysis
- `ICLOUD_SHARING_AUDIT.md` - Sharing abuse
- `ICLOUD_SHARING_FINDINGS.md` - Findings report
- `DISABLE_ICLOUD_ATTACK_VECTORS.sh` - Hardening script

### Operations
- `SEMANTIC-CRYSTALS-OPERATION.md` - Crystal-based tools
- `LAZINESS-AS-DEFENSE.md` - Complexity as defense
- `GEMINI_HARBOR_STRATEGY.md` - Gemini containment
- `MCP-PORT-COLLISION-DEFENSE.md` - Port conflict defense

### Attribution & Analysis
- `ATTRIBUTION_ANALYSIS.md` - Threat actor profiling
- `OSINT-TRAVIS-MOELLER-MARIE-HAMILTON.md` - Person investigation
- `PERSONA_INVESTIGATION.md` - Persona analysis
- `ENVIRONMENT-DETECTION-ANALYSIS.md` - Detection analysis

---

## SCRIPTS & TOOLS

### Active Defense
- `deploy-parser-breakers.sh` - Deploy parser exploits
- `monitor-attack-simple.sh` - Attack monitoring
- `capture-attack-evidence.sh` - Evidence collection
- `detect-spotlight-bombs.sh` - Spotlight bomb detection
- `block-settings-cloudkit.sh` - Block CloudKit settings

### Network Setup
- `nas-thunderbolt-netplan.yaml` - NAS Thunderbolt config
- `nas-nfs-quick.sh` - Quick NFS setup
- `permanent-thunderbolt-setup.sh` - Thunderbolt networking
- `udm-api-setup-script.sh` - UDM API config

### Evidence Management
- `backup-identity-evidence.sh` - Backup identity data
- `replicate-evidence-everywhere.sh` - Replicate evidence
- `strip-metadata.sh` - Strip metadata
- `sync-big-repos-to-icloud.sh` - Large repo sync

### Analysis Tools
- `parse-cache-data.py` - Parse cache files
- `parse-claude-cache.py` - Parse Claude cache
- `filesystem-bomb-detector.py` - Detect filesystem bombs
- `apfs-analyzer/` - APFS analysis tool

---

## ATTACK TIMELINE

### July 2025
- First suspicious Fly.io tokens created
- Attacker establishing persistence

### August-September 2025
- More attacker tokens
- DNS pre-positioning

### October 16, 2025
- Major security incident
- Lost password flow triggered (05:20 UTC)
- 17 Cloudflare API tokens revoked (18 minutes)
- 2FA reset
- Email migration from Fastmail

### October 20, 2025
- 22:32-22:46: Attacker creates 4 new Fly.io tokens
- 16:45: DNS flush executed (113 records deleted)
- 17:00: Data flooding defense activated
- Discovery of email spam campaign via nocsi.org
- Apple Developer account compromise confirmed

### October 21, 2025 (TODAY)
- Discovered iPhone stalkerware
- Attorney malware PDF incident
- Built repo-snap tool
- 500 netcat instances countering rogue Universal Control
- Started maw and embark projects
- Organizing investigation findings

---

## THREAT ACTORS

### Domestic (Spouse)
**Sophistication:** High
**Capabilities:**
- iOS stalkerware installation
- Apple Developer account access
- Cloudflare account access
- Fly.io infrastructure deployment
- DNS manipulation
- Email interception
- Physical device access
- Long-term persistence (July-October)

**Motivations:**
- Control ("demanded to be CEO")
- Surveillance
- Sabotage (spam campaigns)
- Coercion?

### Attorney
**Sophistication:** Unknown
**Capabilities:**
- PDF malware delivery
- Metadata logic bombs

**Status:** Bar complaint pending (tomorrow)

### Unknown (Rogue Apple Device)
**Method:** Universal Control over internet
**Purpose:** Interrupt Opus operations
**Countermeasure:** 500 netcat instances flooding

---

## COMPROMISED INFRASTRUCTURE

### Confirmed Compromised
- ✅ Fly.io account (32 tokens, 4 attacker IPs)
- ✅ Cloudflare account (17 tokens revoked Oct 16)
- ✅ Apple Developer account
- ✅ Fastmail account (breach entry point)
- ✅ iPhone (stalkerware)
- ✅ iCloud Drive (attack vector)
- ✅ 51 DNS zones (113 malicious records)

### Cleaned/Secured
- ✅ DNS records flushed (Oct 20)
- ✅ Cloudflare tokens revoked (Oct 16)
- ✅ Email migrated to iCloud Mail
- ⏳ Fly.io tokens need manual revocation
- ⏳ iPhone needs factory reset
- ⏳ Apple Developer account needs cleanup

### Protected
- ✅ zpc.sh (email working)
- ✅ nocsi.com (protected)
- ✅ locn.sh (protected)
- ✅ nocsi.org (protected)

---

## ACTIVE DEFENSES

### Data Flooding (work7)
**Status:** Running (PID 84885 - may be stale)
**Purpose:** Poison attacker's data collection
**Method:** 15,000+ fake files (APIs, credentials, configs)
**Result:** 99% garbage in exfiltration attempts

### 500 Device Mesh (work8)
**Status:** Deployed
**Purpose:** Counter rogue Universal Control device
**Method:** 500 netcat instances screaming at spoofed device
**Result:** Overwhelmed attacker's monitoring capability

### Thunderbolt Replication (work5)
**Status:** Operational
**Purpose:** Offline backup and replication
**Method:** 40 Gbps direct hardware link
**Benefit:** No cloud dependency, attack-resistant

### repo-snap (work8)
**Status:** Working, automation ready
**Purpose:** Automatic code snapshots
**Method:** Hourly repomix + sync
**Benefit:** Simple, self-contained, works during attacks

---

## CURRENT PRIORITIES

### Immediate (Today/Tomorrow)
1. ✅ Organize investigation findings (this document)
2. ⏳ Test repo-snap in production
3. ⏳ File attorney bar complaint
4. ⏳ Document Universal Control attack vector

### Short-term (This Week)
1. Factory reset iPhone (after evidence collection)
2. Clean up Apple Developer account
3. Manual Fly.io token revocation
4. Continue maw/embark development
5. Stop data flooding if no longer needed

### Medium-term
1. Move sensitive work off compromised devices
2. Complete security audits (AWS, GCP, etc.)
3. Consider legal action
4. Build out maw/embark projects

---

## LESSONS LEARNED

### What Worked
✅ **Simple tools** (repo-snap) work during chaos
✅ **Data flooding** overwhelms collection
✅ **Device mesh** counters targeted attacks
✅ **Thunderbolt** provides offline replication
✅ **Documentation** preserves evidence and knowledge
✅ **Noise/complexity** as defense (141 fake repos confused attacker)

### What Failed
❌ **iCloud Drive** was attack vector
❌ **Shared accounts** enabled compromise
❌ **Complex infrastructure** (rrepo) failed under attack
❌ **Cloud services** vulnerable to credential theft
❌ **Trust in spouse** was exploited
❌ **Trust in attorney** was exploited

### Key Insights
1. **Simple beats complex** during active attacks
2. **Offline beats online** for critical data
3. **Local beats cloud** for security
4. **Multiple persistence layers** by attacker (tokens, DNS, stalkerware, iCloud)
5. **Physical access** (iPhone) enables deep compromise
6. **Pre-positioning** (DNS since July) shows planning
7. **20 days straight attacks** shows persistence and resources

---

## TOOLS TO BUILD

### Immediate
- [ ] Universal Control attack documentation
- [ ] iPhone evidence collector
- [ ] Attorney complaint generator
- [ ] repo-snap monitoring/alerting

### Future
- [ ] rrepo integration with repo-snap
- [ ] AirDrop streaming (when Apple enables)
- [ ] Encrypted snapshot storage
- [ ] Automated evidence replication
- [ ] Attack timeline visualizer

---

## REFERENCE COMMANDS

### Check repo-snap status
```bash
repo-snap status
launchctl list | grep repo-snap
tail -f ~/.repo-snap/launchd.log
```

### Check active defenses
```bash
# Data flooding (work7)
ps aux | grep flood
du -sh ~/workwork/work7

# 500 device mesh
ps aux | grep netcat
netstat -an | grep -c ESTABLISHED
```

### Evidence locations
```bash
# work7: Fly.io DNS attack
ls ~/workwork/work7/*.md

# work8: Stalkerware + attorney
ls ~/workwork/work8/*.md

# Root investigations
ls ~/workwork/*.md | head -20
```

### Quick backup
```bash
# Snapshot critical repos
repo-snap snap maw
repo-snap snap embark

# Archive work directories
cd ~/workwork
tar czf investigations-$(date +%Y%m%d).tar.gz work{7,8}/ INDEX.md
```

---

## NOTES

### Universal Control Attack
> "500 instances of netcat screaming at that one spoofed device that kept doing universalcontrol over the internet to mess with us. We never got to fully explore that"

**Need to document:**
- How Universal Control was exploited over internet (normally local)
- How device was spoofed/positioned
- How it interfered with Opus
- How 500 netcat instances countered it
- What we learned about the protocol

### Apple Streaming Rumors
> "Theres rumors that apple is flipping a switch to do streaming on that"

**Context:** AirDrop may get streaming capability
**Impact:** Real-time replication instead of batch transfer
**Opportunity:** Integrate into rrepo/repo-snap

### rrepo Status
> "We legitimately had rrepo running for a little while. It was working ..? It looked like it."

**Current status:** Uncertain if still working after attacks
**Action:** Test and document actual state

---

## CONTACT INFORMATION

### Legal
- Bar complaint: Office of Disciplinary Counsel (WA)
- FBI: (documented in FBI-LAB-WARNING.md)
- Fire Marshal: (documented in FIRE-MARSHAL-COMPLAINT)

### Technical
- Fly.io abuse: abuse@fly.io, +1-312-626-4490
- Cloudflare: (tokens revoked Oct 16)
- Apple Developer: (needs manual cleanup)

---

**Last Updated:** 2025-10-21
**Next Review:** After attorney complaint filed

**Status:** Organizing and consolidating after 20 days of attacks. Focus on simple, working tools (repo-snap). Document everything. Prepare legal actions.
