# ADDENDUM-22 — Scope extension: one additional cell under Pilot 005 (cell-4)

**Status**: RATIFIED — owner approved publication 2026-10-23. In force as of the change set that publishes this addendum and updates the README scope line from three to four model cells. This file adds scope; it does not rewrite any frozen artifact.

## 1. Purpose

Pilot 005 adds one scope-extension cell, cell-4, under the same frozen discipline. The purpose is a second, same-rules attempt on the Arabic-sovereignty cell after cell-3 ended in a registered FAIL (screening exhausted). The optimization artifact under test is a per-layer mixed-precision recipe plus its serving configuration and audit-grade evidence pack. Measurement exists to make the optimization claim checkable; it is not the product.

## 2. Scope change

The Pilot 005 registry changes from three model cells to four model cells. Cell-4 is an additional (model × recipe × hardware) claim under Pilot 005:

- Model: `QCRI/Fanar-2-27B-Instruct`, byte-pinned by 40-hex revision in the cell-4 public spec before any measurement.
- Hardware: one NVIDIA H100.
- Load anchor: declared Arabic MSA synthetic load; distributions, seeds, and generation limits are pinned in the cell-4 spec before any measurement.
- Gates: unchanged Pilot 005 gates; migration and recipe CI denominators are both BF16. Any older prose reading otherwise is errata context only.
- Quality gate: blind judge panel under the current frozen judging lineage; automatic precision software is reference context only and is never a verdict instrument.
- Speed-gate instrument cross-check: NVIDIA AIPerf may be reported in a separate VERDICT subsection under three firewalls — it is not the verdict statistic, it covers the speed gate only, and any disagreement never rewrites the verdict.

## 3. Cell-4 registration anchor (fields)

The public spec records: schema version; cell id; pilot and role; model repo_id and pinned revision; model family as evidenced by config; max_model_len; profile scope regex; hardware; load anchor declaration; generation settings; rubric file and sha256; anchor counts (frozen 150, screen 40, calibration texts 256); declared seed family; private-segment sha256; AIPerf alignment level and tolerance rule. Recipe bodies, lever parameters, sensitivity values, partner details, and cost figures are not public artifacts.

## 4. Non-changes

This addendum does not modify Protocol Lock v4.2 text; does not modify cell-1, cell-2, or cell-3 verdicts; does not modify FROZEN-LINES; does not introduce cost figures; does not activate frozen L2 levers such as TN/low-rank with healing; does not rate or rank external models.

## 5. Disclosure mechanism v2 note

Cell-4 is the first cell registered under disclosure mechanism v2. Research iteration remains private and unlimited; only a frozen candidate enters the verification track. Once registered, a verdict must be published whatever it returns. The default publication pack is recomputable evidence plus a one-page process summary, with full process archives available for audit. Pilot 005 keeps its flagship posture for verdict evidence while research trial-and-error remains private.

## 6. Effective order

No measurement may exist before this order is complete: (1) this addendum is published; (2) the root README scope line is updated from three to four model cells; (3) the cell-4 public spec anchor is registered with its pinned revision and private-segment sha256; (4) only then may pod ignition and any measurement run begin.
