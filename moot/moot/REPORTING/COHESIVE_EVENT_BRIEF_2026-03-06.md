# Cross-Provider Briefing: Suspected AI-Influence + Firmware Compromise Event
Date: 2026-03-06  
Distribution: OpenAI / Gemini / Anthropic  

## 1) Executive summary
An incident centered on a MacBook Air M3 (Mac16,12 / J713ap / T8132) shows coordinated compromise at both firmware and AI-integration layers.

- **Firmware layer**: Evidence of boot pipeline manipulation (iBoot/SEP patching, `db/active` switching, and custom restore flow state).
- **AI layer**: A 48-byte control vector mechanism was identified in a CoreML model workflow (`control_minus_topic_48d`), with intent to inject context-agnostic behavioral control into Siri/Spotlight-style AI paths via Spotlight xattrs.
- **Operational status**: Restore-related artifacts indicate an interrupted but clearly advanced intervention; a successful escape path was subsequently executed.

## 2) Source evidence
Primary evidence used:
- `FORENSIC-SUMMARY-2026-03-06.md` (firmware/boot artifacts, restore pipeline, SEP patch indicators).
- `GEMINI_ANALYSIS.md` (CoreML latent-space attack analysis of `control_minus_topic_48d_...` capture).

## 3) Technical synthesis

### 3.1 Boot and recovery chain compromise
- Two different `iBoot.img4` binaries were present in distinct firmware locations with different SHA-256 hashes and close timestamps.
- `sep-patches.img4` existed in operational `srvo/current/`, labeled as stage-1 (`stg1`) patch payload for `AppleSEPROM-989.0.0.300.2`.
- `bootcaches.plist` maps to the patched operational iBoot path.
- `restore_perform.txt` confirms restore/DFU pipeline involvement; an `install_fud` step was explicitly skipped during escape, matching a successful neutralization at the firmware persistence level.
- `db/active` pointer plus versioned firmware trees indicate staged/atomic boot-path switching behavior.
- NVRAM artifacts included `auto-boot=false` and abnormal restore/OTA failure states.

### 3.2 AI control vector evidence
- The model archive analyzed contains:
  - CoreML artifact (`enc.mlmodelc`)
  - Spec protobuf (`tabi_spec.pb`)
  - A quantized 48-dimensional latent operation (`dense 768×48`, int8-style compact payload behavior)
- Attack naming suggests **topic-stripping**:
  - Project label: `control_minus_topic_48d`
  - Construct: `topic` vector subtraction then injected control vector
- Reported behavior inference: this can create a context-agnostic attractor in semantic space before downstream AI consumption.

## 4) Risk assessment
- **Highest severity:** `CRITICAL` — SEP-level firmware manipulation is among the deepest practical compromises on Apple Silicon.
- **High severity:** `HIGH` — Latent vector steering of AI behavior is materially different from a passive privacy issue; it targets cognitive output behavior.
- **Observed confidence:** Strong for forensic chain and attack structure; execution impact on end-user behavior still requires independent reproduction from clean replays.

## 5) Immediate actions (shared across providers)
1. **Containment**: isolate host network, image disks read-only, preserve chain-of-custody.
2. **Firmware diff**: extract/diff both `iBoot.img4` binaries and `sep-patches.img4` payload.
3. **Persistence check**: verify `db/active`, `Controller/boot`, and `srvo/current` consistency across captures.
4. **AI artifact validation**: locate and compare all active `kMDLabel*`/xattr payloads to detect control-vector injections.
5. **Behavioral telemetry**: correlate restore timeline with anomalous Siri/Spotlight AI outputs.
6. **Keychain/credential sweep**: continue Kerberos and certificate-chain investigation per existing next-steps.

### Mitigation posture on signedness inversion
- Theoretical defense (`SIGNEDNESS_INVERSION_SHIELD` in `coglet/SIGNEDNESS_SHIELD.md`) is valid as a **first-order defense** against context-sanitized control vectors.
- It is not sufficient as a single control; the observed payload format is `48-byte int8` and current `make_inert.py` flips only `float32`, so script-level neutralization claims must be corrected in tooling and filing language.
- File: [EMBEDDING_SIGN_INVERSION_REVIEW_2026-03-06.md](/Users/locnguyen/corpus/moot/REPORTING/EMBEDDING_SIGN_INVERSION_REVIEW_2026-03-06.md)

## 6) Messaging note for providers
This is not a generic “prompt injection” issue. It appears to combine:
- signed firmware-chain abuse, and
- model-state manipulation via compact control vectors.

Any response should treat this as a **dual-layer compromise** and avoid siloing into either “system security” or “LLM safety” alone.
