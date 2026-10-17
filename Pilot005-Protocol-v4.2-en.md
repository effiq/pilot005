# Pilot 005 Protocol (Protocol Lock v4.2) — Public Engineering Edition

**Status**: DRAFT pending owner review. LOCKED upon publication to effiq/pilot005. This document is immutable after upload; changes happen only through numbered, timestamped addenda (public series starts at ADDENDUM-01).
**Lineage**: self-contained. Frozen disciplines carried over from Pilots 001–004 remain in force.

Pilot 005 tests one claim: **spec in, verdict out.** Given a spec file (model × GPU × load anchor), our pipeline produces a recipe, a configuration, and an audit-grade evidence pack — with **zero adaptation edits to pipeline scripts**. We prove it on three model cells we did not tune for in advance, on a single NVIDIA H100.

## 1. Cells

| Cell | Model | Why it is interesting |
|---|---|---|
| 1 (shakedown) | Qwen3-32B | Same family, larger size band: BF16 ≈64 GB sits near the 80 GB card boundary; the FP8 payoff structure should differ — a calibration generalization test. |
| 2 (verdict-bearing) | DeepSeek-R1-Distill-Qwen-14B | Reasoning-chain load: long CoT output stresses the decode phase; structurally different from chat workloads. |
| 3 (verdict-bearing) | Fanar-2-27B-Instruct | Arabic-sovereign model (Gemma-3 backbone); requires an Arabic-capable judge panel and an Arabic load trace — a pipeline-input change, not a pipeline-code change. |

Swap clause: should an open-weight, single-H100-hostable R2-distill (dense, ≤35B) appear before this protocol is uploaded, Cell 2 is replaced automatically, recorded as Addendum 0. **This clause expires at upload; after upload, cell composition is immutable — a later-appearing model can only enter a future pilot.** (Live-source check 2026-10-17: no qualifying release; clause not triggered.)

## 2. Objective 1 — Pipeline (engineering verdict, mechanical)

Each cell runs in two phases:

- **Development phase** (spec submission → rehearsal gate all green): **untimed**. Crashes, fixes, and interruptions are unrestricted and fully disclosed (duration, crash-fix counts). Development durations are published per cell and **must decrease monotonically** across verdict-bearing cells (Cell 3 ≤ Cell 2; Cell 1 disclosed as baseline). Failure to decrease means pipeline-ization was not achieved — the claim fails in public.
- **Confirmation phase** (owner declares entry after the rehearsal gate): **72 h continuous calendar clock** to verdict, simulating real delivery — machine runtime, queueing, and unattended hours all count. **At most 2 confirmation runs per cell**; the clock is cumulative across attempts and never resets. Every confirmation run is recorded and published in full.
- **Operator-SLA accounting**: inside the confirmation phase, waiting-for-operator events (mechanically timestamped by the run state machine, not self-reported) are billed at min(actual wait, 1 h) — simulating an on-call engineer in a real delivery. An operator-model and SLA accounting statement accompanies publication.
- Sole carve-out: a provider-level outage documented on the provider's public status page pauses the clock and is disclosed via addendum.
- Anti-gaming structure: the SLA value, the attempt cap, and the waiting-event rules are frozen with this protocol; changes go through addenda.

Rehearsal gate composition (all green required before any confirmation run): 0.5B dry-run full-chain regression green ∧ golden environment anchor landed ∧ Pilot 004 regression cell re-run byte-identical ∧ judge exam v2 finalized (firewall: finalized before any scoring data exists).

Verdict-bearing cells are 2 and 3. On both, from spec submission to verdict output:

- **Adaptation edits to pipeline scripts = 0** (git history as proof). Edits are ledgered in two classes: *adaptation edits* count toward this verdict; *defect fixes* go through the addendum ceremony, are disclosed, and are counted separately. **Classification is pre-declared and mechanical**: a fix qualifies as a defect fix only if (a) its addendum declares the classification *before* the fix is applied, and (b) it is model-agnostic — it reproduces on the frozen Pilot 004 regression cell, or its diff contains no model- or architecture-conditional logic. Any edit touching model-specific code paths is an adaptation edit, unconditionally. All model-specific variation must live in the spec file (data), never in pipeline code.
- **Manual interventions ≤ 8.** An intervention is any human-initiated action that alters run state (ignition confirmation, pod stop, uploads, decision points); passive observation does not count. **Automated watchdog actions inside the frozen playbook (including bounded auto-restarts) are machine actions — they do not count, and every occurrence is logged and published.** Each intervention is pre-registered in **Appendix A, published together with this protocol**.
- **Confirmation phase ≤ 72 h per cell** (cumulative, ≤ 2 attempts).
- **Development-phase durations monotonically decrease** (Cell 3 ≤ Cell 2).
- A marginal-delivery-cost curve against the Pilot 004 manual ledger is reported descriptively (not gated).

