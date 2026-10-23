# ADDENDUM-08 — Delta Calibration Instrument: Sealed Argument and Pre-Registration

**Status:** SEALED — owner ratified 2026-10-20, after a discipline scrub (one cost figure removed per owner catch; no argument content changed). No data under the new instrument may be collected before this sealing (ADDENDUM-05 red line 3).
**Date:** 2026-10-20
**Legal basis:** ADDENDUM-05 §4 remedy R1 (delta calibration); ADDENDUM-07 §2 (no human-subjective scoring), §3 (exam v2 errata), §4 (direction-by-construction rule).
**Custody:** sealed in the evidence store with sha256 timestamp before any new-instrument data collection.

## 1. The measurement object, from first principles

1.1. The production verdict makes an **ordinal** claim: *the optimized serving configuration preserves answer quality relative to the original configuration, on the same prompts.* It never claims "this answer is a 7.4 on an absolute human scale."

1.2. Calibration exam v2 measured a **cardinal** capability instead: per-axis Pearson correlation of a judge's absolute 1–10 scores against borrowed crowd-sourced labels. A mediocre absolute scorer can be an excellent pairwise judge; the gate was convicting judges on a capability the verdict never uses. That is an instrument defect, not a judge finding.

1.3. Therefore the measurement object is changed — not the ruler's tightness: **blind pairwise comparison with direction known by construction**. This is R1 exactly as pre-registered in ADDENDUM-05 §4.

## 2. Evidence already in the archive (cited, not newly collected)

From the 2026-10-20 stage-14 re-examination archives (pilot-logs: run_20261020T083828Z, T095516Z, T110320Z, T122102Z, makeup-gemini-20261020; analysis of already-collected data only):

- All four newly registered flagship judges: median worst-axis absolute r = **0.642–0.727** (gate: ≥ 0.80 — all fail).
- The same judges' scores, re-read as pairwise orderings: accuracy **0.78–0.89** on item pairs with gold separation ≥ 1, and **0.90–0.97** on pairs with separation ≥ 3, on every axis.
- Scale compression is mechanical: judge score dispersion 1.7–3.3 vs gold dispersion 3.4–3.8, with gold confined to 4–5 discrete Likert-stretched tiers.
- 22 of 96 items: all four flagships, across all runs, deviate from gold by ≥ 3 points in consensus — consistent with the errata in ADDENDUM-07 §3 (proxy axis; borrowed coarse labels), not with four independent vendors failing identically.

## 3. Literature anchor

Pairwise comparison is the standard form of LLM-as-judge evaluation: MT-Bench (Zheng et al., 2023) pairs judges with pairwise/positional protocols; AlpacaEval employs comparative win-rate judgments; Chatbot Arena derives rankings exclusively from pairwise human preferences. Known judge biases and the mitigations adopted here: **position bias** — every pair is judged in both orientations; **verbosity bias** — construction includes length-matched degraded variants so that "longer" is not a usable cue; **absolute-scale drift** — eliminated by removing absolute scoring entirely.

## 4. Instrument design (frozen as spec v5.0)

4.1. **Items.** Entirely new set; every exam v2 item is retired (R1 requirement). Base texts are newly harvested and all transformations are scripted, logged, and sha256-stamped. No item's direction depends on any human or model opinion.

4.2. **Direction by construction, per axis:**
- *completeness* — the degraded response omits ≥ 1 required element of the prompt (graded: remove 1 of k … k−1 of k required elements). Omission of required content is definitionally less complete.
- *correctness* — the degraded response carries an injected factual, numeric, temporal, or entity error into an otherwise correct answer. It is definitionally less correct.
- *clarity* — the degraded response is produced by coherence-destroying mechanical transformation (sentence-order shuffle within paragraphs; connective removal) with content preserved. It is definitionally less clear.
- *overall* — any single-axis degradation above; definitionally worse overall.

4.3. **Blind protocol.** Judge sees (prompt, response 1, response 2) with randomized position, no labels, and answers per axis: `1`, `2`, or `TIE`. Every pair is judged twice, once per orientation. A TIE scores 0.5; each orientation judgment scores independently (n = 96 judgments per axis = 48 pairs × 2 orientations). Orientation-inconsistency rate is reported as a pre-registered diagnostic (alert level > 15%; diagnostic, not a gate).

4.4. **Judge invocation discipline.** Unchanged from stage 14: temperature 0; reasoning policy derived from the endpoint capability map and pinned in the run archive; max_tokens 4096; empty or unparseable reply = error (that judgment re-asked once, then scored as error-excluded with count disclosed).

## 5. Threshold, justified a priori, with simulation self-check

Gate: per-axis pairwise accuracy ≥ **70/96 (0.729)**, all four axes must pass (worst axis binds). Single-run certification — the binomial design makes the run statistically self-sufficient; no repeated-run protocol is needed.

Self-check (binomial, n = 96, computed a priori — no data involved):

| true judge accuracy | single-axis pass | four-axis pass |
|---|---|---|
| 0.65 (weak) | 6.2% | **≈ 0.0%** — fails, as required |
| 0.70 | 30.8% | 0.9% |
| 0.80 (mediocre) | 96.5% | **86.7%** — passes, as required |
| 0.90 | ≈ 100% | ≈ 100% |
| 0.95 | ≈ 100% | ≈ 100% |

The instrument passes a mediocre judge and fails a weak one, with the four-axis binding providing the separation. Reference point from the archive (diagnostic only): the flagship judges' observed pairwise accuracy on separation ≥ 1 pairs (0.78–0.89) straddles the mediocre band — this instrument is demanding but, on the archived evidence, passable.

## 6. Data-collection plan (executes only after sealing)

- Candidates and order: unchanged — JUDGES.json ordered pools (as extended by ADDENDUM-06), serial procedure, first pass stops, every result including failures published.
- Execution: CPU-only compute pod (no GPU; ratified operational improvement 2026-10-20). Estimated wall time ≈ 2–4 h; the spend envelope is pre-registered in the private operations ledger, and cost figures never enter any publishable artifact.
- Item construction: D+1, scripted and hashed; harness dry-run against the pod-local anchor before any API call.
- Spec freeze: pipeline spec v5.0 (pairwise judge machinery for calibration and production stages) frozen before the calibration run.

## 7. Consequence chain

- At least one seat filled per the serial procedure: panel seated; the cell-1 confirmatory quality re-evaluation (then a registered pending item) executes with the seated panel; cell-2 ignition evaluation unlocks per protocol. (That pending item was later cancelled by ADDENDUM-15 and absorbed into the cell-2 rehearsal gate.)
- Zero seats filled: escalation to owner with the full archive — the instrument's self-check bounds what a failure can mean (the candidate pool's true pairwise accuracy is below 0.80), and the next instrument decision is an owner decision.
- Publication: the full story — wipeout, autopsy, this sealed argument, and the rebuilt instrument's results — is published as one package after seating. No standalone failure chronicle (owner ruling 2026-10-20).
