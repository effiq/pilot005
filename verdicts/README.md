# Pilot 005 — Verdict Registry

This index is the complete registry of Pilot 005 cell verdicts. Registry
completeness is a hard rule: every cell that reached a verdict appears here,
whatever it returned. FAIL headlines never carry a model name (v4.2); cell
identifiers reference the pre-registered specs in `specs/`, public since
Protocol Lock.

| cell | spec | verdict | date (UTC) | publication |
|---|---|---|---|---|
| cell-1 | specs/cell1-qwen3-32b.json | PASS (baseline; non-verdict-bearing per Protocol §2) | 2026-10-18 | [cell1/VERDICT.md](cell1/VERDICT.md) · [REPRODUCE](cell1/REPRODUCE.md) |
| cell-2 | specs/cell2-r1-distill-qwen-14b.json | FAIL (recipe gate below line; quality gate FAIL) | 2026-10-22 | [cell2/VERDICT.md](cell2/VERDICT.md) · [REPRODUCE](cell2/REPRODUCE.md) |
| cell-3 | specs/cell3-fanar-2-27b.json | FAIL (screening-exhausted) | 2026-10-22 | [cell3/VERDICT.md](cell3/VERDICT.md) · [REPRODUCE](cell3/REPRODUCE.md) |

Pilot-level closure: [PILOT005-TOTAL-VERDICT.md](PILOT005-TOTAL-VERDICT.md) — Pilot 005 closed 2026-10-23; the table above is the complete set of cell verdicts.

## How to read these

- Each verdict page quotes the verdict semantics verbatim and lists its
  frozen-lines compliance (adaptation edits, interventions, wall clock,
  defect fixes by addendum number).
- Each REPRODUCE sheet recomputes the verdict from published per-run rows
  with the frozen algorithm (`pipeline/stages/19-dual-gates.sh`,
  `pipeline/FROZEN-LINES.json`). Cell-1/2 speed gates reproduce bit-exactly;
  cell-3's verdict is a logic result recomputed from its screening table.
- Cell-1 carries load-bearing caveats (ADDENDUM-15): pre-delta-calibration
  judge arrangement, single local-fallback seat; its numbers are a baseline
  disclosure and must not be compared on the same scale as cell-2/3 results.
- All three publications carry the same Protocol §3 erratum: both gate
  denominators are BF16; the "over stock FP8" phrase in §3 prose is
  clarified, with no change to code, thresholds, seeds, or data.
- Raw evidence (per-request logs, judge transcripts, ledgers) is archived
  under sha256 custody in the evidence repository; available on request for
  audit.