Any breached verdict line is a FAIL, published as such.

## 3. Objective 2 — Model-family coverage (scientific verdict, per cell)

Each cell is judged independently under the frozen Pilot 004 metrology:

- **Migration gate**: speedup CI lower bound ≥ **1.20×** over stock FP8.
- **Recipe gate**: CI lower bound ≥ **1.50×**, AND a quality gate (three-judge panel, worst-judge binding; overall and per-axis delta ≥ −0.1), AND tail-latency non-inferiority within **5%**.
- Statistics: n=10, no straddle, paired bootstrap 100,000 resamples (seed 20262002), screening advance margin 0.05 — carried over from Pilot 004 (frozen craft). Run validity is mechanical and symmetric: a run contaminated by a provider incident documented contemporaneously on the provider's public status page is voided and rerun, with disclosure; without such evidence, every run counts as measured.
- Profile priors: reuse permitted **within a model family** (Cell 2), fresh profiling **across families** (Cell 3); reuse-or-not is itself hypothesis H2's test material.
- PASS (for Objective 2) means: every selected cell reaches a published verdict (PASS or FAIL both count as completion) with zero pipeline-script edits in every cell.

**Cell 3 specifics**: Arabic-capable judge panel; rubric authored natively in Arabic (no translated rubrics); MSA-only scope, dialects explicitly out of scope — deliberate scope honesty: dialect judging is unreliable in the current literature, and we prefer a narrow claim we can defend over a broad one we cannot; tokenizer-fertility differences disclosed descriptively in each VERDICT (within-cell B/A ratios are fertility-immune by construction).

## 4. Judge panel and calibration gate (exam v2)

- Panel: current-generation flagship judges from three independent vendors, plus a pod-local judge (Qwen3-32B) as a byte-reproducible anchor. Exact seats are listed in Appendix B. **The replacement pool is pre-registered as an ordered list**: seats are filled in fixed order, stopping at the first pass — never shopping until a convenient panel emerges. **All calibration results, including failures and seat replacements, are published in the VERDICT appendix.** If the pool is exhausted, the pod-local judge steps in and the calibration-gate status is disclosed as a limitation.
- **Calibration before adjudication ("judges are examined first")** — exam v2 (frozen prescription): the completeness axis uses **constructive labels** (paired complete/rule-abridged answers; ground truth carried by construction, abridgement rule disclosed per item); clarity and overall use high-contrast items; 24 items per axis; parallel EN and AR papers (Cells 1–2: EN; Cell 3: AR, human-annotated Arabic reference samples); pass threshold **category-level r ≥ 0.80**; three-tier pool; first-pass-stops. **Firewall: the exam is finalized before any scoring data exists.** Exam v1 was retired after its verbosity-proxy miscalibration was diagnosed (four live rounds, all seats failed completeness while other axes passed — instrument defect, not judge incapacity); the diagnosis is published with the exam v2 artifact.
- Three-judge ensemble voting; worst judge binds the quality gate.
- Cell 3 is judged on MSA only; dialects are out of scope and disclosed as such in the VERDICT.

## 5. Objective 3 — High-load frontier mapping (exploratory, descriptive, ungated)

On the existing Qwen2.5-14B × H100 cell, concurrency is pushed beyond the calibrated operating point to map the shape of the overload throughput/latency frontier. Output: frontier curve + inflection position (descriptive only; feeds no verdict). Kill condition: if overload behavior proves non-reproducible (instrumentation cannot anchor it), we record and stop.

## 6. Publication policy (frozen in advance)

- Every cell verdict is published **whether PASS or FAIL**. This policy is frozen before any run — selective disclosure is not available to us.
- Semantics are pinned: **a FAIL is a negative lab report, not a confession.** It states that, *under the pre-registered process, budget, and statistical discipline*, the ≥1.50× lossless-speedup test on *this model × quantization × hardware combination* came back negative. Effiq stands behind the rigor and reproducibility of the verdict; a negative result is neither a defect verdict on the model nor a capability verdict on Effiq — it is a compressibility fact about the combination under the frozen process. (The "under the pre-registered constraints" qualifier is mandatory: we never claim impossibility, only a scoped negative.)
- Misreading guards apply **uniformly to every cell**: FAIL headlines never carry a model name (every verdict, model name, and datum appears in full in the body; the headline rule prevents misreading, never reduces disclosure); the first sentence of the body pins the subject semantics; quality-gate wording is combination-precise.

