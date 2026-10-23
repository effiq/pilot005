# Pilot 005 — Spec In, Verdict Out

**One claim, frozen in advance**: given a spec file (model × GPU × load anchor), the pipeline produces a recipe, a serving configuration, and an audit-grade evidence pack — with **zero adaptation edits to pipeline scripts**. The instrument is published before the first run; the verdict is mechanical.

Four model cells, one NVIDIA H100 (80GB), no advance tuning:

| Cell | Model | Why it is in the experiment |
|---|---|---|
| 1 | Qwen/Qwen3-32B | shakedown cell — exposes pipeline defects; not counted in the verdict |
| 2 | deepseek-ai/DeepSeek-R1-Distill-Qwen-14B | reasoning-family distill |
| 3 | QCRI/Fanar-2-27B-Instruct | Arabic-sovereignty model (Gemma-3 backbone), MSA-only |
| 4 | QCRI/Fanar-2-27B-Instruct | scope-extension cell — second same-rules attempt after cell-3 FAIL; enters via ADDENDUM-22 before any measurement |

## Frozen before ignition

| Artifact | What it pins |
|---|---|
| [Pilot005-Protocol-v4.2-en.md](Pilot005-Protocol-v4.2-en.md) | the full protocol — verdict lines, two-phase wall clock, judge calibration gate, intervention ledger, disclosure layers. Immutable after upload; changes only via numbered addenda (ADDENDUM-01 onward) |
| [addenda/README.md](addenda/README.md) | the numbered addendum registry — every Protocol-Lock change in order, with sealed/not-routed items marked |

Cell-4 enters Pilot 005 by numbered scope-extension addendum before any measurement; earlier cells remain byte-frozen.
| [pipeline/FROZEN-LINES.json](pipeline/FROZEN-LINES.json) | the verdict lines as data — the instrument, not the object |
| [pipeline/JUDGES.json](pipeline/JUDGES.json) | judge panel as ordered pools, pre-registered; all IDs live-verified |
| [MANIFEST.sha256](MANIFEST.sha256) | per-file integrity of the curated pipeline tree |

## What a verdict means

A cell **PASS**es only if all frozen lines hold: zero adaptation edits, ≤8 pre-registered interventions, confirmation-phase wall clock ≤72 h (≤2 attempts, cumulative), migration gate CI lower bound ≥1.20×, recipe gate ≥1.50× with quality non-inferiority (worst-judge panel) and tail latency within 5%. Any line broken = **FAIL**, published as-is.

A FAIL is a negative lab report: a compressibility fact about one model × quantization × hardware combination under this process — never a capability verdict on the model, and FAIL headlines never carry a model name.

The development phase is untimed but fully recorded; per-cell development durations are published and must decrease monotonically (cell 3 ≤ cell 2). Zero-edits claims without shrinking setup time would be empty.

## Verdicts

Three cells have reached terminal verdicts — see the
[verdict registry](verdicts/README.md): cell-1 PASS (baseline,
non-verdict-bearing), cell-2 FAIL, cell-3 FAIL. Each verdict ships with a
recomputation sheet: the speed-gate math reproduces bit-exactly from the
published per-run rows under the frozen algorithm.

## Layout

```
pipeline/            the instrument: run_cell.sh orchestrator, stages 14–19, verdict lines, judge pool, spec contract
specs/               the cell specs (model × GPU × load anchor) — all model variation lives here, as data
rubrics/             judge rubrics (EN / AR)
staging/             dry-run harness (disposable-GPU mechanics validation; produces no evidence)
verdicts/            the verdict registry: one VERDICT.md + REPRODUCE.md per cell
```

## Evidence flow

Run evidence (intervention ledger, wall-clock files, calibration results including failures, verdict math) streams to a separate logs repository throughout the run. Judges are examined before they adjudicate (calibration exam, category-level r ≥ 0.80), and all calibration results are published with the verdict.

## License

MIT — see [LICENSE](LICENSE).
