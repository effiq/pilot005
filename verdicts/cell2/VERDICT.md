# Pilot 005 — Cell Verdict Publication: FAIL (recipe gate below the frozen line; quality gate FAIL)

> Headline rule (v4.2): FAIL headlines never carry a model name. The cell
> identifier below references the pre-registered spec, which has been public
> since Protocol Lock (specs/cell2-r1-distill-qwen-14b.json).

- **Cell**: cell2-r1-distill-qwen-14b — spec sha256 `da590e7ef7818657b16c23062278fc60348243d61b4c842cc93e2838787c04d5`
- **Verdict**: **FAIL** — recipe gate CI lower bound 1.2918 < 1.50; quality gate FAIL
- **Verdict record**: `VERDICT.json`, stage-19 run `run_20261022T043544Z`, n=10
- **Phase disposition**: development phase only; the confirmation phase was not
  executed. Sealed as the cell's terminal state per ADDENDUM-18 (rationale
  summarized below).

## Semantics (verbatim from the verdict record)

> Under the pre-registered process, budget, and statistical discipline, the
> lossless-speedup test on this model × quantization × hardware combination
> returned this result. A negative result is neither a defect verdict on the
> model nor a capability verdict on Effiq — it is a compressibility fact about
> the combination under the frozen process.

## What was measured

### Stage 16 — arm screening (indicative)

Per-axis mean deltas vs the BF16 reference generation (negative = worse than
reference). Blinded items n=40 per arm; single indicative judge seat
(gpt-6-astra-pro). Screening is indicative per protocol; the calibrated
three-judge panel governs stages 18/19.

| arm | clarity | correctness | completeness | overall |
|---|---|---|---|---|
| b4-w2 (wave-2 merge; screening winner) | 0.000 | −0.025 | +0.025 | +0.150 |
| b1-profile-exempt | −0.050 | +0.025 | −0.150 | −0.150 |
| b3-a4-kv | −0.125 | −0.175 | −0.175 | −0.125 |
| b2-smooth-exempt | −0.225 | −0.125 | +0.025 | −0.100 |

Frozen proceed bar: winner clarity delta ≥ −0.05 (FROZEN-LINES
`screening_proceed_margin`). Winner b4-w2 at 0.000 → `proceed=true`.
Screening run `16-arm-screening/run_20261022T022413Z`; winning recipe sha256
`a9b66ffa1c48aa5f51e71be3d59e68e5bfe2f62660474a614b1fed24aba42198`
(b4-w2 = deterministic merge of b1-profile-exempt and b3-a4-kv).

### Stage 18 — quality gate (calibrated three-judge panel, n=150)

Per-judge mean deltas of the recipe arm vs the BF16 reference. Frozen
tolerances: −0.1 per axis and overall; worst-judge binds.

| judge | clarity | correctness | completeness | overall | seat result |
|---|---|---|---|---|---|
| deepseek-chat-v3-0324 | −0.0667 | **−0.1067** | −0.0400 | −0.0800 | FAIL (correctness axis below −0.1) |
| gpt-6-astra-pro | −0.0600 | +0.0133 | +0.0533 | −0.0267 | pass |
| glm-5.3-prime | −0.0133 | +0.2533 | +0.1600 | +0.1133 | pass |

One seat below tolerance on one axis → **quality gate FAIL** (worst-judge
binds; the other two seats passing does not rescue the gate).
Stage-18 run `18-red-dot-confirm/run_20261022T035413Z`.

### Stage 19 — dual gates (n=10 paired runs)

Speed ratios vs the BF16 baseline (A); B = stock FP8, C = winning recipe.
CI lower bounds by the frozen paired bootstrap (100,000 resamples, seed
20262002 — see REPRODUCE.md).

| gate | definition (frozen code) | frozen line | result | outcome |
|---|---|---|---|---|
| migration | CI lower bound of B/A | ≥ 1.20 | **1.4433** (mean 1.4589) | **PASS** |
| recipe | CI lower bound of C/A | ≥ 1.50 | **1.2918** (mean 1.3033) | **FAIL** |