## 7. Stop-loss scripts (pre-registered, no appeal)

- Pipeline regression failure on the Pilot 004 cell (re-run diverges from frozen conclusions) → full stop and instrument autopsy; disclosed.
- Double FAIL on the shakedown cell → single-cell FAIL published as usual; the pipeline objective is judged independently of scientific outcomes.
- Confirmation phase exhausted (2 attempts) without clearing a post-rehearsal gate → the cell is a FAIL, published as usual (the clock never resets; "crash and restart" is not free).
- All three cells FAIL → kill-page review: autopsy plus three options (fix and retry / contract to single-cell craft / dignified burial).
- Evidence-chain contamination anywhere → the batch is voided and disclosed.

## 8. Disclosure layers

Public: cell verdicts, VERDICT, REPRODUCE, this protocol, pipeline scripts (including the watchstanding tooling), raw logs, hash chains, envelope charts; the *existence* of the spec-file schema, lever-category labels of arms, recipe sha256.
Gated (pod-only): recipe bodies, profile thresholds, private parameter segments of spec files.
Private: detailed costs, ledgers, pricing, partners.

## 9. Continuity with Pilot 004

All Pilot 004 verdicts stand permanently — never re-opened, never diluted. The Qwen2.5-14B × H100 cell serves only as the pipeline regression reference (a re-run must reach byte-identical conclusions; a regression failure halts the line — see §7). All Pilot 004 frozen disciplines carry over: protocol before execution, addendum-first changes, sealed statistics, worst-judge panel, kill-page no-appeal, and the Publication SOP as delivery machinery.

## Appendix A — Pre-registered manual interventions (per cell)

| # | Pre-registered intervention |
|---|---|
| 1 | Cell ignition confirmation (owner's explicit go) |
| 2 | Gate-layer file placement and verification (cell spec-private segment + recipe pack) |
| 3 | Confirmation-phase entry declaration (after rehearsal gate all green) |
| 4 | Verdict countersignature (mechanical verdict + owner confirmation) |
| 5 | Pod termination (between cells; never automated) |
| 6 | Budget top-up (conditional — only if a cap is hit) |
| 7–8 | Contingency reserve (disclosed as "unused" if untouched) |

Cap: 8 per cell. Exceeding the cap is an Objective-1 FAIL for that cell, published as such. Passive observation and frozen-playbook machine actions do not count.

## Appendix B — Judge panel ordered pools (JUDGES.json v4.2, published with this protocol)

All candidate IDs live-verified against the judge-serving API's model endpoint on 2026-10-17:

- **Chief seat**: `qwen/qwen3.8-max-0902` → fallback `qwen/qwen3-235b-a22b-2507` (Cell 3 locks the Arabic-capable chief directly to the latter).
- **Second seat**: `deepseek/deepseek-v3.2` → fallback `deepseek/deepseek-chat-v3.1` → `deepseek/deepseek-chat-v3-0324`.
- **Third seat**: `moonshotai/kimi-k2.6` → fallback `z-ai/glm-4.6` (first to clear the calibration gate takes the seat).
- **Local anchor**: pod-local Qwen3-32B (byte-reproducible; not a voting seat; steps in only if pools exhaust, disclosed as a limitation).

## Appendix C — Frozen-artifact hash record

| Artifact | sha256 |
|---|---|
| Pipeline scripts (curated clean tree; per-file hashes in MANIFEST.sha256) | ae8e2901719f11480720cce271af59e8cce30560d00188f8372be77caa6b64c9 (manifest) |
| FROZEN-LINES.json (v4.2 verdict lines) | 18ffa911fd7c65878eb581deb04020d148188cb68bc5a21638921f8aeadcade0 |
| JUDGES.json (v4.2 Appendix B entity) | 4a08e13a3e436bf5369450a469d26719baed1b0cedb06cbd183043abb6a4b984 |
| Judge exam v2 (EN + AR papers) | backfilled via addendum upon finalization (firewall: before any scoring data) |

---

*This is the public engineering edition. Internal parameters that are commercially sensitive (costs, ledger, partners) are intentionally absent — not hidden behind vagueness, but out of scope of this layer.*
