# ADDENDUM-15 — Cell-1 Confirmatory Quality Re-Evaluation Cancellation and Baseline Disclosure Rule

**Status:** SEALED — owner ratified 2026-10-22
**Date:** 2026-10-22
**References:** Protocol v4.2 §1–2 (cell roles and verdict lines); duty-log records 115–116 (origin of the pending re-evaluation item and the three-seat panel); ADDENDUM-08; ADDENDUM-14

## Background

1. Cell-1 (Qwen3-32B) is the shakedown cell, not a verdict-bearing cell. Protocol v4.2 §2 makes cell-2 and cell-3 the verdict-bearing cells; cell-1 results are baseline disclosure only and enter no verdict line.
2. The cell-1 dual-gate verdict of 2026-10-18 (PASS: migration CI lower bound 1.5537 ≥ 1.20; recipe CI lower bound 1.5395 ≥ 1.50; quality gate PASS) was produced under the pre-delta-calibration judge arrangement. The final three seats (chief openai/gpt-6-astra-pro, second deepseek/deepseek-chat-v3-0324, third z-ai/glm-5.3-prime) had not scored any cell-1 artifact.
3. The real value of the queued "cell-1 confirmatory quality re-evaluation" was a first live-data exercise for the final panel: three-way agreement, end-to-end scoring chain, and worst-bind mechanics. That purpose is absorbed by the cell-2 rehearsal gate; a separate re-evaluation is not an additional safety net.

## Clauses

1. The cell-1 confirmatory quality re-evaluation is **cancelled** as of this sealing; cell-2 development may start without that prerequisite.
2. **Baseline disclosure rule (load-bearing):** every published cell-1 baseline number, including the 2026-10-18 dual-gate PASS, must be labelled "evaluated under the pre-delta-calibration judge arrangement (before ADDENDUM-08)" and must not be placed on the same scale as cell-2/3 results produced by the final panel.
3. The final panel's first live-data scoring, three-way agreement statistics, and worst-bind check are folded into the judge-scoring segment of the cell-2 rehearsal gate and disclosed there.
4. **Reversal clause:** if a future deliverable needs a cross-cell quality comparison on one scale, the re-evaluation obligation automatically returns — the final panel re-scores the archived cell-1 artifacts (judge-side work only; no GPU re-run), and that re-evaluation is disclosed in the deliverable.
5. This addendum touches no cell-2/3 pre-registered discipline, including the 72 h clock, ≤2 confirmation runs, zero adaptation edits, ≤8 manual interventions, and the mandatory watchdog and region prechecks.
