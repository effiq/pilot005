#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 18: SINGLE-SHOT CONFIRM (quality half of the recipe gate)
#
# Frozen craft from Pilot 004 stage 12, generalized to spec:
#   - The stage-16 winner gets ONE confirmation attempt on the cell's frozen
#     150-item set vs the hardware-local BF16 reference (gen_A, stage 15).
#     A miss publishes FAIL; a second attempt requires a new pre-registered
#     addendum. This stage RUNS ONCE per cell.
#   - Winner checkpoint rebuilt from the identical recipe; if the rebuild
#     hash differs from the screening build, BOTH hashes are disclosed.
#   - Panel: the three judges seated in stage 14 (panel.json). Rubric = spec
#     data (EFFIQ_RUBRIC_FILE; Arabic-native for ar cells — v4.2).
#   - Blind map: the cell's frozen blind_map (stage 15 derivation).
#   - Quality gate (frozen, FROZEN-LINES.json): per judge, overall delta
#     (candidate − reference) >= -0.1 AND every axis delta >= -0.1.
#     QUALITY-PASS iff ALL 3 judges pass (worst-judge binding).
#   - Run-validity (v4.2): a contaminated run is voided ONLY with
#     contemporaneous provider status-page evidence attached; otherwise
#     every run counts as measured. Symmetric.
#
# Requires: lib_spec env; stage 15 + 16 COMPLETE; stage 14 panel seated.
# Verify: bash stages/18-red-dot-confirm.sh --verify <run_dir>
# Test hooks: STAGE18_OUT_DIR, STAGE18_MOCK_BUILD, STAGE18_MOCK_JUDGE,
#   STAGE18_SKIP_SERVER, PORT, MAX_SECONDS
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
REPO_DIR="${EFFIQ_REPO_ROOT:-$EFFIQ_HOME/pilot005}"
CELL_DIR="${EFFIQ_CELL_DIR:?set by run_cell.sh}"
STAGE_NAME="18-red-dot-confirm"
CKPT_ROOT="${CKPT_ROOT:-$HOME/effiq/p005-ckpt}/$EFFIQ_CELL_ID"
KEY_FILE="${KEY_FILE:-$HOME/pilot-env/openrouter-key}"
OR_BASE_URL="${OR_BASE_URL:-https://openrouter.ai/api/v1}"
PORT="${PORT:-8000}"
MAX_SECONDS="${MAX_SECONDS:-21600}"

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage18][ERROR] %s\n' "$*" >&2; exit 1; }

S15="$(ls -d "$CELL_DIR/15-cell-preflight"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort (mtime meaningless after fresh clone)
S16="$(ls -d "$CELL_DIR/16-arm-screening"/run_* 2>/dev/null | sort | tail -1 || true)"     # A-12: name-sort
[ -f "$S15/COMPLETE" ] || die "stage 15 incomplete"
[ -f "$S16/COMPLETE" ] || die "stage 16 incomplete"
[ -f "$S16/winner.json" ] || die "stage 16 winner.json missing"
FROZEN_JSONL="$S15/frozen_set.jsonl"
BLIND_JSONL="$S15/blind_map.jsonl"
GENA_JSONL="$S15/gen_A.jsonl"
PANEL_JSON="$(ls -d "$CELL_DIR/14-judge-calibration"/run_*/panel.json 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort
[ -f "$PANEL_JSON" ] || die "panel.json missing"
for f in "$FROZEN_JSONL" "$BLIND_JSONL" "$GENA_JSONL"; do [ -f "$f" ] || die "missing $f"; done

# single-shot guard
PRIOR="$(ls -d "$CELL_DIR/$STAGE_NAME"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort
if [ -n "$PRIOR" ] && [ -f "$PRIOR/COMPLETE" ]; then
  echo "STAGE 18 already ran for this cell ($PRIOR) — single-shot discipline: a second attempt requires a new pre-registered addendum"
  exit 0
fi
# Amendment-12: own-dir resume (same pattern as stage-15/16) — a crash mid-stage
# must resume the existing incomplete run dir, not mint a new one and redo gen_C.
if [ -n "${STAGE18_OUT_DIR:-}" ]; then
  RUN_DIR="$STAGE18_OUT_DIR"
