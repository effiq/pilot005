# ADDENDUM-18 — Cell-2 Development-Phase FAIL Sealed as the Cell Terminal State (Confirmation Phase Not Executed)

**Status:** SEALED — owner ruling 2026-10-22
**References:** ADDENDUM-15 (cell-1 re-evaluation cancellation; same sealing precedent); ADDENDUM-16 (panel handoff); ADDENDUM-17 (defect fix); Protocol v4.2

## 1. Object being sealed

The full cell2-r1-distill-qwen-14b development chain (ignition 2026-10-22T02:16:14Z, completion 05:08:46Z, wall clock 2h52m):

- stage 16 screening: FINAL WINNER = b4-w2 (merge of b1-profile-exempt and b3-a4-kv; recipe sha a9b66ffa1c48aa5f…), clarity_delta = +0.000, proceed = true (run_20261022T022413Z);
- stage 18 red-dot confirmation: quality gate FAIL — deepseek-v3-0324 correctness axis −0.1067 crosses the −0.1 frozen line (worst judge binds); the other two seats pass (verdict_c.json, n = 150);
- stage 19 dual gates: migration gate PASS (mean 1.4588×, CI lower bound 1.443 > 1.20 line); recipe gate FAIL (mean 1.3033×, CI lower bound 1.292 < 1.50 line); overall verdict FAIL, straddle = false (VERDICT.json, n = 10);
- evidence chain: pilot-logs terminal commit a134b85; intervention ledger 6/8 manual actions + 1 machine row; the pod had exited with its disk retained.

## 2. Legal basis: why a failure needs no confirmation phase

1. The confirmation phase exists to prevent "tune in the lab until the line is crossed, then claim one success" — it certifies a strong claim (success). A failure claim carries no corresponding incentive to cheat; its evidence requirement is one grade lower by construction: one clean development-phase failure is publication-eligible.
2. Protocol v4.2's symmetric no-rerun rule: invalidation or rerun is allowed only on same-period supplier-failure evidence; a result-driven rerun is itself a violation. Running confirmation after a rehearsal FAIL is lose-lose: a repeated FAIL spends money for zero information, while a flipped PASS falls under "run until it passes" suspicion and is unpublishable.
3. ADDENDUM-15 precedent: a cell result can be sealed as a terminal record through disclosure wording; the confirmation phase is not mandatory.

## 3. Cleanliness argument: the failure comes from the measured combination, not instrument failure

1. The two development-phase incidents (profile-lever omission; recipe-hash custody lookup defect) were both **fail-stop faults** — the pipeline would rather halt than write a wrong number; neither touched any measurement reading.
2. Every number came from the frozen instrument: FROZEN-LINES.json hash 18ffa911… (matches Appendix C, untouched throughout); the three-judge panel.json d9335e72…; per-stage custody.sha256 anchors; stage-15 artifact hashes chained into stage 16/18 input custody.
3. The ADDENDUM-17 repair changed only the custody query (skip empty-sha rows); it touched neither winner-selection mathematics nor any landed data — scores_*.jsonl and screening_verdict.json are byte-identical before and after, and anyone can re-verify.
4. Compliance: development phase is untimed per protocol; manual interventions 6/8; adaptation edits 0 (both code repairs followed defect-fix ceremony — commit first, then resume — with the adaptation meter green).

## 4. Disclosure wording (for publication)

This cell's verdict comes from the development-phase chain; the confirmation phase was not executed (its two-attempt budget and 72 h track remain unused). The semantics paragraph follows the frozen VERDICT.json text: a negative result is a compressibility fact about the measured combination (model × quantization × hardware) under the frozen process — not a defect verdict on the model, and not a capability verdict on Effiq.

## 5. Sealing action

The STAGE bookmark stops at 19-dual-gates (this cell does not resume); the pilot-logs working tree is clean; the pod is stopped with disk retained. This addendum is the terminal-state registration and routes with the publication package through the novelty gate.
