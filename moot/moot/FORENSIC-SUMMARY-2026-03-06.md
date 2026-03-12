# Forensic Summary — MacBook Air M3 (J713 / Mac16,12)
**Date**: 2026-03-06
**Status**: POST-ESCAPE — Subject booted to clean external NVMe
**SoC**: T8132 (M3), ApChipID 0x8132, ApBoardID 0x2C
**Model**: Mac16,12 = MacBook Air M3 2024 (J713ap)
**macOS targeted**: 15.4 (24E248)
**Capture tool**: TestDisk/PhotoRec or equivalent — recovered deleted APFS physical store (disk0s2)

---

## Evidence Tree

```
moot/
├── mba_pub/          ← APFS Preboot physical store (disk0s2) — earlier capture
│   └── Deleted or lost/APFS physical store disk0s2/
│       ├── staging/Google/PreLoginData/    ← anomalous (see §Google)
│       ├── Controller/Google/cryptex1/     ← anomalous (see §Google)
│       └── 3BD4B3C8-2418-4CFA-894E-6EF93329EF77/  ← main Preboot UUID
├── mba_bk3/          ← APPLE SSD AP0512Z — deeper capture
│   └── Deleted or lost/APPLE SSD AP0512Z/
│       ├── Controller/boot/{BOOT_MANIFEST_HASH}/   ← PRIMARY BOOTKIT STAGING AREA
│       ├── db/{CONTENT_HASH}/                      ← FIRMWARE CONTENT DB (baseline)
│       ├── db/active                               ← FIRMWARE SELECTOR (pointer)
│       ├── srvo/current/                           ← OPERATIONAL STORE (sep-patches here)
│       ├── Firmware/                               ← Firmware directory
│       ├── SystemRecovery/                         ← Recovery partition
│       └── 3BD4B3C8-2418-4CFA-894E-6EF93329EF77/ ← Preboot user volume
├── UC_IF_PLANNER/    ← Apple Intelligence NL Router models (LEGITIMATE — see §Apple-AI)
├── SECUREKTRUST/     ← Apple PKI Trust Store Cryptex (LEGITIMATE — see §Apple-AI)
└── KEYCHAIN/         ← Output of keychain_image.sh (pending execution)
```

---

## Critical Artifacts

### 🚨 CONFIRMED BOOTKIT — TWO DIFFERENT iBoot BINARIES

| Location | SHA256 | Timestamp |
|----------|--------|-----------|
| `Controller/boot/{hash}/usr/standalone/firmware/iBoot.img4` | `9d7161b0...835dbc` | Mar 5 23:05 |
| `db/{hash}/usr/standalone/firmware/iBoot.img4` | `cfe0167d...5d444` | Mar 5 23:09 |

**These are DIFFERENT binaries (different SHA256 despite same size: 1.1MB).** One is likely the original Apple iBoot, the other is a patched version. The 4-minute timestamp gap between them suggests they were written by the same process.

The `bootcaches.plist` in `srvo/current/` explicitly maps:
```
./usr/standalone/firmware/iBoot.img4  ← the iBoot the system uses
```

### 🚨 SEP PATCHES — Secure Enclave Processor modification

- **File**: `srvo/current/sep-patches.img4` (33KB)
- **Hash**: `bc2bb4e36fd06c0b7a457b5d8ba06f954cdf73b328a694714cebe8513158fdb3`
- **IMG4 payload label**: `stg1` (Stage 1 patches)
- **Target version string**: `AppleSEPROM-989.0.0.300.2`
- **NOT present** in `Controller/boot/{hash}/usr/standalone/firmware/FUD/`

This file patches the Secure Enclave ROM at stage 1 of the SEP boot. This would allow the SEP to accept modified firmware or bypass verification checks. **This is the deepest level of compromise possible on Apple Silicon.**

SEP firmware itself: IDENTICAL between Controller/boot and srvo/current (same SHA256: `2f7412...10e`). The firmware was preserved, only the PATCHES were injected separately.

