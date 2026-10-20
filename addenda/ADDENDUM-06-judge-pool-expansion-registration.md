# ADDENDUM-06 — Judge Pool Expansion Registration

**Status: RATIFIED — owner review 2026-10-19. Committed before any new-candidate calibration data.**

**Date:** 2026-10-19
**Governing documents:** Pilot005 Protocol Lock v4.2 (commit `39b92d19`), JUDGES-v4.2.json, ADDENDUM-01 (calibration exam v2), ADDENDUM-04 (sealed), ADDENDUM-05 (judge-examination decision tree; must be sealed before any new-credential probe — hard ordering constraint).

---

## 1. Purpose and firewall

The judge candidate pool is expanded by registering additional frontier model families. This registration is executed **before any calibration data involving the new candidates is produced**. The ordering chain is mechanical and non-reorderable:

1. ADDENDUM-05 sealed (owner ratification).
2. This registration committed to `effiq/pilot005`.
3. New-credential probe (reachability verification only; see §5).
4. Pinned model IDs recorded in the Execution Record (§9) and committed.
5. Only then: stage-14 seating re-examination per the frozen pipeline.

No step may be advanced ahead of a prior step. No examination content may be transmitted to any new candidate before step 4 is complete.

## 2. Background and evidence chain

- Current pool ceiling, empirically fixed: seven candidates, zero seats passed the r ≥ 0.80 calibration gate; full-exam run `run_20261018T060012Z` (pilot-logs commit `7bc89b8a`), scored-seat worst-axis r band 0.345–0.613.
- Anchor-probe full grid (384 calls, pilot-logs commits `98f9c7a`, `adff850`): ceiling band 0.65–0.77 across four anchored low-effort configurations; three single-axis passes (0.830 / 0.815 / 0.808) prove the gate is reachable, but no in-pool candidate passes all four axes simultaneously.
- Ruling (2026-10-18): the in-pool remedy set is exhausted; engineering state frozen; pool expansion is the remaining lawful lever, and any expansion requires this registration before the new candidates' first calibration data point.

## 3. Scope

Expansion only. No registered member of JUDGES-v4.2.json is removed or modified. The calibration exam (v2, EN sha256 `d42740d3…` / AR sha256 `20c80cce…`, registered via ADDENDUM-01), the gate threshold, the seating procedure, and the panel composition rules are all untouched.

## 4. New candidate families and selection algorithm

Four additional families are registered as candidates:

| Family | Intended tier of entry |
|---|---|
| OpenAI flagship (current GPT generation) | chief candidate |
| Anthropic flagship (current Claude generation) | chief candidate |
| Google flagship (current Gemini generation) | second candidate |
| xAI flagship (current Grok generation) | second candidate |

Because exact dated model IDs are mutable upstream, they are **not hard-coded in this document**. At probe time, for each family, the current flagship ID is selected from the live OpenRouter `/models` listing by this algorithm:

1. Enumerate listing entries whose `id` belongs to the family namespace.
2. Select the family's current flagship generation (latest dated general-purpose flagship; exclude preview/beta/mini/lite/nano variants unless no full flagship exists).
3. Record the exact ID, the listing snapshot sha256, and the probe timestamp in the Execution Record (§9).

If a family is unavailable at probe time (not listed, deprecated, or not callable under the active credential), it is recorded as EXCLUDED-UNAVAILABLE in the Execution Record and skipped — no substitution outside this algorithm is permitted without a new addendum.

## 5. Probe discipline

The probe verifies reachability only. Probe payloads must be trivial and must contain **no examination content** — a fixed non-exam ping (e.g., `Reply with the word OK.`) plus a minimal reasoning-parameter compatibility check per family (learning from the reasoning-budget incident, ADDENDUM-03). Probe raw responses are archived to pilot-logs as an operations record; they carry no calibration semantics.

Per-family reasoning-parameter policy (mandatory vs optional reasoning, effort routing) is determined at probe time from observed endpoint behavior and pinned in the Execution Record — same discipline as JUDGES-v4.2.json's per-model pinned parameters, now applied to the new families.

## 6. Seat and gate rules (unchanged, restated for completeness)

- Gate: Pearson r ≥ 0.80 on **all four axes** of calibration exam v2, computed by the frozen stage-14 implementation; worst-axis r is the seat criterion.
- Seating: frozen stage-14 serial procedure; first-pass-stops; panel tiers (chief / second / third) per Protocol v4.2; existing pool members remain eligible on equal terms with new candidates.
- If new candidates pass, panel composition follows the frozen tier rules. If none pass, ADDENDUM-05's pre-registered decision tree governs — no ad-hoc remedies.

## 7. Explicit non-changes

This addendum does not modify: the r ≥ 0.80 threshold; the exam (questions, rubric, axis definitions); the metric definition; the seating order logic; any cell spec; any verdict line; the intervention ledger rules; the wall-clock rules.

## 8. Failure governance

All post-probe outcomes — including marginal misses (worst-axis r ∈ [0.70, 0.80)), instability across runs, or total failure — route through ADDENDUM-05 §3's pre-registered branch criteria (per-axis cross-run range ≤ 0.10 / > 0.10) and its remedies. The prohibited moves remain prohibited: lowering the gate, editing the exam after seeing scores, swapping the metric outside its legal form, self-trained judges.

## 9. Execution record (filled at probe time, then committed)

```
probe_timestamp_utc:        2026-10-20, probe window 08:05-08:35 UTC
credential_ref:             vault:openrouter_key (contents never embedded anywhere)
models_listing_sha256:      8746c3e6c0855b80c12202ba69a35a6bef7e86f1977bdf85576772a851771d36
models_listing_retrieved:   2026-10-20, 470 entries, live source /models
pinned_candidates:
  openai:    openai/gpt-6-astra-pro    reasoning_policy: explicit effort pinned at call time (param accepted, verified)
  anthropic: anthropic/claude-opus-5.5 reasoning_policy: explicit effort pinned at call time (param accepted, verified)
  google:    google/gemini-4-argon     reasoning_policy: explicit effort pinned at call time (param accepted, verified)
  xai:       x-ai/grok-4.7             reasoning_policy: explicit effort pinned at call time (param accepted, verified; reasons by default)
excluded_unavailable:       none. Three families enforce egress-location-based availability
                            (platform-side policy); probe and all subsequent calibration
                            traffic originate from a supported egress on compute nodes.
                            Verified by differential probe across two egress locations.
probe_payloads:             non-exam content only ("Reply with the word OK."); no exam material transmitted
probe_archive_ref:          pilot-logs commit 7f2cc02a72ee26238bc22b323c8e8c176739780f
                            (full telemetry, sha256 7f7c1a50d41dba7f...)
```

## 10. Consequence chain after seating

1. If at least one seat is filled by a live API judge: stage-14 re-examination concludes per frozen rules; cell-1 confirmatory quality re-evaluation (registered pending item) is executed with the seated panel; cell-2 ignition evaluation is unblocked per protocol.
2. If zero seats are filled: ADDENDUM-05 branches govern; engineering remains frozen pending owner direction.
