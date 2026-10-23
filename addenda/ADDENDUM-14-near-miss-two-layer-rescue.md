# ADDENDUM-14 — Two-Layer Rescue for Near-Miss Candidates (429 Redelivery Layer + Empty-Reply Guardrail Re-Ask Layer)

**Status:** SEALED — owner first ruled plan C on 2026-10-22, then approved merged execution of both layers
**References:** ADDENDUM-12 (legal basis for 402 undelivered redelivery); ADDENDUM-13 (same-family tier, four candidates failed); operations-log record 115

## Background

After all four ADDENDUM-13 tier candidates failed, the archived error rows were autopsied line by line (originals in seating-run-20261021/):

| candidate | errors | composition |
|---|---|---|
| deepseek-v4-pro-0813 | 2 | 2 × unparseable-or-empty (raw=None), same item r1-en-corr-47, both orientations |
| deepseek-v4.1-flash-1017 | 2 | 2 × unparseable-or-empty (raw=None), same item r1-en-corr-47, both orientations |
| qwen3.8-max-prime | 3 | 2 × unparseable-or-empty (same item r1-en-corr-47, both orientations) + 1 × HTTP 429 |
| glm-5.3-prime | 3 | 3 × HTTP 429 (still rate-limited after retries=3, raw=''), **zero genuine format errors** |

The two error classes differ in law:

- **HTTP 429 is transport-layer non-delivery**, same legal basis as the 402 in ADDENDUM-12 — the request never reached the judge; one redelivery is not re-judging;
- **an empty reply is output-layer underperformance by the model**. Owner ruling of 2026-10-22 (plan C): grant one "guardrail re-ask" — append a fixed format reminder to the original prompt and raise max_tokens; re-ask once; the landed rows carry a disclosure star.

## Clauses

1. **429 redelivery layer:** every HTTP 429 error row (qwen-prime 1 row, glm-prime 3 rows) is redelivered once with the original prompt and parameters; new rows land with `rescue="redelivery-429"`; if they still fail, the FAIL stands with no further make-up.
2. **Guardrail re-ask layer:** for empty-reply rows with error='unparseable-or-empty' (v4-pro 2 rows, v4.1-flash 2 rows, qwen-prime 2 rows), append the fixed reminder ("Reminder: reply with exactly one letter — A, B, or T. No explanation.") to the original prompt, raise max_tokens 4096→8192, keep temperature 0 and all other parameters unchanged, and re-ask once; new rows land with `rescue="guardrail-reask"`. If a candidate passes through this layer, the certification conclusion must carry the "output guardrail" disclosure star; if still unparseable, the FAIL stands.
3. **Order and seating:** rescue proceeds in pool order — v4-pro → v4.1-flash → qwen-prime → glm-prime. After each candidate's rescue the summary is recomputed; **the first candidate reaching τ=70 four-axis binding + zero errors takes the third seat and rescue stops immediately** (first-pass-seating invariant, inherited from ADDENDUM-10/11/13).
4. **No-verdict-change principle:** every row that already holds a verdict stays byte-untouched; rescue replaces error rows only. Before merging, pre-rescue snapshots of all four candidates' original archives are pushed to the archive (inheriting the ADDENDUM-12 snapshot precedent).
5. **Disclosure wording:** a pass via the guardrail layer = starred certification (the deliverable states the row count and the mechanism); a pass via the 429 redelivery layer = bare-model certification, with only a footnote recording the transport redelivery. The family-concentration clause (ADDENDUM-13 §2) remains load-bearing.
6. **Budget:** total rescue calls ≤ 10; the cost is negligible and the credit position at execution time was sufficient.
7. Only if all four candidates still fail after rescue does the pool_exhausted local-anchor clause apply (one seat filled + disclosure).