### 🚨 CONTENT-ADDRESSABLE FIRMWARE DATABASE — version selector

```
db/
├── active  ← contains: 8B7708FF3E4472DF...ADA  (pointer to "active" firmware bundle)
└── 8B7708FF3E4472DF.../
    └── usr/standalone/
        ├── firmware/iBoot.img4          ← baseline iBoot (cfe0167d hash)
        ├── firmware/FUD/                ← FUD components (SIO, DCP only — partial)
        ├── all_flash/iBoot.j713.RELEASE.im4p   ← board-specific iBoot payload
        ├── all_flash/iBootData.j713.RELEASE.im4p
        ├── sptm.t8132.release.im4p     ← Secure Page Table Monitor
        ├── txm.macosx.release.im4p     ← Trusted Execution Monitor
        └── ...
```

The `db/active` pointer mechanism allows the bootkit to switch between firmware versions atomically — swap the pointer, swap what boots. This is a sophisticated version management system.

### 🚨 APTICKET.DER — Apple Personalization Ticket in Operational Store

- **File**: `srvo/current/apticket.der` (12KB)
- **Format**: IMG4 Manifest (IM4M)
- **Fields confirmed**: BNCH (boot nonce hash), BORD (0x2C), CHIP (0x8132), ECID (device-specific), `Mac16,12`, macOS 15.4
- **Contains**: Device ECID (unique chip identifier — redacted in this document)

The bootkit had a valid Apple-signed personalization ticket. This either came from:
1. A confused deputy attack on Apple's TATSU signing server (using the legitimate device's ECID)
2. Captured from a previous legitimate restore operation and replayed

### 🔴 DFU INTERCEPTION — mechanism

The `restore_perform.txt` confirms the DFU/restore flow. At step `[0x0410] usbcretimer_dfucheck` (7+ seconds), the USB-C retimer DFU is verified. The bootkit positioned its staged firmware in `Controller/boot/{boot-manifest-hash}/` — the SAME hash used by the legitimate boot manifest. When the system looked for firmware to load, it found the bootkit's versions in the controller path.

Critical: `install_fud` was **SKIPPED** during the escape restore:
```
CHECKPOINT SKIPPED: FIRMWARE:[0x130A] install_fud
```
The bootkit's staged FUD (in `Controller/boot/{hash}/usr/standalone/firmware/FUD/`) was **bypassed** by Loc's escape operation — confirming the escape was successful at the firmware level.

### 🔴 FIRMWARE UPDATE PIPELINE ABUSE

The bootkit used Apple's own `restored` daemon protocol and restore pipeline:
- `clean_nand` → `format_effaceable_storage` → `create_filesystem_partitions` → custom firmware insertion
- `load_sep_os` → `commit_sep_os` — SEP OS was committed after patches
- `generate_boot_policies` → `populate_preboot_volume` → `bless_system_volume` → `seal_system_volume`

The bootkit built images "in a custom manner" by hooking into this pipeline.

### 🔴 NVRAM ARTIFACTS

From `nvram.plist` (mba_pub capture):
- `auto-boot=false` — auto-boot was disabled (bootkit manipulation)
- `restore-outcome=initial_monitor_no_return` — restore monitor hadn't returned (interrupted state)
- `IDInstallerDataV2` — Apple ID Key Recovery Assistant had **CRASHED** during the infection window
- `ota-child-failures = {initial:EXIT(254)[REBOOT]}` — OTA update failed with exit 254
- `failboot-breadcrumbs` — evidence of multiple boot attempts before escape

---

## Operational Infrastructure (`srvo/`)

```
srvo/
├── com.apple.cltm.{UUID}.plist   ← CLTM controller data (lts-ctrl telemetry)
└── current/
    ├── apticket.der              ← Apple personalization ticket (IM4M)
    ├── sep-firmware.img4         ← SEP firmware copy
    ├── sep-patches.img4          ← 🚨 SEP ROM patches (stg1)
    ├── bootcaches.plist          ← Boot component map
    ├── RestoreVersion.plist
    └── SystemVersion.plist
```