elif [ -n "$PRIOR" ]; then
  RUN_DIR="$PRIOR"; echo "resuming: $RUN_DIR"
else
  RUN_DIR="$CELL_DIR/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$RUN_DIR"

WINNER=$(python3 -c "import json;print(json.load(open('$S16/winner.json'))['arm_id'])")
WSHA=$(python3 -c "import json;print(json.load(open('$S16/winner.json'))['recipe_sha256'])")
echo "winner: $WINNER (recipe_sha256=${WSHA:0:16}…)"

# ---------- rebuild winner checkpoint from identical recipe; compare hash ----------
note "1. rebuild winner checkpoint (custody: disclose both hashes if rebuild differs)"
CKPT_C="$CKPT_ROOT/$WINNER"
SCR_SHA=$(grep "\"arm_id\": \"$WINNER\"" "$S16/checkpoints.jsonl" | tail -1 | python3 -c "import json,sys;print(json.loads(sys.stdin.read())['checkpoint_sha256'])")
if [ ! -d "$CKPT_C" ]; then die "winner checkpoint missing on pod ($CKPT_C) — rebuild from gate-layer recipe via stage 16 build path (addendum disclosure if hashes differ)"; fi
REBUILT_SHA=$(CKPT_C="$CKPT_C" python3 - <<'PY'
import hashlib, os
h = hashlib.sha256()
root = os.environ["CKPT_C"]
for dp, _, fns in sorted(os.walk(root)):
    for fn in sorted(fns):
        p = os.path.join(dp, fn)
        h.update(os.path.relpath(p, root).encode()); h.update(hashlib.sha256(open(p, "rb").read()).digest())
print(h.hexdigest())
PY
)
if [ "$REBUILT_SHA" != "$SCR_SHA" ]; then
  echo "REBUILD DIVERGENCE — disclosing both hashes (frozen rule): screening=$SCR_SHA confirm=$REBUILT_SHA" | tee "$RUN_DIR/rebuild_disclosure.txt"
fi
echo "checkpoint custody: ${REBUILT_SHA:0:16}…"

# ---------- candidate generation on frozen 150 ----------
note "2. candidate generation (frozen 150, winner arm)"
GEN_C="$RUN_DIR/gen_C.jsonl"
if [ "${STAGE18_SKIP_SERVER:-0}" = "1" ] || [ "${STAGE18_MOCK_BUILD:-0}" = "1" ]; then
  python3 -c "
import json
rows = [json.loads(l) for l in open('$FROZEN_JSONL')]
open('$GEN_C','w').write(''.join(json.dumps({'id': r['id'], 'prompt': r['text'], 'output': 'MOCK OUTPUT for ' + r['id']}, sort_keys=True) + chr(10) for r in rows))"
  echo "TEST HOOK mock gen_C"
else
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  MODEL_DIR="$CKPT_C" PORT="$PORT" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" GEN_CONC="$EFFIQ_GEN_CONC" \
  MAX_TOKENS_CAP="$EFFIQ_MAX_TOKENS_CAP" TEMPERATURE="$EFFIQ_TEMPERATURE" \
  SERVE_EXTRA="--quantization compressed-tensors" \
  bash "$REPO_DIR/pipeline/lib_generate.sh" --set "$FROZEN_JSONL" --out "$GEN_C"
fi

# ---------- panel judging (3 seated judges, blind order from stage 15) ----------
note "3. panel judging (worst-judge binding)"
if [ "${STAGE18_MOCK_JUDGE:-0}" = "1" ]; then MOCK="--mock"; else MOCK=""; fi
# Amendment-12 (D19): local-fallback judging path — if any seat carries the
# sentinel, bring up the pod-local anchor server (base model, BF16) for those
# seats; API seats keep their OpenRouter route (per-judge routing in lib_judge).
if [ -s "$RUN_DIR/scores_panel.jsonl" ]; then   # A-12: resume — judging already complete
  echo "  scores_panel.jsonl exists (non-empty), skip judging"
