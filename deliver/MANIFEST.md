# Incident Evidence Package

**Prepared:** November 17, 2025  
**Case:** Network MITM Binary Injection Attack

## Package Contents

```
deliver/
├── EXECUTIVE_SUMMARY.md     # High-level overview for decision makers
├── TECHNICAL_REPORT.md      # Complete forensic analysis
├── CHECKSUMS.txt            # SHA256 checksums of all evidence
└── MANIFEST.md              # This file
```

## Full Evidence Archive

**Location:** `~/workwork/work17/`

**Contents:**
- Binaries (124MB): Infected vs clean Node.js  
- Network captures (74KB): Exfiltration traffic
- Proxyman logs (56MB): Detailed HTTP/HTTPS analysis
- Debug logs (298KB): Cloudflare WAF errors
- Analysis files (60MB): Symbol tables, strings extraction

**Total size:** ~200MB

## How to Access Full Evidence

```bash
# View evidence structure
ls -lR ~/workwork/work17/

# Verify checksums
cd ~/workwork/work17
shasum -a 256 -c ~/workwork/deliver/CHECKSUMS.txt

# Read full technical analysis
open ~/workwork/deliver/TECHNICAL_REPORT.md
```

## Key Files for Immediate Review

1. **EXECUTIVE_SUMMARY.md** - Start here
2. **TECHNICAL_REPORT.md** - Complete analysis
3. **work17/binaries/node1** - Infected binary (for RE team)
4. **work17/pcaps/*.pcap** - Network evidence (for security team)
5. **work17/logs/claude-debug-waf-error.txt** - Cloudflare evidence

## Sensitive Information

This package contains:
- ⚠️ User IP addresses
- ⚠️ Cloudflare Ray IDs
- ⚠️ Network infrastructure details
- ⚠️ Malicious binary samples

**Handle with appropriate security controls.**

## Verification

```bash
# Verify this is the complete package
wc -l EXECUTIVE_SUMMARY.md TECHNICAL_REPORT.md CHECKSUMS.txt
# Should show: substantial line counts

# Check evidence integrity
cd ~/workwork/work17
shasum -a 256 binaries/node1
# Should match: e7daf91e350dcfc19c3f67bef0a463c1269e98e084606c2e38edf2c349e3842a
```

## Questions?

Contact: [Your details]