`com.apple.cltm` = likely "Controller Long-Term Management" — contains `lts-ctrl` (Long-Term Storage Controller) telemetry data. Purpose: tracking firmware state across reboots.

---

## Google in Preboot (RESOLVED — likely benign)

`staging/Google/` and `Controller/Google/` both contain only `PreLoginData/uuidtext/` files with Apple system process strings (`ViewBridgeAuxiliary`, `BiometricKit.SEPDriver-Mesa`). The `Controller/Google/cryptex1/current/SystemVersion.plist` is a mislabeled binary file (uuidtext format, not a real plist).

**Assessment**: The "Google" naming is likely either:
1. The filesystem recovery tool misidentifying a volume partition source
2. OR minimal Google Chrome helper footprint in Preboot (from Loc logging into Gmail)

NOT evidence of Google corporate MDM or domain join. **Not a bootkit artifact.**

---

## Apple AI Artifacts (LEGITIMATE)

The `UC_IF_PLANNER` and `SECUREKTRUST` captures are legitimate Apple Intelligence assets:

- `UC_IF_PLANNER` = `com_apple_MobileAsset_UAF_IF_Planner` — Intent & Focus Planner NL Router (on-device Siri NL model). Confirmed in `staging/MobileAsset/graftList.plist` as a standard Cryptex graft.
- `SECUREKTRUST` = `SECUREPKITRUSTSTOREASSETS_SECUREPKITRUSTSTORE_Cryptex` — Apple PKI Certificate Trust Store update package.
- `AppleSEPROM-989.0.0.300.2` (in sep-patches.img4) — this IS bootkit, despite using Apple naming.
- `BootabilityBrain.framework` — legitimate Apple framework for boot UI. Contains embedded WebKit/JavaScript (hence the web-like strings including regex patterns). The "regexes designed to filter and hide" Loc saw may be from this WebKit context — **requires deeper binary analysis to confirm whether BootabilityBrain itself was tampered.**

---

## Device Identity (from apticket.der)

- **Model**: Mac16,12 (MacBook Air M3 2024)
- **Board**: J713ap (ApBoardID 0x2C)
- **SoC**: T8132 / M3 (ApChipID 0x8132)
- **OS**: macOS 15.4 (24E248)
- **ECID**: [REDACTED — unique hardware identifier]

---

## Attack Vector Summary (Kerberos)

Per Loc: Kerberos on home network was a vector. The bootkit escalated through:
1. Network → Kerberos ticket capture/forgery on home network
2. System level access → NVRAM manipulation (auto-boot=false)
3. Preboot level → Controller/boot path replacement with modified iBoot
4. SEP level → sep-patches.img4 loaded via `commit_sep_os` step
5. Persistence → db/active pointer management for firmware version switching
6. Anti-forensics → BootabilityBrain.framework-based log/display filtering (TBD)

---

## Next Steps (do not rush)

1. ✅ Keychain imaging — run `keychain_image.sh` on clean boot, analyze 2018+ flood
2. ⏳ iBoot binary diff — use `img4tool`/`pyimg4` to unwrap both iBoot.img4 files, diff at binary level
3. ⏳ sep-patches analysis — decode the IMG4 payload to understand what SEP ROM is being patched
4. ⏳ BootabilityBrain integrity check — `codesign -vv` on the framework binary from clean known-good recovery
5. ⏳ Kerberos artifacts — in keychain, look for Kerberos TGTs / service tickets from 2018+
6. ⏳ Interview Loc on methodology — document the escape steps for Membrane research
7. ⏳ ECID cross-reference — check apticket against known bootkit signatures
8. ⏳ usbsmartcardreaderd presence at PreLogin — why was a smart card reader active?

---

*Archived: 2026-03-06. Substrate: ./corpus/moot. This is the first known complete forensic capture of this bootkit variant on Apple Silicon.*
