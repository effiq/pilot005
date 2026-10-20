# ADDENDUM-05 — Frontier-Judge Examination: Pre-Registered Decision Tree and Failure-Branch Remedies

**Status: SEALED — owner ratified 2026-10-19, before any new-candidate calibration data. Branch definitions (§3) and audit procedure (§5) frozen.**

**Timing discipline:** This document must be sealed **before** any calibration data from the newly registered candidates is collected (including credential-probe scoring runs). Branch definitions, fork criteria, and remedy-selection rules below are frozen in advance; no clause may be edited after the new candidates' judge data exists.

**Scope:** Pilot005 judge-calibration chain (stage-14). ADDENDUM-04 remains sealed and unaffected. The frozen instrument (exam v2), the gate (Pearson r ≥ 0.80, worst axis binds), and the ordered seating protocol are unchanged by this document.

## 1. Purpose

The open question is "pool ceiling or instrument defect": all four in-pool candidates failed, which is consistent with both a bounded candidate pool and a defective exam/gate construction. The newly registered flagship judge examination is a **decision experiment**. Its value is diagnostic under every outcome — provided the branches are drawn before the data arrives. This document draws them.

## 2. Baseline noise floor (measured, cited for fork criteria)

Three official full runs of stage-14 at temp=0 produced worst-axis r of 0.610 / 0.691 / 0.613 (max cross-run swing 0.081). This is service-side noise under deterministic settings, and it anchors the fork thresholds below.

Statistical context: at n=24 items per axis, the 95% CI of a true r=0.75 correlation spans [0.497, 0.885] (Fisher z, width 0.389); at n=48 it narrows to [0.592, 0.852] (width 0.260). The worst-of-4 binding at n=24 is statistically demanding: a genuinely qualified judge can fail by sampling noise alone. This is why power hardening (Remedy R2) is a real lever, not a placebo.

## 3. Pre-registered fork criteria

The newly registered flagship candidate(s) run the frozen stage-14 exam unchanged, with the existing repeated-run protocol (3 runs, temp=0). Let `worst_r` = worst-axis r per run, and `axis_range` = per-axis cross-run max-minus-min.

| Branch | Criteria (all quantitative) | Diagnosis | Remedy |
|---|---|---|---|
| **PASS** | Gate met per frozen stage-14 | Pool boundary confirmed; exam and gate vindicated | Seat per existing protocol; cells ②③ unlock. Case closed. |
| **FAIL-A** (narrow, stable) | Gate missed; worst_r ∈ [0.70, 0.80) on the median run; every axis_range ≤ 0.10 | Binding harshness / insufficient statistical power, not judge incompetence | **R2 first** (power hardening). Gate unchanged. |
| **FAIL-B** (broad, stable) | Gate missed; all four axis r < 0.70 on the median run; every axis_range ≤ 0.10 | Suspect instrument — **but not convicted**: scale compression is a cross-vendor RLHF artifact, so shared structural failure remains possible | **Exam audit first** (§5), then **R1** only if audit clears the exam |
| **FAIL-C** (noisy) | Any axis_range > 0.10 | Measurement noise dominates; no diagnosis possible at current power | **R2 first**; if noise persists after hardening, escalate to owner |

Mixed presentations (e.g., one axis noisy, others stable-low) resolve to the most conservative applicable branch (FAIL-B outranks FAIL-A; any noisy axis triggers FAIL-C handling for that axis's remedy scoping). Borderline values round toward the more conservative branch. No other interpretation is permitted.

## 4. Remedies (all lawful forms; none is a relaxation)

**R1 — Delta calibration (the lawful form of "change the measurement").**
Change the *measurement object*, not the ruler's tightness: the production gate needs **relative comparison** (is the fixed version better than the original), while exam v2 calibrates **absolute scoring** against human 1–10 labels. These are distinct capabilities; a mediocre absolute scorer can be an excellent pairwise blind judge. Exam v2's 24 constructed completeness pairs are precedent that pair-construction is feasible — but R1 requires entirely new harvested items (all old items retired), a new frozen spec version, a first-principles + literature argument **sealed before any data is collected**, pre-registration, and a new threshold justified a priori with its own simulation self-check (must pass a mediocre judge and fail a weak one). Executed this way, R1 is an instrument upgrade, not "retaking with an easier exam."

**R2 — Power hardening.**
Double items per axis (24 → 48) and adopt repeated measurement (k=3, median). The gate (r ≥ 0.80) is untouched. R2 treats only "noise drowning real ability"; it does nothing for "real ability insufficient." Branch selection between R1 and R2 is governed by §3, not by preference.

**R3 — Human blind-review seat (upgrade, not downgrade).**
The pipeline architecture already tolerates seat replacement (the Appendix B local fallback is precedent). Replacing the verdict seat with blind human raters is a channel replacement toward the gold standard, and does not violate the no-self-trained-judge rule. Pre-registered scope limits:
- **(a)** Human seats are for one-off verdict cells only (bounded: hundreds of pairwise comparisons). Continuous production gating still requires a machine judge — human latency/throughput cannot staff a standing gate.
- **(b)** Human raters are themselves calibrated: qualification items plus reported inter-rater agreement. The no-assumption rule applied to models applies equally to humans.
- **(c)** Circularity note: exam labels derive from harvested public annotations; agreement of blind raters with those labels is a standard inter-annotator agreement metric — lawful.
- Two-tier architecture: machine judges screen; blind humans adjudicate. A verdict line reading "adjudicated by blind human review" is stronger, not weaker, than "judged by API model."

**R4 — Judge-free floor (last resort).**
Quality gate re-hangs on objective benchmark deltas (standard eval sets + confidence intervals); LLM judges demoted to auxiliary. Maximally recomputable; insensitive to subtle quality regressions. Held as the final floor only.

## 5. Exam audit procedure (pre-registered, triggers on FAIL-B)

Before any metric change is proposed under FAIL-B: a human re-label spot-check of a pre-registered sample of exam items (sampling rule and sample size fixed at sealing time — proposed: 25% per axis, stratified by label tier, blind re-labelers disjoint from the original annotation source). If re-label agreement with the frozen labels is within the pre-registered tolerance, the exam is cleared and R1 may proceed; if not, the exam is defective and the remedy is exam reconstruction under full next-version ceremony — the gate and pool are not touched in either case.

## 6. Red lines (unchanged, restated for the pessimistic day)

1. The r ≥ 0.80 gate is never loosened.
2. No self-trained judge, ever.
3. No metric change may be *decided* after the new candidates' judge data is seen — the argument document is sealed first, data second.

## 7. Owner expectations (recorded)

The pass odds for flagship judges are not low (judge literature reports frontier-model/human agreement well above open-pool levels; an in-pool candidate already touched 0.830 on a single axis). But the design does not depend on that bet: the moat is not "a specific instrument passing," it is "an instrument passing under pre-registered discipline." Even the terminal script — "we measured and proved that API judges cannot reach the bar, sealed the data, published the argument, and moved to blind human adjudication" — is a credibility asset no competitor can copy.

## 8. Status

SEALED 2026-10-19 by owner ratification, before the new-credential probe and before any new-candidate calibration data. Branch definitions in §3 and the audit procedure in §5 are the load-bearing clauses; editing them after data exists voids this document.
