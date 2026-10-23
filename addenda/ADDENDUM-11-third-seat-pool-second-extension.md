# ADDENDUM-11 — Third-Seat Pool Second Extension (Claude/MiniMax/Llama Tier)

**Status:** SEALED — owner ratified 2026-10-21
**References:** ADDENDUM-06; ADDENDUM-10 (pool-tail extension precedent); JUDGES.json; ADDENDUM-08

## Background

In the ADDENDUM-10 extension tier, gemini-4-argon (7 format errors) and grok-4.7 (5 format errors) failed in sequence, leaving mistral-large-4-0 as the last candidate of the existing pool. The owner ruled that a local-anchor fallback is not acceptable as the first-choice outcome and ordered the pool extended.

## Clauses

1. Four candidates are appended to the third-seat pool tail, in order: **anthropic/claude-opus-5.5 → anthropic/claude-sonnet-5.5 → minimax/minimax-m2 → meta-llama/llama-4-maverick**. All four were verified live on OpenRouter /models on 2026-10-21 (both Claude seats support the reasoning parameter, so contract wiring is unaffected; claude-opus-5.5 was registered-but-unexamined in the ADDENDUM-06 chief pool, and its cross-seat registration follows the ADDENDUM-10 precedent).
2. Activation condition: this tier engages automatically if mistral-large-4-0 fails; if mistral passes, this addendum stays dormant and is not executed.
3. Invariants inherit ADDENDUM-10 in full: in-pool order untouched; already-judged candidates zero re-judging and zero score shopping; same instrument / contract / τ=70 four-axis binding / zero-error rule / retry policy; first pass takes the seat; every result including FAIL is archived and published.
4. Only if this entire tier fails does the pre-registered pool_exhausted clause apply: the local anchor fills the third seat only (chief and second are already seated and unaffected), with the limitation disclosed in the deliverable.
5. Budget basis unchanged: billing per call, 480 judgments per candidate.