Recipe gate outcome = performance FAIL ∧ quality FAIL → **cell verdict FAIL**
(`straddle=false`).

## Why the confirmation phase was not executed (ADDENDUM-18)

1. The confirmation phase exists to certify a strong claim (success) — its
   purpose is to prevent "tune in the lab until the line is crossed, then
   claim one success." A failure claim carries no corresponding incentive;
   one clean development-phase failure is publication-grade.
2. The v4.2 no-rerun rule is symmetric: voiding or rerunning requires
   contemporaneous provider-outage evidence; rerunning after a FAIL would be
   a result-driven rerun — itself a violation. Running confirmation after a
   rehearsal FAIL is lose-lose: a repeated FAIL buys zero information, and a
   flipped PASS would be unpublishable under the rerun rule.
3. ADDENDUM-15 precedent: a cell result can be sealed as terminal with
   disclosure wording; the confirmation phase is not mandatory.

## Frozen-lines compliance

- **Adaptation edits: 0.** Two development-phase incidents were both
  halting-type (the pipeline stops rather than writes wrong numbers) and
  touched no measurement readings:
  - a staged-profile reuse error, corrected before measurement;
  - ADDENDUM-17 — stage-16 winner recipe-sha custody lookup skipped build
    rows (null sha); fixed to last-non-null wins. Scores and the screening
    verdict were byte-identical before and after the fix.
- **Interventions: 6 / 8** human actions, plus 1 machine row (ledger
  `interventions.jsonl`): panel handoff (Appendix A intervention #2,
  ADDENDUM-16), three development ignitions, the profile-reuse correction,
  and the ADDENDUM-17 defect-fix ceremony.
- **Wall clock**: development phase 2 h 52 m (ignition 2026-10-22T02:16:14Z,
  completion 05:08:46Z); the development phase is untimed per protocol and
  fully recorded. The confirmation-phase budget (72 h, ≤2 attempts) was
  reserved and unused.

## Protocol errata (carried into this publication per governance decision)

- Protocol v4.2 §3 states "Migration gate: speedup CI lower bound ≥ 1.20× over
  stock FP8." The frozen implementation (stage-19, craft inherited from
  Pilot 004) computes **migration = stock FP8 ÷ BF16** and **recipe = winning
  recipe ÷ BF16** (FROZEN-LINES: `migration_ci_lower = 1.2`,
  `recipe_ci_lower = 1.5`). **Both gate denominators are BF16**; the §3 phrase
  is clarified to read "stock FP8 delivers ≥ 1.20× over BF16". This is a
  semantic clarification only: no code, threshold, seed, or datum was changed,
  and no published or sealed result is affected. The same erratum appears in
  the cell-3 verdict publication.

## Custody anchors (public chain)

- Spec sha256 `da590e7e…`; verdict math recomputed from per-run measurement
  rows — see REPRODUCE.md for the full per-run table and the frozen algorithm.
- Recipe sha256 (b4-w2) `a9b66ffa…`; stage-16/18/19 run directories carry
  per-stage `custody.sha256` chains.
- Gate-layer parameters (profiling / smoothing / calibration values) remain
  trade-secret and pod-only by design; their sha256 is pinned into the custody
  chain without disclosure of content.
- Full raw evidence (per-request logs, judge transcripts, ledger) is archived
  in the evidence repository with sha256 custody; available on request for
  audit.

## Limitations

- Screening figures are indicative (single judge seat, n=40); gate results
  rest on stage-18/19 measurements only.
- The recipe gate has two legs — CI lower bound ≥ 1.50× over BF16, and
  quality non-inferiority under the worst-judge panel. The winning arm failed
  both legs. Nothing in this publication is a claim about other models, other
  GPUs, or other load anchors.
- This verdict is a property of the combination under the frozen process; it
  is not a statement that this model cannot be served faster by other means.
