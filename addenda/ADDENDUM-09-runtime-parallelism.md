# ADDENDUM-09 — Runtime Parallelism (R1 Seating Exam and Future Judge Workloads)

**Status:** SEALED — owner ratified 2026-10-21, before any parallel execution. Sealed in pilot-logs sealed-addenda/ prior to the first parallel call; execution follows the seal, never precedes it.

## Trigger

Second-seat candidate deepseek/deepseek-v3.2 measured ~52 s per judgment (70/480 in 61 min, zero retries, one format error) — a ~7 h serial wall time for one candidate. Owner order of 2026-10-21: eliminate that seven-hour wait.

## Clauses

1. **Within-candidate parallelism.** The 480 judgments of a candidate are mutually independent; concurrency (default 8 workers) changes wall time only. The measurement is untouched: same item set (manifest faaafdf8fd9a2e522273ba0c1a8cd6b0d3d4c55581b1397ce9910dceff781321), same prompt contract, same parse rule, same τ=70/96 per axis, same zero-error rule, same retry policy (429/5xx/URLError → 20/40/80 s, max 3, recorded).
2. **Between-seat parallelism.** JUDGES.json freezes order *within* each seat's pool only. Seats are independent; they may be examined concurrently. First-pass-stops still applies inside each pool — never shopping, never skipping a candidate for any reason other than a recorded verdict.
3. **Slow-endpoint clause.** If a candidate's median call latency over its first 48 new judgments exceeds 45 s, concurrency for the remainder rises to 16 workers. Latency and worker counts are recorded in the run archive. No candidate may be skipped or reordered for slowness.

## Invariants preserved (verified at seal)

- Candidate order per pool: unchanged. Panel rule: unchanged.
- Already-archived judgment rows are reused verbatim — no re-judging, no double spending (v3.2's 70 archived rows carry over).
- Budget: unchanged call count; the pre-registered envelope is unaffected.
- Every judgment row still archived raw before aggregation.

## Execution record (filled after completion)

- ADDENDUM-09 applied from candidate deepseek/deepseek-v3.2 onward, with the second and third seats examined concurrently. Details in pilot005/cell1-qwen3-32b/calibration-delta/seating-run-20261021/.
