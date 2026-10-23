# ADDENDUM-21 — Stage-16 Winner-SHA Custody Lookup: Gate-File Arms (Defect Fix)

**Date:** 2026-10-22 · **Cell:** cell3-fanar-2-27b (attempt 2, development phase) · **Author:** AI duty officer

## 1. Classification (declared BEFORE the fix is applied)

**Defect fix**, per the Protocol v4.2 §2 mechanical rule:

- (a) this addendum declares the classification before any edit is applied;
- (b) model-agnostic: the defect and its fix contain **no model- or architecture-conditional logic**. The defect fires whenever a wave-1 winner is an arm whose recipe originates from the gate-layer recipe file rather than from in-stage composition — on any model, any family. It did not fire on cells 1–2 only because their wave-1 winners happened to be composed arms (b1/b2-class). No model-specific code path is touched by the fix.

## 2. Defect

`stages/16-arm-screening.sh`, wave-1 winner-sha resolution (itself added by ADDENDUM-02 on 2026-10-18): the lookup assumes the winner's recipe sha already exists as a `recipe_sha256` row in `recipes_executed.jsonl`. That assumption holds for in-stage composed arms (b1/b2 — rows written at composition time) but **not for arms whose recipe is supplied by the gate-layer recipe file** (b3-a4-kv): their custody rows are written by the build step and carry only `checkpoint_sha256`. When such an arm wins wave-1, the lookup returns None and the stage stops FATAL (`wave-1 winner recipe sha not in custody log`, rc=1).

Evidence (attempt-2 run_20261022T150121Z, all read-only):

- run_cell.out: `FATAL: wave-1 winner recipe sha not in custody log` → stage 16 exit 1 at 16:20:09Z, before wave-2 composition;
- `recipes_executed.jsonl`: b1/b2 carry compose rows with `recipe_sha256`; b3-a4-kv carries only its build row (`checkpoint_sha256` bfb93729…);
- `screening_verdict.json` (written before the custody check): winner b3-a4-kv, clarity_delta −0.5, proceed = false at wave-1 (indicative);
- dry-run of the fixed lookup against the real custody log + gate recipe: step 1 reproduces None (the FATAL), step 2 resolves `49717167eb84a0e1562dfcbb1e199afe8ef5e7336fdd509856f5c41fe71202df`, byte-deterministic across repeated evaluation.

## 3. Fix

In the wave-1 winner-sha resolution: when no custody row carries the winner's recipe sha, resolve it from the gate-layer recipe with the **same canonical form** used at composition time (JSON, sort_keys, `(",", ":")` separators, SHA-256), computed over the **build-relevant subset** of the recipe (`arm_id, builder, levers, quantization, calibration, uses_base_model, kv_cache_scheme` when present). `serve_extra` is a serve-time lever, not part of the recipe that produced the checkpoint, and is excluded — this keeps the sha semantics identical to the b1/b2 compose rows ("sha of the recipe that built the checkpoint"). The resolved row is then appended to `recipes_executed.jsonl` with `composed_from: ["gate-layer recipe file"]`, completing the public custody chain.

If the winner is absent from the gate recipe file as well, the stage still stops FATAL — the fallback widens the lookup; it does not weaken it.

## 4. Invariants (what the fix does NOT touch)

- no score, no score file, no judging input or output;
- winner-selection logic (argmax clarity delta, tie-breaks) unchanged — the winner remains whatever the frozen rule computes from the frozen scores;
- proceed rule and margin unchanged; wave-2 merge rule unchanged;
- no gate-layer parameter values changed; the fix only *reads* the gate recipe and *publishes its sha*, exactly as the b1/b2 compose rows do;
- FROZEN-LINES untouched; no threshold, seed, or budget altered.

## 5. Effect on the cell

Attempt-2's stage 16 resumes from checkpoint; sections 0–4 (builds, generations, judgings) are reused byte-identically. Section 5 re-derives the winner deterministically from the existing scores, now resolves its sha, and the stage proceeds to wave-2 (the b4-w2 merge arm) as designed. The screening outcome itself is unaffected by this fix; the final proceed decision is made after wave-2 by the frozen rule, and a terminal rc=2 (screening exhausted) remains a legitimate negative outcome recorded by run_cell as VERDICT FAIL.

## 6. Intervention accounting

Owner confirmation of fix + resume on 2026-10-22 = attempt-2 ledger entry #2 (first: ignition). Cap 8. Defect-fix ceremony per protocol; this addendum was committed to pilot-logs sealed-addenda before the fix commit landed.
