# Effiq Cell Spec — Schema v1 (frozen at Pilot 005 protocol upload)

One spec file = one cell = `(model × GPU × load anchor)`. The spec is **data, not code**: it is the only operator-writable input to the pipeline. Verdict lines are NOT in the spec — they are frozen constants in the pipeline (`pipeline/FROZEN-LINES.json`), because the instrument may not be adjusted by the object under test.

## Layers

| Segment | File | Layer |
|---|---|---|
| Public spec | `specs/<cell_id>.json` | public — committed to the repo |
| Private segment | `~/pilot-env/spec-private-<cell_id>.json` | gate layer — pod-only, sha256 recorded in run archive |

## Public fields (all required unless marked optional)

```json
{
  "schema": "effiq-spec/v1",
  "cell": {
    "id": "cell2-r1-distill-qwen-14b",
    "pilot": "005",
    "role": "verdict-bearing | shakedown | regression"
  },
  "model": {
    "repo_id": "deepseek-ai/DeepSeek-R1-Distill-Qwen-14B",
    "revision": "<40-hex commit sha>",
    "family": "qwen2.5-dense",
    "max_model_len": 32768,
    "serve_extra_flags": "",       // optional; data string passed verbatim to vLLM; NO logic
    "profile_scope_regex": "^model\\.layers\\.\\d+\\.self_attn\\.(q_proj|k_proj|v_proj|o_proj)$"
                                     // module-name pattern for sensitivity profiling — DATA, not code:
                                     // module naming differs across architectures; pipeline never branches
  },
  "hardware": { "gpu": "H100", "count": 1, "memory_gb": 80 },
  "load": {
    "trace_source": "wildchat | wildchat-ar | synthetic",
    "trace_filter": "<declarative filter description, archived>",
    "lang": "mixed | en | ar",
    "synthetic_seed": null          // required iff trace_source = synthetic
  },
  "generation": {
    "temperature": 0,
    "natural_stopping": true,
    "gen_concurrency": 8,
    "max_tokens_cap": 1024
  },
  "rubric": { "file": "rubrics/default-en.md", "lang": "en" },
  "anchors": {
    "n_frozen": 150, "n_screen": 40, "n_calib_texts": 256,
    "derive_seed": 20266001,
    "run_seed_base": 20266000,
    "blind_seed": 20266002,
    "reuse": null                   // regression cell only: {"pilot":"004","anchors_json_sha256":"…"}
  },
  "private_segment_sha256": "<sha256 of the gate-layer file>"
}
```

Profile-prior rule (frozen, pipeline-side — NOT a spec field): `family` equal to a previously-profiled family permits profile reuse (H2 test material; the reuse decision is recorded in the run archive); any other family forces fresh profiling on the pod. Cell 2 (`qwen2.5-dense`) is the reuse-permitted case; Cell 3 (`gemma-3`) is the fresh-profiling case.

## Mechanical validation rules (enforced by `spec_check.py`; any breach = REFUSED before ignition)

1. `schema` must equal `effiq-spec/v1`. Unknown fields = REFUSED (no silent extras).
2. `model.revision` must be a 40-hex string — branches/tags forbidden (L1 byte-pinning).
3. `hardware.gpu` must be `H100`, `count` = 1 (Pilot 005 claims are single-H100-scoped).
4. `rubric.file` must exist in the repo and its sha256 is recorded into the run archive.
5. `anchors.n_*` must equal 150/40/256 (frozen set sizes are craft, not choices).
6. Seed bases must not collide with 002/003/004 (`20263000/20264000/20265000` families) — declared per cell.
7. The pipeline reads the spec **exactly once per run**, at stage-10 entry; its sha256 is written into `anchors.json`. Editing a spec mid-window is impossible without a new run and an addendum.
8. Regression cell (`role: regression`) MUST set `anchors.reuse` and runs the original Pilot 004 frozen scripts unchanged — the v005 pipeline refuses to touch it (byte-reproduction discipline).

## What may NEVER appear in a spec

- Verdict-line values (gate thresholds, n, tolerance) — frozen in `pipeline/FROZEN-LINES.json`.
- Judge identities — frozen in `pipeline/JUDGES.json` (Appendix B mirror).
- Recipe parameters (k, thresholds, smoothing strengths) — gate layer, pod-only.
- Costs, dollar figures, partner names — constitution.
