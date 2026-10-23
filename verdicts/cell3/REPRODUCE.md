# Pilot 005 — Cell-3 Verdict: Recomputation Sheet

Cell-3 terminated at the screening stage: the verdict is a logic result, not
a speed measurement. Everything needed to recompute it is on this page.

## 1. Screening table (archived `screening_verdict.json`, run `run_20261022T150121Z`)

Per-axis mean deltas vs the BF16 reference generation; blinded items n=40 per
arm; single indicative judge seat (qwen3.8-max-prime). Negative = worse than
reference.

| arm | clarity | correctness | completeness | overall |
|---|---|---|---|---|
| b1-profile-exempt | −0.525 | −0.750 | −0.625 | −0.675 |
| b2-smooth-exempt | −3.375 | −2.700 | −2.300 | −2.225 |
| b3-a4-kv | −0.500 | −0.525 | −0.550 | −0.550 |
| b4-w2 (wave-2 merge of b3 + b1) | −0.200 | −0.375 | −0.250 | −0.225 |
| b0-control (stock FP8; wave-1 only) | −0.550 | −0.350 | −0.225 | −0.225 |

## 2. Verdict logic (frozen)

From `pipeline/FROZEN-LINES.json`: `screening_proceed_margin = 0.05`.

```
winner      = arm with the highest clarity delta (tie-break: overall, then name)
            = b4-w2, clarity −0.200
proceed     = winner.clarity >= −margin
            = −0.200 >= −0.05  ->  False
verdict     = proceed is False  ->  FAIL (screening-exhausted)
```

The cell therefore never enters stages 18/19: **no throughput, latency, or
formal panel measurements exist for cell-3**, and any document claiming
otherwise contradicts the custody record.

## 3. Custody anchors (public chain)

- Spec sha256 `d7a72701561f0e2cab59cd4316b2e16412f54b4e895c13b20c06274d42ca1f51`;
  verdict record `VERDICT.json` timestamped 2026-10-22T17:32:08Z.
- Recipe sha256: b1 `3a58a496…`, b2 `67076a3b…`, b3 `49717167…` (resolved per
  ADDENDUM-21), b4-w2 `085ee89d…` — the b4-w2 composition hash is
  byte-identical across the attempt-2 resume, demonstrating deterministic
  composition.
- Checkpoint sha256: b1 `412863ba…`, b2 `033243bd…`, b3 `bfb93729…`,
  b4-w2 `705ad4a7…`. Per the build-hash-delete custody design, b1/b2
  checkpoint bytes were deleted after scoring; their shas remain the anchors.
- Judge custody: rubric `0ef82297…`, blind set `199b1883…`, panel `dcc537da…`.

## 4. What is not on this page

- Blinded item texts, judge transcripts, and per-item scores are archived in
  the evidence repository under per-stage `custody.sha256` chains; available
  on request for audit.
- Gate-layer recipe parameters (profiling / smoothing / calibration values)
  are trade-secret by design; their sha256 is pinned in custody without
  disclosure of content.
