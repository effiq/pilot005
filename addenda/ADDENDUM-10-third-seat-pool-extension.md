# ADDENDUM-10 — Third-Seat Pool Extension (Overseas Flagship Backstop)

**Status:** SEALED — owner ratified 2026-10-21
**References:** ADDENDUM-06 (cross-seat registration precedent); JUDGES.json (frozen ordered pools); ADDENDUM-08 (R1 instrument)

## Background

The pre-registered third-seat pool (kimi-k2.6 → glm-4.6) was exhausted on 2026-10-21 10:51:59Z: both candidates scored above the τ=70 line (Kimi 96/77/76.5/96; GLM 96/86/83/91.5) but failed the zero-error rule with 22 and 11 format errors respectively, and SEAT-UNFILLED was recorded. Design review confirmed the third-seat pool had no overseas-flagship backstop — a pool-construction omission of the same class as the pre-ADDENDUM-06 chief/second pools.

## Clauses

1. Three candidates are appended to the third-seat pool tail, in order: **google/gemini-4-argon → x-ai/grok-4.7 → mistralai/mistral-large-4-0**. All three were verified live on the OpenRouter /models endpoint on 2026-10-21 (mistral-large-4-0 supports the reasoning parameter; contract wiring is unaffected).
2. The existing in-pool order is unchanged; the already-judged results for kimi-k2.6 and glm-4.6 are retained in the archive in full — **no re-judging, no score shopping** (the never-shopping principle applies unchanged).
3. Appended candidates run the identical seating exam: same instrument (768-item queue = 384 std + 96 probe), same contract (SPEC-PAIRJUDGE-v5.0), same τ=70 four-axis binding + zero-error rule, same retry policy; first pass takes the seat; every result including FAIL is archived and published.
4. If all three appended candidates fail, the pre-registered pool_exhausted clause applies: the pod-local anchor (Qwen3-32B) fills the seat and the limitation is disclosed in the deliverable.
5. Budget basis unchanged: billing is per call, 480 judgments per candidate, no additional call category.

## Invariants confirmed

- Frozen pool order: untouched.
- Archived judgment rows: reused verbatim, zero re-judging.
- Instrument and contract: untouched.
- Disclosure duty: all results (including FAIL) enter the VERDICT appendix, unchanged.
