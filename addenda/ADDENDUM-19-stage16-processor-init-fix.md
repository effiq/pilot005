# ADDENDUM-19 — Stage-16 llmcompressor Processor Implicit-Initialization Fix (Defect-Fix Ceremony)

**Sealed:** 2026-10-22T14:35Z, during cell3-fanar-2-27b development
**Trigger:** stage 16 section 3 (checkpoint builds) stopped on FATAL; default-deny watchdog alert at 14:25:34Z (class = unknown → wait_ai); owner instruction: inspect it.

## 1. Defect

The recipe build in `stages/16-arm-screening.sh` calls `llmcompressor.oneshot(model=..., dataset=..., recipe=...)` without passing `processor` explicitly. When a dataset is supplied, llmcompressor forces an implicit processor initialization via `AutoProcessor.from_pretrained(model_dir)`.

- cell-1/cell-2 (Qwen families): the AutoProcessor mapping exists, so the path never surfaced;
- cell-3 (gemma3_text text-only checkpoint): transformers 5.10.4 maps model_type `gemma3_text` to the multimodal `Gemma3Processor`, whose initialization requires an image processor, while the QCRI/Fanar-2-27B-Instruct text-only repository has no `preprocessor_config.json` → `OSError: Can't load image processor` → llmcompressor raises RuntimeError and stops.

Same-day verification: `AutoProcessor.from_pretrained(ckpt)` fails as diagnosed; `AutoTokenizer.from_pretrained(ckpt)` works (GemmaTokenizer); the `oneshot` signature accepts a `processor` parameter.

## 2. Classification

An instrument–environment interaction defect, not an adaptation to the measured object: the pipeline implicitly assumed "AutoProcessor works for every architecture"; the gemma-3 text-only checkpoint breaks that assumption. Recipe content, exemption sets, quantization scheme, and calibration data: **zero changes**.

**Self-examination:** this is exactly the same class that ADDENDUM-17 §5 exists to prevent — "no code path enters a formal cell without real-run or sandbox verification." The stage-16 build path had never been dry-run against gemma-3 (the 0.5B dry run used Qwen). The cell-3 pre-registration checklist missed "dry-run the builder path for the target architecture." Lesson registered: before any cross-family first run, in addition to profile regex verification (done here, 248/248), a **build-path sandbox smoke** (small-sample oneshot dry run) is mandatory.

## 3. Fix (pilot005 commit 32cf7df, 6 insertions / 1 deletion)

The oneshot call now passes `processor=AutoTokenizer.from_pretrained(MODEL_DIR)` explicitly — the repair prescribed by llmcompressor's own error message ("create and pass in a processor directly"). Semantic invariants:

- the tokenizer is the text channel of the multimodal processor; text calibration behaviour is unchanged;
- recipe mathematics untouched; no landed data touched (the stage-15 profile artifact and b1/b2 composition records are byte-identical; resume reuses them automatically);
- no model name and no architecture-conditional branch (applies uniformly to all cells — completed cells are not re-run and are unaffected);
- a genuinely multimodal checkpoint will need a real processor in future; that will be a separate addendum.

## 4. Procedural compliance

- Fix committed before resume; the orchestrator's adaptation-edit meter (`git diff --exit-code` vs origin/main) stayed green.
- Intervention ledger: one Appendix A entry (#6: defect-fix ceremony + re-ignition).
- Leak scan: clean before commit (no tokens, no private filenames, no amounts).
- The stage-15 profile artifact already landed in this run (248 modules; max mse_rel = 0.000829 at model.layers.25.self_attn.q_proj) and the b1/b2 composition hashes are unaffected by the repair; the resume path reuses them.

## 5. Relations

- Precedents: ADDENDUM-17 (same ceremony class at stage 16); ADDENDUM-18 (cell-2 sealing); PRE-REGISTRATION-cell3 (e048d46).
- Earlier events in the same run: stage-15 disk refusal + podEditJob expansion (ledger #2–#3); push-collision repair (ledger #5).
