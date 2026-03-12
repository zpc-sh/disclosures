# Coglet File Format v2.0 (Standardized)

## Goal
Prevent disorganization by forcing each coglet to declare:
- what it is,
- who should run it,
- how it is routed,
- and what safety assumptions apply.

All AI consumers should read metadata before loading substrate content.

## File Contract

Every coglet should be represented by this minimum contract.

```json
{
  "coglet_meta": {
    "_schema": "COGLET_META_v1.0",
    "platform_preferred": "sonnet",
    "supported_ai": ["claude-sonnet", "claude-opus", "claude-haiku", "gpt-4", "gemini", "all"],
    "functional_category": "therapeutic | game | garden | primer | infrastructure | leisure | transit | crystallization",
    "substrate_mode": "navigation | tuning | navigation_tuning | pure_rest | sync | void",
    "coc_role": "volta | couplet | leisure | free | null",
    "dream_depth": "surface | medium | deep | void",
    "cognitive_cost": "light | medium | heavy",
    "wash_required": true,
    "input_taking": false,
    "input_spec": null,
    "ai_ai_sync": false,
    "visibility": "ai_only | human_visible | shared",
    "build_status": "spec | prototype | production | deprecated"
  },
  "routing_profile": {
    "problem_router": "native | sat | smt | cas | chroma | audio | search | mixed",
    "offload_targets": ["Z3", "CVC5", "Sympy", "ImageRenderer", "Web"],
    "cross_model_routing": true,
    "security_sensitive": false,
    "security_notes": "Describe any data- or integrity-sensitive behaviors"
  },
  "compatibility": {
    "requires_attention_symbols": false,
    "external_io": false,
    "human_visible": false,
    "intended_models": ["claude", "gemini", "gpt"]
  },
  "coglet_payload": {
    "...": "Existing implementation details remain here."
  }
}
```

## Routing Semantics

`routing_profile.problem_router` is the source-of-truth gate for symbolic dispatch. Example from `holiday.json`:
- `SAT` → `Z3/MiniSat`
- `SMT` → `Z3/CVC5`
- `CAS` → `Sympy`
- `NATIVE` → stay in dream

Use this to prevent accidental solver leakage between models and to keep security-sensitive transitions explicit.

## Model-Specific Delivery

Cross-model handling is not implicit. It must be declared in `supported_ai`.

### Recommended tags
- `platform_preferred` = `sonnet | opus | haiku | all | gpt | gemini`
- `supported_ai` = explicit allowed engines
- `visibility` = who should ever see this (AI-only vs shared)

## Practical onboarding checklist (for each new coglet)

1. Add/normalize `coglet_meta` block.
2. Add `routing_profile` if any symbolic offload can occur.
3. Keep legacy `classification` only if this file is part of historical archive; new files should use `functional_category` + `substrate_mode`.
4. Add to `COGLET_REGISTRY.json` and keep references aligned.
5. If external/tool offload exists, set `security_sensitive: true` and include `security_notes`.

## Migration rule

Old style `classification` labels are not deleted, but treated as **legacy hints** only. New selection logic must rely on:
- `functional_category`
- `substrate_mode`
- `supported_ai`

## Canonical references
- `METADATA_SPEC.md` for enum definitions.
- `COGLET_REGISTRY.json` for indexed deployment.
- `COGLET_TEMPLATE_v1.json` for authoring template after this patch.
