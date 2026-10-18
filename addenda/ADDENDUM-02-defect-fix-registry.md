# ADDENDUM-02 — Defect-Fix Registry: Ignition-Week Repairs

**Status:** Ratified — owner review 2026-10-18
**Protocol:** Pilot005 Protocol Lock v4.2
**Date:** 2026-10-18
**Dual-track reference:** AMENDMENT-16 (internal numbering)

## 1. Scope

This addendum registers pipeline-script repairs made during the Pilot005 ignition week, and pre-declares the defect-fix classification of two further repairs required before the cell-1 confirmation phase. All five repairs are model-agnostic: none contains model- or architecture-conditional logic, and none modifies any verdict gate, frozen statistic, or protocol line. The adaptation-edit count for verdict-bearing cells 2 and 3 remains 0.

Background: the three cell specs were submitted in the frozen upload commit (39b92d1, 2026-10-17). Repairs to pipeline scripts after that point fall inside the "from spec submission to verdict output" window of verdict line 1 and are therefore registered here with their mechanical classification basis.

## 2. Group A — applied during cell-1 development (retrospective registration)

| Commit | File | Symptom → root cause → fix |
|---|---|---|
| cfb3b25 | stages/15-cell-preflight.sh | Exit 134 after all artifacts were written → pyarrow/huggingface_hub prefetch threads can outlive the workload and abort interpreter finalization (PyGILState_Release) — a streaming teardown race, not a version regression → flush stdout/stderr + os._exit(0) so the exit code reflects the completed work, not the race. |
| 4ba90c5 | pipeline/lib_measure.sh | vLLM 0.31 server refused to start → `--enable-prefix-caching=False` is not accepted pair syntax → use `--no-enable-prefix-caching` (aligns with lib_serve.sh, which already carried the correct form — file-level drift family). |
| be7d565 | pipeline/lib_measure.sh | vLLM 0.31 memory profiling under CUDA graphs made gpu-memory-utilization 0.92 behave as ~0.89; KV cache 7.31 GB < the 8 GB required by the spec-pinned 32k context → raise to 0.9472 (vLLM's own published equivalent), identical across all three arms so measurement fairness is preserved; spec-pinned MAX_MODEL_LEN untouched. |

## 3. Group B — pre-declared here, applied only after this addendum enters the repository

1. **pipeline/run_cell.sh — intervention-count semantics.** The intervention ledger appends one line per event; the cap check counted raw lines, including machine bookkeeping rows (`run-complete:*`) that Protocol v4.2 §7 explicitly classifies as "logged and published, but not counted". After cell-1 development the ledger holds 6 lines (5 human ignitions + 1 machine row). Uncorrected, a single confirmation-phase resume would trip the cap at 9 raw lines and lock the phase out of its frozen second attempt — a verdict-line risk for verdict-bearing cells 2 and 3. Fix: count human-action rows only (exclude `run-complete:` machine rows). No gate value changes; the cap stays 8 and the attempt cap stays 2.
2. **pipeline/stages/16-arm-screening.sh — wave-1 winner.json recipe sha.** The wave-1 winner writer hard-coded `recipe_sha256: None` under a stale note ("resolved from recipes_executed.jsonl at stage 18"); stage 18 in fact reads winner.json. When the wave-1 winner survives the wave-2 merge, the file is not overwritten, and the string "None" propagated into cell-1's verdict_c.json. Fix: resolve the real sha from recipes_executed.jsonl at the wave-1 write point — the identical lookup the wave-2 final writer already performs. Cell-1 artifacts stand as published; §4 registers the blemish.

## 4. Disclosure

- Cell-1 stage-18 verdict_c.json carries `recipe_sha256: "None"` — registered here as a known provenance-field blemish. The verdict path never consumed the field (stage 19 reads only `arm_id` from winner.json and `quality_gate` from verdict_c.json); the cell-1 development verdict is unaffected.
- Each repair commit message records the defect family; staging-harness verification is noted where applicable.

## 5. Effect

No line of the Protocol or of FROZEN-LINES.json is modified by this addendum. The intervention cap remains 8 per cell, the confirmation attempt cap remains 2, and all gate thresholds are unchanged.
