# ADDENDUM-20 — Cell-3 Development Attempt-1 Sealing and Attempt-2 Re-Opening (Intervention-Cap Breach)

**Status:** SEALED — owner ruling 2026-10-22 ("choose A and re-open")
**References:** ADDENDUM-15/18 (sealing precedents); ADDENDUM-16 §7 (ignition discipline); ADDENDUM-17 §5 (unverified-path prohibition); ADDENDUM-19 (processor-initialization fix); Protocol v4.2 Appendix A

## 1. Object being sealed

cell3-fanar-2-27b development attempt 1 (first ignition 2026-10-22T13:46:49Z, terminated 14:30:55Z):

- Termination cause: the orchestrator entry self-check stopped with `INTERVENTION CAP EXCEEDED (9 > 8)` — Appendix A freezes the manual-intervention cap at 8; this attempt actually consumed 9 (four ignitions + handoff placement + disk expansion + push-collision repair + defect-fix ceremony). **The verdict discipline line was breached, independent of any measurement result.**
- No verdict was produced. Landed data (the full stage-15 anchor/custody set; the stage-16 sensitivity profile of 248 modules; b1/b2 composition hashes) is archived under `attempt-1-cap-breach-20261022/` for engineering reference only and never enters any verdict.
- Cleanliness argument: all three stops were fail-stop faults (disk precheck, push collision, processor initialization), occurring before measurement readings or at the transport layer; no reading was touched or rewritten.

## 2. Lesson attribution (line-by-line review of the nine ledger rows)

Owner instruction: "do not repeat the same class of mistake; raise the ignition success rate." Three avoidable operational failures are fixed as rules:

1. **Missing capacity precheck:** the container disk was not checked against the spec card before ignition (stage 15 has a frozen ≥150GB check). → Rule: the first ignition-checklist item is a line-by-line check of every orchestrator entry hard check (disk, GPU, stack versions, the four gate-layer pieces, sha consistency), and the check record goes into the ignition notice.
2. **Concurrent push collision:** manual sandbox pushes of the ledger raced the pod's automatic artifact pushes to the same remote. → Rule: while a run is alive, all writes to pilot-logs go through the pod's landed-push path only; the sandbox is read-only.
3. **Target-architecture build path never dry-run:** the gemma-3 llmcompressor build chain was never smoke-tested (violates ADDENDUM-17 §5). → Rule: before a cross-architecture-family first run, the full build→serve chain must pass a small-sample smoke in a disposable directory, with the evidence listed in the ignition notice.

## 3. Smoke-verification evidence (before attempt-2 ignition, 2026-10-22T14:4xZ)

Executed per rule 3: mini oneshot (same recipe structure as b3: FP8_DYNAMIC + kv_cache_scheme + attention-exemption regex + the ADDENDUM-19 processor path; 8 real calibration texts; samples=8, seq=512):

- build: **SMOKE-BUILD-OK** (82 s; float-quantized format landed correctly);
- serve: **SMOKE-SERVE-OK** (vLLM 0.31.0 `--quantization compressed-tensors` loaded the mini checkpoint and generated correctly);
- smoke artifacts were removed immediately (disposable directory /root/smoke; no run state touched).

## 4. Attempt-2 inheritance and reset

- **Inherited** (interventions not re-counted): the 14-judge-calibration/ panel-handoff placement (the physical state already exists; certification validity does not lapse with the attempt); pilot005 @ 32cf7df (contains the ADDENDUM-19 fix).
- **Reset:** the STAGE bookmark returns to 15-cell-preflight; the intervention ledger is zeroed (attempt-2's first row = ignition); wallclock-development restarts (development is untimed, but its duration is recorded and published truthfully).
- **Sealing action:** every attempt-1 artifact is `git mv`ed into `attempt-1-cap-breach-20261022/` (including the empty run skeleton); this addendum is the terminal-state registration.

## 5. Disclosure wording (for publication)

Cell-3's first development attempt was sealed because manual interventions exceeded the frozen cap (9 > 8); it produced no verdict. The event itself demonstrates that the intervention-cap rule is executed mechanically (the orchestrator refused to continue; there was no silent resumption). All formal cell-3 verdicts come from the attempt-2 chain.
