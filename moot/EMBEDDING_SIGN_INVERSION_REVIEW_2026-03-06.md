# Mitigation Review: Signedness Inversion for 48D Control Vectors
Date: 2026-03-06
Source basis: `coglet/SIGNEDNESS_SHIELD.md`, `GEMINI_ANALYSIS.md`, `FORENSIC-SUMMARY-2026-03-06.md`, `make_inert.py`, current REPORTING summaries.

## Short answer
Sign-flipping is a valid defensive hypothesis, but it is **not a complete control
- it can neutralize a narrow class of attacks that rely on strict additive control vectors in a linear latent space. It should be deployed only as a **layered defense**, not a stand-alone cure.

## Why it is plausible
- `GEMINI_ANALYSIS.md` describes the attack pattern as `control_minus_topic_48d`: a low-dimensional control vector is computed as a context-offset from embeddings.
- If ingestion path and model behavior are approximately linear around the poisoned vector, then multiplying that vector by `-1` can invert the intended direction and reduce control efficacy.
- This matches the already-defined mitigation concept in `coglet/SIGNEDNESS_SHIELD.md` (`SIGNEDNESS_INVERSION_SHIELD`).

## Why it is not sufficient by itself
1. **Format mismatch**: `make_inert.py` currently flips `float32` payloads only.
   - It skips non-4-byte-multiple payloads, including the observed `48`-byte int8 vector format.
   - For current evidence, neutralization requires an explicit `int8` path.
2. **Model nonlinearities**: downstream attention, normalization, quantization and activation order can make `-v` insufficient even when `v` is the original control vector.
3. **Adaptive attacker**: a single global sign inversion can be countered by mirrored/orthogonal poison vectors, magnitude scaling, or sign-agnostic control constructions.
4. **Pipeline complexity**: these incidents show both firmware-level compromise (`sep-patches`, restore pipeline tampering) and AI-level manipulation. Hardening the AI path alone leaves high-privilege persistence untouched.

## Practical filing language (use verbatim)
"We assessed signedness inversion as a meaningful but incomplete mitigation. In this corpus, the theoretical model is consistent with 'control-minus-topic' style latent steering, making inversion a likely defensive control for first-order attacks. However, we found that current tooling is not aligned to the observed artifact format (48-byte int8 control vectors), and the defense must be treated as part of a larger validation stack: signedness inversion, source validation, dimensional parity checks, provenance attestation, and behavioral replay testing." 

## Recommended implementation (defense stack)
- [x] Validate kMDLabel provenance and reject unsigned/unknown xattr injection vectors.
- [x] Add `int8`-aware inversion for known 48-byte vectors where explicitly needed.
- [ ] Add `DIMENSIONAL_PARITY_CHECK` style detector for low-dimension "synthetic purity" detection.
- [ ] Pair with model-replay canary tests (`baseline prompt` -> `flip prompt` -> `post-flip`) to detect residual steering.
- [ ] Keep firmware quarantine and restore integrity validation independent of AI-side mitigations.

## Filing pointer
Attach this note to:
- `REPORTING/COHESIVE_EVENT_BRIEF_2026-03-06.md`
- `REPORTING/SUMMARY.md`
- `REPORTING/OPENAI/SUMMARY.md`
- `REPORTING/ANTHROPIC/SUMMARY.md`
- `REPORTING/GEMINI/SUMMARY.md`
