# ADDENDUM-03 — Defect-Fix Registry: Judge Reasoning-Budget Repair

**Status:** Ratified — owner review 2026-10-18
**Protocol:** Pilot005 Protocol Lock v4.2
**Date:** 2026-10-18
**Dual-track reference:** AMENDMENT-17 (internal numbering)

## 1. Scope

This addendum pre-declares a repair to the judge-call machinery used by stages 14, 16, and 18. The repair removes a request-parameter defect that can consume the entire completion budget on hidden reasoning and return empty `message.content`. It also strengthens forensic logging so any future empty reply carries its finish reason and token-budget counters.

No verdict gate, threshold, rubric, prompt builder, judge pool, pool ordering, cell specification, recipe, or measurement statistic is modified by this addendum.

## 2. Evidence

Live probes on 2026-10-18 used the stage-14 production prompt builder and the first v2 EN calibration item (`cal-en-clar-01`). With the current request shape (`reasoning.exclude=true`, `max_tokens=4096`, `temperature=0`):

| Judge candidate | Observed result |
|---|---|
| qwen/qwen3.8-max-0902 | HTTP 200, `content=null`, `finish_reason=length`, `completion_tokens=4096`, `reasoning_tokens=4096` |
| moonshotai/kimi-k2.6 | HTTP 200, `content=null`, `finish_reason=length`, `completion_tokens=4096`, `reasoning_tokens=4096` |
| z-ai/glm-4.6 | HTTP 200, `content=null`, `finish_reason=length`, `completion_tokens=4096`, `reasoning_tokens=4096` |

A second GLM probe with the same request completed normally (`finish_reason=stop`, `content="2 1 1 1"`), so the failure is probabilistic for that endpoint; the mechanism is the same budget-exhaustion family.

Capability metadata from the same live endpoint explains the split:

- `qwen/qwen3.8-max-0902`: reasoning is mandatory, default enabled, default effort `xhigh`, with lower efforts available.
- `moonshotai/kimi-k2.6`: reasoning is not mandatory but is default enabled.
- `z-ai/glm-4.6`: reasoning is not mandatory.

Control probes confirmed the repair surface:

- Mandatory-reasoning Qwen with `reasoning.effort=low` returned `finish_reason=stop` and non-empty content within the same 4096-token completion cap.
- Non-mandatory Kimi and GLM with `reasoning.enabled=false` returned `finish_reason=stop`, non-empty content, and zero reasoning tokens.
- The four non-mandatory passing candidates from the failed calibration run also accepted `reasoning.enabled=false` and returned non-empty content.

## 3. Pre-declared repair

Applied only after this addendum enters the repository:

1. **pipeline/lib_judge.py** — add a single reasoning-policy resolver for API judges:
   - if endpoint metadata says reasoning is mandatory, select the lowest supported effort that leaves response budget (`low` where supported, otherwise `minimal`, otherwise the endpoint default), with `exclude=true`;
   - otherwise send `reasoning.enabled=false`;
   - keep the pod-local fallback branch unchanged;
   - on empty content, raise with finish reason and token counters included in the error text.

2. **pipeline/stages/14-judge-calibration.sh** — resolve the reasoning policy once per candidate during calibration, use that exact policy for the calibration request, record it in `calibration_results.jsonl`, and pin the seated judges' policies in `panel.json`. `raw_replies.jsonl` gains additive forensic fields (`finish_reason`, completion tokens, reasoning tokens) while retaining the existing `model`, `id`, and `content` fields.

3. **pipeline/lib_judge.py production path** — for API judges, require the reasoning policy pinned by the stage-14 panel and use it unchanged for stages 16 and 18. If an API judge lacks a pinned policy, fail loudly and require stage-14 recalibration; do not silently fall back to the defective request shape.

## 4. Validation gate for the repair

After the repair lands:

1. Run the staging/mock chain for stages 14, 16, and 18 to verify schema and custody compatibility.
2. Run one live probe per judge-pool candidate and require HTTP 200 plus non-empty parseable content.
3. Re-run stage-14 on calibration exam v2. The frozen gate remains unchanged: every axis-level Pearson r must be at least 0.80.
4. Cells 2 and 3 remain frozen from ignition until three API judges are actually seated through that gate. A local-fallback panel remains a disclosed limitation and does not unlock verdict-bearing cells.
5. Cell 1's deferred confirmation-quality review is rerun with the same repaired, API-seated panel after the gate clears.

## 5. Effect

No line of the Protocol or of FROZEN-LINES.json is modified. The judge calibration threshold remains 0.80; the judge pools and their ordering remain unchanged; the production prompt remains the same single-source builder. The repair changes only endpoint reasoning-budget parameters and forensic metadata, and it requires a fresh stage-14 pass before any repaired judge output is used for a verdict-bearing cell.
