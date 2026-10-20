# ADDENDUM-07 — Remedy Amendments and Calibration Exam v2 Errata

**Status:** RATIFIED by owner 2026-10-20
**Date:** 2026-10-20
**Amends:** ADDENDUM-05 (remedies §4; audit trigger §5) — by amendment record, sealed text untouched
**References:** ADDENDUM-05 (decision tree), ADDENDUM-06 (pool expansion), stage-14 re-examination archives of 2026-10-20 (pilot-logs: run_20261020T083828Z, run_20261020T095516Z, run_20261020T110320Z, run_20261020T122102Z, makeup-gemini-20261020)

## 1. R2 (power hardening) is abolished

By owner ruling of 2026-10-20, remedy **R2 is removed from the remedy menu** of ADDENDUM-05 §4.

Rationale (archived diagnostic, analysis of already-collected run data only): the observed failure mode is a measurement-object mismatch and label-source construct defects (§3), not statistical noise. R2 treats only noise; enlarging the exam cannot repair a mis-specified measurement object. Revival of R2 by any party requires a fresh pre-registration.

## 2. The §5 human re-label audit path is closed

By owner ruling of 2026-10-20, the human re-label spot-check (ADDENDUM-05 §5) will not be executed. The project adopts a standing design rule: **no human-subjective scoring enters any instrument of this pipeline** — label direction must be established by construction, not by opinion.

Consequence, recorded honestly: exam v2 thereby loses its only pre-registered acquittal channel. It can no longer be cleared; it can only be replaced. The replacement path is R1 (ADDENDUM-05 §4), unchanged.

## 3. Errata recorded against calibration exam v2

The following instrument defects are recorded as errata, established from PROVENANCE.json and the archived run data:

1. **Proxy-axis construct mismatch.** The exam's *completeness* axis is sourced from the source dataset's *verbosity* axis (disclosed as a proxy at construction time). Verbosity is not completeness; the axis measures a different construct than its name and rubric claim.
2. **Borrowed coarse-tier labels.** The gold labels are crowd-sourced Likert 0–4 ratings from a public dataset, linearly stretched to 1–10 (1 + 2.25·v), leaving only 4–5 discrete label tiers. Judges scoring on a continuous 1–10 scale are structurally penalized against coarse tiers.
3. **Measurement-object mismatch (diagnostic finding).** The gate measures absolute calibration against the borrowed labels (per-axis Pearson r), while the production verdict requires pairwise discrimination (is the fixed version better than the original). Archived evidence: all four newly registered flagship judges score median worst-axis r of 0.64–0.73, while their pairwise ordering accuracy on item pairs with gold separation ≥ 3 is 0.90–0.97 on every axis.

## 4. Binding requirement for the replacement instrument (R1 design rule)

The R1 instrument shall establish every item's comparison direction **by construction** (e.g., a response with required content removed is definitionally less complete), such that no subjective labeling is needed at any stage — construction, calibration, or operation. Its threshold is justified a priori with the simulation self-check required by ADDENDUM-05 §4 (must pass a mediocre judge and fail a weak one).

## 5. What does not change

- ADDENDUM-05 red lines stand: the r ≥ 0.80 gate of exam v2 is never loosened; no self-trained judge, ever; no metric change decided after data — the R1 argument document is sealed before any new data is collected.
- Exam v2, its archives, and all calibration results including failures remain published in full per Protocol Lock v4.2.
- Panel seating remains frozen at LOCAL-FALLBACK with disclosed limitation until a replacement instrument clears its own gate under its own sealed pre-registration.
