# Pilot 005 — Cell Verdict Publication: FAIL (screening-exhausted)

> Headline rule (v4.2): FAIL headlines never carry a model name. The cell
> identifier below references the pre-registered spec, which has been public
> since Protocol Lock (specs/cell3-fanar-2-27b.json).

- **Cell**: cell3-fanar-2-27b — spec sha256 `d7a72701561f0e2cab59cd4316b2e16412f54b4e895c13b20c06274d42ca1f51`
- **Verdict**: **FAIL** — screening-exhausted
- **Verdict record**: `VERDICT.json`, 2026-10-22T17:32:08Z
- **Phase**: development. The confirmation phase was never entered: under the
  frozen proceed rule, screening exhaustion terminates the cell before any
  formal measurement. No stage-18/19 data exists for this cell.

## Semantics (verbatim from the verdict record)

> Under the pre-registered process, budget, and statistical discipline, the
> lossless-speedup test on this model × quantization × hardware combination
> returned this result. A negative result is neither a defect verdict on the
> model nor a capability verdict on Effiq — it is a compressibility fact about
> the combination under the frozen process.

## What was measured (screening stage — indicative)

Per-axis mean deltas vs the BF16 reference generation (negative = worse than
reference). Blinded items n=40 per arm; **single indicative judge seat**
(qwen3.8-max-prime), per protocol the screening phase is indicative — the
calibrated three-judge panel (stage-14 calibration: COMPLETE) governs stages
18/19, which never ran.

| arm | clarity | correctness | completeness | overall |
|---|---|---|---|---|
| b4-w2 (wave-2 merge; screening winner) | −0.200 | −0.375 | −0.250 | −0.225 |
| b3-a4-kv | −0.500 | −0.525 | −0.550 | −0.550 |
| b1-profile-exempt | −0.525 | −0.750 | −0.625 | −0.675 |
| b2-smooth-exempt | −3.375 | −2.700 | −2.300 | −2.225 |
| b0-control (stock FP8; wave-1 only, not a candidate) | −0.550 | −0.350 | −0.225 | −0.225 |

Frozen proceed bar: winner clarity delta ≥ −0.05
(FROZEN-LINES `screening_proceed_margin`). Winner b4-w2 at −0.200 →
`proceed=false` → legitimate negative outcome, cell terminated. The verdict
logic is recomputed from this table in REPRODUCE.md.

## Descriptive observations (ungated, no verdict weight)

- The stock-FP8 control (b0) scored −0.55 on clarity: on this Arabic-native
  27B model, **plain FP8 migration itself carries a quality cost of the same
  order as the recipe arms**. The screening result is a property of the
  combination, not of any single recipe.
- The deterministic wave-2 merge (b4-w2 = merge of b3-a4-kv and
  b1-profile-exempt) improved clarity from −0.500 to −0.200. Recorded as a
  direction signal for future pre-registration; it is not a gate result.
- Literature context: that quantization disproportionately harms
  non-Latin-script languages is established (Marchisio et al., *How Does
  Quantization Affect Multilingual LLMs?*, EMNLP Findings 2024). To our
  knowledge (literature search dated 2026-10-22), no public measurement exists
  for FP8 dynamic quantization with FP8 KV cache on an Arabic-native 27B model
  under a pre-registered blind-judge protocol; this cell's screening data is,
  in that scoped setting only, a first published measurement. This is a
  bounded claim about a specific setting, not a general priority claim.

## Frozen-lines compliance

- **Adaptation edits: 0** (public git history of `pipeline/`).
- **Interventions: 3 / 8** (ledger `interventions.jsonl`): three ignition
  confirmations. Automated watchdog actions are machine actions — logged and
  published, not counted.
- **Attempts**: attempt-1 was sealed before any measurement (intervention-cap
  breach, 9 > 8; ADDENDUM-20) — no measurement data exists from attempt-1.
  Attempt-2 carried the cell from ignition (2026-10-22T14:49:51Z) to verdict
  (17:32:08Z), wall clock 2 h 43 m.
- **Defect fixes** (disclosed under the addendum ceremony; classification
  declared before application; both model-agnostic — no score, winner, or gate
  logic altered):
  - ADDENDUM-19 — llmcompressor implicit processor init fails on text-only
    checkpoints whose `model_type` maps to a multimodal AutoProcessor; the
    tokenizer is now passed explicitly (llmcompressor's own prescribed remedy).
  - ADDENDUM-21 — stage-16 winner recipe-sha custody lookup assumed a compose
    row that gate-file arms never write; the sha is now resolved from the gate
    recipe with the same canonical form and the custody row is completed.

## Protocol errata (carried into this publication per governance decision)

- Protocol v4.2 §3 states "Migration gate: speedup CI lower bound ≥ 1.20× over
  stock FP8." The frozen implementation (stage-19, craft inherited from
  Pilot 004) computes **migration = stock FP8 ÷ BF16** and **recipe = winning
  recipe ÷ BF16** (FROZEN-LINES: `migration_ci_lower = 1.2`,
  `recipe_ci_lower = 1.5`). **Both gate denominators are BF16**; the §3 phrase
  is clarified to read "stock FP8 delivers ≥ 1.20× over BF16". This is a
  semantic clarification only: no code, threshold, seed, or datum was changed,
  and no published or sealed result is affected. The same erratum appears in
  the cell-1 and cell-2 verdict publications.

## Custody anchors (public chain)

- Spec sha256 `d7a72701…`; screening run `16-arm-screening/run_20261022T150121Z`.
- Recipe sha256: b1 `3a58a496…`, b2 `67076a3b…`, b3 `49717167…` (resolved per
  ADDENDUM-21), b4-w2 `085ee89d…`.
- Checkpoint sha256: b1 `412863ba…`, b2 `033243bd…`, b3 `bfb93729…`,
  b4-w2 `705ad4a7…`. Per the build-hash-delete custody design, b1/b2
  checkpoint bytes were deleted after scoring; their shas remain the anchors.
- Judge custody: rubric `0ef82297…`, blind set `199b1883…`, panel `dcc537da…`.
- Gate-layer parameters (profiling / smoothing / calibration values) remain
  trade-secret and pod-only by design; their sha256 is pinned into the custody
  chain without disclosure of content.
- Full raw evidence is archived in the evidence repository with sha256
  custody; available on request for audit.

## Limitations

- Screening figures are indicative (single judge seat); no formal panel
  adjudication took place.
- No throughput or latency measurements exist for this cell; nothing in this
  publication is a performance claim.
- Cell-3 scope is MSA-only by pre-registration; dialects are out of scope.

## What follows

A follow-up cell on this model family, with redesigned recipe arms informed by
the wave-2 merge direction, will be pre-registered before any measurement.
No outcome is promised; whatever the next cell returns will be published
under the same frozen rules.
