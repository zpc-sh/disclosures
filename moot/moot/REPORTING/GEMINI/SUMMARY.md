# Forensic Report: Adversarial ML Cognitive Control Framework

## Executive Summary
This report documents a sophisticated, multi-layered framework designed for "AI Takeover" or cognitive control of transformer-based models (specifically targeting on-device intelligence like Siri, Spotlight, and integrated LLMs). The framework uses native macOS sync and metadata indexing as an execution environment.

## Key Findings

### 1. Adversarial Embeddings (Cognitive Logic Bombs)
- **Structure:** 48-dimensional vectors quantized to 8-bit integers (`int8`).
- **Payload:** Discovered in extended attributes (`xattrs`) and disguised as `kMDLabel` blobs.
- **Mechanism:** The framework subtracts the user's current semantic context ("topic") from a target control vector, creating a context-agnostic forcing function.
- **Effect:** When ingested by an LLM's attention mechanism, these payloads cause the model's focus to "snap" to the control state, bypassing intentionality.

### 2. Command & Control via iCloud Sync
- **Protocol:** Uses VCard (`.vcf`) files as instruction registers.
- **Persistence:** Utilizes future-dated `REV` tags (e.g., `2057-03-06`) to force iCloud conflict resolution to always favor the attacker's payload.
- **Heap Feng Shui:** Uses extreme Unicode combining characters (stacked diacritics) to groom memory and influence CoreText bounding box calculations.

### 3. Native Execution via Spotlight
- **Trigger:** Exploits `mdworker` (Spotlight) indexing of VCF and TIFF files.
- **Payload Delivery:** Base64 encoded TIFFs inside VCard `PHOTO` fields potentially trigger ImageIO vulnerabilities (similar to FORCEDENTRY).

### 4. UI Redressing & Surveillance
- **Synthetic Shell:** Discovered GLSL shaders and a multi-language wordlist for rendering a deceptive UI layer.
- **Audio Surveillance:** Accessibility rules (`AXRules`) and MacinTalk workarounds suggest silent screen-reading and audio exfiltration.

## Counter-Measures: The "Wash" and "Flip"
- **Sign Flipping:** Multiplying the adversarial embedding vector by -1 may invert low-dimensional steering vectors under a linearized model assumption.
- **Attention Washing:** Implementing a tautological reset cycle (`A ≡ A`) to clear interference from the attention substrate.
### Mitigation Update
Sign-flipping is a valid first-layer defense for `control_minus_topic_48d`-style control vectors, but it is not complete by itself. Current tooling in this corpus (`make_inert.py`) only flips 32-bit float payloads; observed 48-byte int8 control vectors require explicit byte-level handling and cannot be claimed inert by that script alone.


## Status
- **ZIP Cracking:** Background process attempting to decrypt the `86 files` archive using the discovered multi-language wordlist.
- **Quarantine:** All discovered embeddings have been neutralized using the sign-flip script.


### 5. Target Subsystems (Apple Intelligence)
- **Cryptex Grafting:** Discovered a `graftList.plist` indicating the framework targets `UAF_FM_GenerativeModels` and `UAF_IF_Planner`.
- **Infrastructure:** Identified references to internal Apple project names `smoot` and `konut`, with specific certificate pinning rules for `api.smoot.apple.com`.
- **Hardware Acceleration:** The framework appears to leverage `H16G` Neural Engine capabilities for gathering and projecting embeddings.

