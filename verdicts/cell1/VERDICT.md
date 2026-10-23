# Pilot 005 — Cell-1 Baseline Publication: PASS (shakedown cell, non-verdict-bearing)

> Cell-1 is the shakedown cell: under Protocol v4.2 §2 its result is not
> counted in the pilot verdict line. It is published as a baseline record,
> with the disclosure caveats below in full. Those caveats are load-bearing
> (ADDENDUM-15) — please read them before quoting any number on this page.

- **Cell**: cell1-qwen3-32b — spec sha256 `dbfce256406fed506cb806d7dc197ec19d7622ad697c03f03f9c1e4573359ba9`
- **Result**: **PASS** on all frozen gate lines (confirmation-phase run)
- **Verdict record**: `VERDICT.json`, stage-19 run `run_20261018T005723Z`, n=10
- **Phase**: confirmation — declared 2026-10-18T00:57:23Z, completed
  01:35:03Z; one attempt; no interventions between declaration and
  completion; well inside the 72 h / ≤2-attempt rail.

## Semantics

This PASS is a property of one model × quantization × hardware combination
measured by the frozen instrument. It is not a pilot-level claim: Protocol
§2 assigns verdict-bearing status to cells 2 and 3 only.

## What was measured

### Stage 19 — dual gates (confirmation run, n=10 paired runs)

Speed ratios vs the BF16 baseline (A); B = stock FP8, C = recipe arm
(b2-smooth-exempt). CI lower bounds by the frozen paired bootstrap
(100,000 resamples, seed 20262002 — see REPRODUCE.md).

| gate | definition (frozen code) | frozen line | result | outcome |
|---|---|---|---|---|
| migration | CI lower bound of B/A | ≥ 1.20 | **1.5537** (mean 1.5685) | **PASS** |
| recipe | CI lower bound of C/A | ≥ 1.50 | **1.5395** (mean 1.5575) | **PASS** |

### Stage 18 — quality gate

Quality gate: **PASS** (tolerances −0.1 per axis and overall, worst-judge
binds). Assessed by a **single local-fallback judge seat** (so labeled in the
custody record), n=150 blinded items; overall delta +0.200. See caveat (a).

### Stage 16 — screening (indicative, n=40 per arm, same local-fallback seat)

| arm | clarity | correctness | completeness | overall |
|---|---|---|---|---|
| b4-w2 (wave-2 merge) | +0.275 | +0.325 | +0.150 | +0.200 |
| b2-smooth-exempt (**arm measured at stages 18/19**) | +0.225 | +0.275 | +0.125 | +0.150 |
| b1-profile-exempt | +0.175 | −0.175 | +0.075 | +0.025 |
| b3-a4-kv | −0.800 | −0.875 | −0.850 | −0.925 |

## Load-bearing disclosure caveats (ADDENDUM-15)

**(a) Judge arrangement.** Cell-1 was scored before the delta-calibration
instrument existed (ADDENDUM-08, 2026-10-21) and before the final three-judge
panel was constituted. All cell-1 quality figures — screening and stage-18 —
come from a single local-fallback judge seat, disclosed as a limitation in
the custody record itself. The final panel has never adjudicated any cell-1
artifact. **Per ADDENDUM-15, cell-1 numbers must not be compared on the same
scale as cell-2/3 results, which were adjudicated by the calibrated panel.**

**(b) Arm-selection flow.** Cell-1 ran before the ADDENDUM-02 defect fix
(2026-10-18). Under the pre-fix screening flow, the arm carried into stages
18/19 was the wave-1 winner (b2-smooth-exempt); the final screening table's
top-clarity arm — the wave-2 merge b4-w2 at +0.275 — was not the arm
measured. This is part of what a shakedown cell is for: cell-1 exposed the
defect, and the fix is registered in ADDENDUM-02 with later cells running
the corrected flow.

**(c) Registry completeness.** An earlier development-phase dual-gate run
exists in the evidence archive (2026-10-17, also PASS: migration CI lower
1.5677, recipe CI lower 1.5460). The confirmation-phase run published here is
the basis cited by ADDENDUM-15. Both runs' custody chains are archived.

## Frozen-lines compliance

- Confirmation phase: 1 attempt; zero interventions and zero code changes
  between phase declaration and completion (ledger `interventions.jsonl`).
- Development phase (2026-10-17, untimed per protocol): five ignitions; the
  defects exposed along the way are registered in the ADDENDUM-02 defect
  registry — that exposure is the shakedown cell's designated function.

## Protocol errata (carried into this publication per governance decision)

- Protocol v4.2 §3 states "Migration gate: speedup CI lower bound ≥ 1.20× over
  stock FP8." The frozen implementation (stage-19, craft inherited from
  Pilot 004) computes **migration = stock FP8 ÷ BF16** and **recipe = winning
  recipe ÷ BF16** (FROZEN-LINES: `migration_ci_lower = 1.2`,
  `recipe_ci_lower = 1.5`). **Both gate denominators are BF16**; the §3 phrase
  is clarified to read "stock FP8 delivers ≥ 1.20× over BF16". This is a
  semantic clarification only: no code, threshold, seed, or datum was changed,
  and no published or sealed result is affected. The same erratum appears in
  the cell-2 and cell-3 verdict publications.

## Custody anchors (public chain)

- Spec sha256 `dbfce256…`; verdict math recomputed from per-run measurement
  rows — see REPRODUCE.md for the full per-run table and the frozen algorithm.
- Stage-16/18/19 run directories carry per-stage `custody.sha256` chains.
- Gate-layer parameters (profiling / smoothing / calibration values) remain
  trade-secret and pod-only by design; their sha256 is pinned into the custody
  chain without disclosure of content.
- Full raw evidence (per-request logs, judge transcripts, ledger) is archived
  in the evidence repository with sha256 custody; available on request for
  audit.

## Limitations

- Caveat (a) caps the evidentiary weight of every quality figure on this
  page: single uncalibrated local seat, not the calibrated panel.
- The PASS holds for this combination under this frozen process; it says
  nothing about other models, GPUs, or load anchors.
- Cell-1's PASS is a baseline disclosure, not a deliverable claim; the
  pilot's verdict rests on cells 2 and 3.
