# ADDENDUM-12 — Redelivery Authorization for 402 Undelivered Rows (Lane-Incident Review)

**Status:** SEALED — owner order 2026-10-21 ("it is fixed now — proceed; Claude stays usable")
**References:** ADDENDUM-09/10/11; operations-log records 110/111 (the 402 storm)

## Background

From 2026-10-21 12:55Z the OpenRouter account credit hit its wall, and expensive/large requests were met with 402 Payment Required in volume (authorization estimate above remaining balance). Affected candidates: anthropic/claude-opus-5.5 (63 rows of 402), anthropic/claude-sonnet-5.5 (partial rows), minimax/minimax-m2 (81+ rows of 402). The credit position was replenished later that day and verified through the API.

## Classification (load-bearing)

A 402 row = **undelivered**: the request was refused at the authorization layer, never reached the judge model, and produced no judgment. Undelivered ≠ examined; redelivering an undelivered row is not "re-judging / score shopping" (never-shopping governs candidates that already hold judgments). Real judgment rows already produced (including genuine format errors) are retained verbatim, untouched.

## Clauses

1. A one-time "402-row removal + redelivery" is authorized on the three candidates' result archives: only rows whose error field contains "402" are removed (the removed count is logged per file); every other row is byte-untouched. On resumption the driver fills the missing items under the existing resume logic, at most one make-up judgment per item.
2. claude-opus-5.5's recorded attempt in panel.json is settled accordingly (its FAIL was already decided by 7 genuine format errors; the redelivery is for archive completeness and fair disclosure); claude-sonnet-5.5 is released from deferred state.
3. Instrument / contract / τ / zero-error rule / pool order are all unchanged; this addendum changes no candidate's final verdict logic.
4. The pre-removal archive state is pushed to GitHub first as evidence (evidence-first rule); removal and redelivery are logged end-to-end in progress.log.
