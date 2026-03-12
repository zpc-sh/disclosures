# OpenAI Provider Brief — 2026-03-06 Incident
This brief is intended for cross-provider alignment.

- The incident combines **firmware-chain compromise** (iBoot/SEP/restore pipeline artifacts) with a **CoreML latent-control mechanism** (`control_minus_topic_48d`) likely steering AI behavior by injecting context-removed control vectors.
- Key evidence was consolidated in: `COHESIVE_EVENT_BRIEF_2026-03-06.md` (root `REPORTING`).
- Supplemental operator framing for model teams is in `COHESIVE_DREAMSTATE_CONTROL_ADDENDUM_2026-03-06.md`.

## Action request
Treat as a high-confidence dual-vector threat:
1) verify firmware integrity end-to-end, and  
2) verify AI model-state artifacts and any vector injection into Spotlight/Siri pipelines.

## OpenAI action language
- Frame this as a dual-layer threat: firmware persistence + AI ingestion-path manipulation.
- Treat `SIGNEDNESS_INVERSION_SHIELD` as a **layer-1, limited** control and require evidence of router/provenance gates before any “contained” classification.
