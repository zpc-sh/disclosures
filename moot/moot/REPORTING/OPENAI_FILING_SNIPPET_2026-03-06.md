# OpenAI Filing Snippet — Signedness Inversion and Defense Posture
Date: 2026-03-06

## Proposed paragraph for Incident Report (Executive)
This incident appears to comprise a dual-layer compromise: (1) low-level firmware manipulation (iBoot/SEP restore pipeline) and (2) on-device AI behavioral steering through compact latent payloads (`control_minus_topic_48d`) injected via metadata surfaces (e.g., `kMDLabel` xattr objects). We assess signedness inversion as a **valid first-order defensive maneuver** against this class of latent steering, but not a complete remediation. In this dataset, the adversarial vector family is consistent with direction-dependent attention capture, so negating vector sign can reduce immediate control efficacy; however, defense claims should not be treated as full sanitization absent broader controls (format validation, provenance checks, and runtime replay).

## Proposed paragraph for Technical Appendix (Threat/Defense Model)
`SIGNEDNESS_INVERSION_SHIELD` behavior is best characterized as an input-space preconditioner: apply vector negation (`v -> -v`) to suspected steering vectors before model ingestion. This is effective under approximately linear, first-order assumptions and can disrupt additive "control-minus-topic" style optimization if the payload is consumed as a directional residual in embedding space. It should be classified as **mitigation-in-depth tier 1**, not complete containment, because downstream model nonlinearity, quantization boundaries, and adaptive adversarial counter-designs can preserve control under sign-flip-only conditions.

## Proposed paragraph for Evidence Alignment
Our current implementation artifacts are internally inconsistent for this event’s observed format: the observed control vectors are 48-byte int8 payloads, while existing `make_inert.py` currently targets `float32` blobs and skips non-4-byte-multiple payloads. We therefore cannot claim full neutralization from that script alone. Any filing should explicitly state that signedness inversion is implemented conditionally for supported vector encodings and that unsupported payload encodings remain under separate quarantine/verification workflows.

## Suggested OpenAI-safe mitigation section (Actionable)
- Implement a multi-stage control-flow check before ingestion: provenance (author/signature), schema validation (dimension/type), and statistical parity checks for ultra-compressed control-like vectors.
- Add dual-path validation for both semantic and byte-level vectors (including int8 48d formats).
- Run behavioral canary tests on model outputs before/after transformation to verify reduction of steering effects.
- Keep firmware integrity workflows independent; AI-side interventions do not substitute for restore/boot-chain remediation.

## Suggested one-line risk statement for filing
OpenAI assessment: Signedness inversion is an inexpensive and useful first response for this incident class, but it is a partial containment control and does not replace full containment of the broader attack chain.