else
LOCAL_JUDGE_ACTIVE=0
LOCAL_JUDGE_ARGS=()
if grep -q "LOCAL-FALLBACK" "$PANEL_JSON"; then
  LOCAL_JUDGE_ARGS=(--local-base "http://127.0.0.1:$PORT/v1")
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  sleep 5
  source "$REPO_DIR/pipeline/lib_serve.sh"
  MODEL_DIR="$CKPT_ROOT/base" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" PORT="$PORT" SERVE_EXTRA="" ensure_server \
    || die "anchor judge server failed to start (local-fallback path)"
  LOCAL_JUDGE_ACTIVE=1
  echo "  local-fallback seat(s) present: anchor server up on :$PORT (base model, BF16, thinking disabled per-call)"
fi
python3 "$REPO_DIR/pipeline/lib_judge.py" --panel "$PANEL_JSON" \
  --rubric "$REPO_DIR/$EFFIQ_RUBRIC_FILE" --blind "$BLIND_JSONL" \
  --candidates "$GEN_C" --reference "$GENA_JSONL" --frozen "$FROZEN_JSONL" \
  --out "$RUN_DIR/scores_panel.jsonl" --key-file "$KEY_FILE" --base "$OR_BASE_URL" \
  "${LOCAL_JUDGE_ARGS[@]}" $MOCK
if [ "$LOCAL_JUDGE_ACTIVE" = "1" ]; then
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  rm -f /tmp/.effiq-server-pid
  echo "  anchor judge server down"
fi
fi   # A-12: end scores_panel.jsonl resume guard

# ---------- quality gate (frozen thresholds; worst judge binds) ----------
note "4. quality gate"
set +e
RUN_DIR="$RUN_DIR" LINES="$REPO_DIR/pipeline/FROZEN-LINES.json" WINNER="$WINNER" WSHA="$WSHA" \
GEN_C="$GEN_C" GEN_A="$GENA_JSONL" python3 - <<'PY'
import json, os, statistics, sys
L = json.load(open(os.environ["LINES"]))["gates"]
tol_o, tol_a = L["quality_tolerance_overall"], L["quality_tolerance_axis"]
rows = [json.loads(l) for l in open(f"{os.environ['RUN_DIR']}/scores_panel.jsonl")]
by = {}
for r in rows: by.setdefault((r["blind_id"], r["judge"]), {})[r["which"]] = r["axes"]
judges = sorted({r["judge"] for r in rows})
per_judge = {}
for j in judges:
    ds = [v for (b, jj), v in by.items() if jj == j]
    per_judge[j] = {ax: statistics.mean([d["candidate"][ax] - d["reference"][ax] for d in ds])
                    for ax in ("clarity", "correctness", "completeness", "overall")}
verdicts = {j: (d["overall"] >= tol_o and all(v >= tol_a for k, v in d.items() if k != "overall"))
            for j, d in per_judge.items()}
qp = all(verdicts.values())
out = {"arm": os.environ["WINNER"], "recipe_sha256": os.environ["WSHA"],
       "per_judge_deltas": per_judge, "per_judge_pass": verdicts,
       "quality_gate": "PASS" if qp else "FAIL", "worst_judge_binds": True,
       "tolerances": {"overall": tol_o, "axis": tol_a},
       "n_items": len({r['blind_id'] for r in rows})}
json.dump(out, open(f"{os.environ['RUN_DIR']}/verdict_c.json", "w"), indent=1, sort_keys=True)
print(json.dumps(per_judge, indent=1))
print("QUALITY GATE:", out["quality_gate"])
sys.exit(0 if qp else 2)
PY
rc=$?
set -e
sha256sum "$GEN_C" "$RUN_DIR/scores_panel.jsonl" "$RUN_DIR/verdict_c.json" | tee "$RUN_DIR/custody.sha256"
touch "$RUN_DIR/COMPLETE"
if [ "$rc" = "2" ]; then
  note "STAGE 18 COMPLETE — QUALITY-FAIL (single shot spent; publish as-is; stage 19 reports the FAIL)"
  exit 2
fi
note "STAGE 18 COMPLETE — QUALITY-PASS (worst judge bound)"
