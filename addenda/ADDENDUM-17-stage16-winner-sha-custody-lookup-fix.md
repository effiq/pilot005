# ADDENDUM-17 — Stage-16 Winner Recipe-SHA Custody Lookup Fix (Defect-Fix Ceremony)

**Sealed:** 2026-10-22T03:45Z, during cell2-r1-distill-qwen-14b development
**Trigger:** stage 16 step 5 stopped on FATAL (`wave-1 winner recipe sha not in custody log`); default-deny watchdog alert at 03:28:04Z.

## 1. Defect

Two winner recipe-hash lookups in `stages/16-arm-screening.sh` (wave-1 line 436; wave-2 final line 517) walked `recipes_executed.jsonl` by `arm_id` and took the **last** row's `recipe_sha256`. The same arm has two row types in that file:

- compose rows, which carry `recipe_sha256`;
- build rows, which carry only `checkpoint_sha256` and no `recipe_sha256` field.

Build rows are written after compose rows, so the walk overwrote the value with null (`wsha=None`) and the stage stopped. The lookup was introduced by the ADDENDUM-02 defect fix of 2026-10-18 and **had never been executed on a real run after the fix** — cell-1 ran the pre-fix code (the defect itself wrote the string "None" into winner.json); cell-2 was the first execution of that path, exposing the fix's own regression.

## 2. Evidence (run_20261022T022413Z)

- `recipes_executed.jsonl` had five rows: compose-b1 (sha 116eea97…), compose-b2, and build-b1/b2/b3 (no `recipe_sha256`).
- `screening_verdict.json` had already landed before the FATAL: wave-1 winner b1-profile-exempt, clarity_delta −0.05, proceed=true (inside margin).
- After the fix, a sandbox-equivalent replay against the same real custody log resolved b1 → 116eea97831ea307… correctly.

## 3. Fix (pilot005 commit a01f9de, two lines)

Both lookups now skip rows whose `recipe_sha256` is empty (last non-null wins). Semantic invariants:

- winner-selection mathematics untouched (argmax clarity delta and the margin rule unchanged);
- no landed data touched (scores and verdict bytes unchanged);
- no model name and no architecture-conditional branch — the zero-adaptation-edit property is preserved (instrument defect repair, not adaptation to the measured object);
- the same defect in the wave-2 final path was fixed in the same commit (same-class elimination, not only the observed site).

## 4. Procedural compliance

- Adaptation-edit ledger: the fix was **committed first** (clean working tree) and the run resumed only after; the orchestrator's `git diff --exit-code` meter passed. This file is the defect-fix ceremony classification record required by run_cell.sh line 213.
- Intervention ledger: this fix + resume is one Appendix A entry (#5).
- Leak scan: both pre-commit scans were clean (no tokens, no private filenames, no amounts).

## 5. Zero-error rule — same-class prevention (new rule)

> Any code path that was repaired but not verified on a real run or a sandbox equivalent may not enter a formal cell run. The cell-3 pre-ignition checklist adds one item: every pipeline code path changed since its last successful execution must first pass on the staging/sandbox chain (mock or dry run), with the verification evidence listed line by line in the ignition notice.
