# Pilot 005 — Total Verdict and Closure

**Pilot 005 is closed.** Closing date: 2026-10-23 (UTC). This page is the pilot-level verdict record; it closes the registry without rewriting any cell publication.

## Final registry state

| cell | spec | verdict | publication |
|---|---|---|---|
| cell-1 | specs/cell1-qwen3-32b.json | PASS (baseline; non-verdict-bearing per Protocol §2) | [cell1/VERDICT.md](cell1/VERDICT.md) · [REPRODUCE](cell1/REPRODUCE.md) |
| cell-2 | specs/cell2-r1-distill-qwen-14b.json | FAIL (recipe gate below line; quality gate FAIL) | [cell2/VERDICT.md](cell2/VERDICT.md) · [REPRODUCE](cell2/REPRODUCE.md) |
| cell-3 | specs/cell3-fanar-2-27b.json | FAIL (screening-exhausted) | [cell3/VERDICT.md](cell3/VERDICT.md) · [REPRODUCE](cell3/REPRODUCE.md) |

The table above is the complete set of Pilot 005 cell verdicts.

## What the closed pilot establishes

- The instrument ran as published: cell specs were registered before measurement, verdict lines stayed frozen, and each terminal cell outcome was published with its recomputation sheet.
- Cell-2 and cell-3 are negative results under the frozen process. They are compressibility facts about their respective model × quantization × hardware combinations, not capability verdicts on the models.
- The published failure modes are part of the deliverable: cell-2 reached the dual gates and failed them; cell-3 terminated at screening exhaustion under the frozen proceed rule. Both outcomes remain in the registry.
- No claim in this closure extends beyond the registered specs, the H100 hardware class, and the published load anchors.

## Boundary statements

- This closure introduces no new thresholds, no new seeds, no new judging rules, and no new measurements.
- Recipe bodies, gate-layer parameters, partner details, and cost figures remain non-public by design.
- Future work starts from a new pre-registered pilot. Whatever it returns will be published under its own frozen rules.

## Custody

Raw evidence for cell-1, cell-2, and cell-3 remains archived under sha256 custody in the evidence repository and is available on request for audit.
