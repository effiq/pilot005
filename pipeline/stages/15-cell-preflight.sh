#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 15: CELL PREFLIGHT (foundation, spec-driven)
#
# Generalizes Pilot 004 stage 10 from one hardcoded cell to ANY cell:
# constants are gone — everything arrives via lib_spec.sh env vars (spec
# data). The PROCEDURE is the frozen 002/003/004 craft, byte-preserved in
# substance:
#
#   1. Environment anchors: golden-stack assertion (versions from
#      FROZEN-LINES.json) with the pinned auto-repair sequence; GPU must
#      match spec.hardware (H100); disk >= 150GB; volume writable.
#   2. Model custody: model repo pinned by 40-hex revision (spec); weights
#      downloaded and full-tree sha256 recorded (the cell's byte identity).
#   3. Load trace acquisition per spec.load (wildchat | wildchat-ar |
#      synthetic), filter description archived; trace sha256 anchored.
#      (Synthetic top-up, if any, is disclosed via addendum — v4.2.)
#   4. Anchor DERIVATION (new machinery, replaces 004's archive-inherit):
#      derive_cell_anchors.py produces frozen 150 / screening 40 /
#      calibration 256 / blind map, disjointness asserted, every sha256
#      recorded. Regression cells never reach here (run_cell.sh refuses).
#   5. H100 operating-point recalibration: frozen grid order and SLO
#      (TTFT<=5s AND TPOT<=100ms, >=95% compliance, tier-1/tier-2 aborts),
#      calibrated on the BF16 arm. ALL calibration rows watermarked:
#      CALIBRATION DATA ONLY — never enters the CI.
#   6. Hardware-local references: gen_A (frozen 150) and gen_R (screening
#      40) generated on THIS pod with BF16 defaults (temperature 0,
#      natural stopping, spec concurrency) — judging never crosses
#      hardware.
#
# This stage judges nothing and measures nothing for the verdict.
#
# Requires: env vars from lib_spec.sh (set by run_cell.sh).
# Verify entry: bash stages/15-cell-preflight.sh --verify <run_dir>
# Test hooks (sandbox only): STAGE15_OUT_DIR, STAGE15_SKIP_GPU,
#   STAGE15_SKIP_ENV, STAGE15_SKIP_DOWNLOAD, STAGE15_MOCK_CALIB,
#   STAGE15_SKIP_SERVER, STAGE15_MIN_FREE_GB, PORT, MAX_SECONDS, VOLUME_DIR
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
LOGS_DIR="${LOGS_DIR:-$EFFIQ_HOME/pilot-logs}"
REPO_DIR="${EFFIQ_REPO_ROOT:-$EFFIQ_HOME/pilot005}"
CELL_DIR="${EFFIQ_CELL_DIR:?set by run_cell.sh}"
STAGE_NAME="15-cell-preflight"
VOLUME_DIR="${VOLUME_DIR:-/workspace}"
MAX_SECONDS="${MAX_SECONDS:-43200}"
PORT="${PORT:-8000}"
CKPT_ROOT="${CKPT_ROOT:-$HOME/effiq/p005-ckpt}"

# frozen calibration craft (002 stage-02, unchanged byte-for-byte rule)
GRID_ORDER="1 16|2 16|1 8|4 16|2 8|1 4|8 16|4 8|2 4|16 16|8 8|4 4|32 16|16 8|8 4|64 16|32 8|16 4|128 16|64 8|32 4|256 16|128 8|64 4|256 8|128 4|256 4"
SLO_TTFT_S=5.0
SLO_TPOT_MS=100.0
COMPLIANCE_MIN=0.95
REQ_TIMEOUT_S=900
CLIENT_CONC=2048
FILLER_SEED=20261010
WATERMARK="CALIBRATION DATA ONLY — never enters the CI"

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage15][ERROR] %s\n' "$*" >&2; exit 1; }
sha_file() { sha256sum "$1" | cut -d' ' -f1; }

# ---------- --verify ----------
if [ "${1:-}" = "--verify" ]; then
  D="${2:-}"
  [ -n "$D" ] && [ -f "$D/anchors.json" ] || { echo "usage: --verify <run_dir>"; exit 1; }
  ANCHORS_JSON="$D/anchors.json" RUN_DIR="$D" python3 - <<'PY'
import hashlib, json, os, sys
def sha(p): return hashlib.sha256(open(p, "rb").read()).hexdigest()
a = json.load(open(os.environ["ANCHORS_JSON"]))
bad = []
for name, want in sorted(a.get("files", {}).items()):
    p = os.path.join(os.environ["RUN_DIR"], name)
    got = sha(p) if os.path.exists(p) else "MISSING"
    print(f"  {name}: {'OK' if got == want else 'MISMATCH'} ({got[:16]}…)")
    if got != want: bad.append(name)
if bad: print("VERIFY: MISMATCH — " + ", ".join(bad), file=sys.stderr); sys.exit(1)
print("VERIFY: ALL CHECKS PASSED")
PY
  exit $?
fi

# ---------- run bookkeeping (resume-or-create; COMPLETE re-entry guard) ----------
note "0. run bookkeeping (cell=$EFFIQ_CELL_ID)"
if [ -n "${STAGE15_OUT_DIR:-}" ]; then
  RUN_DIR="$STAGE15_OUT_DIR"; mkdir -p "$RUN_DIR"
else
  LATEST="$(ls -d "$CELL_DIR/$STAGE_NAME"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort (mtime meaningless after fresh clone)
  if [ -n "$LATEST" ] && [ -f "$LATEST/COMPLETE" ]; then
    echo "STAGE 15 already COMPLETE: $LATEST"; exit 0
  fi
  RUN_DIR=""
  for cand in $(ls -d "$CELL_DIR/$STAGE_NAME"/run_* 2>/dev/null | sort -r); do   # A-12: name-sort, newest first
    [ -f "$cand/COMPLETE" ] || { RUN_DIR="$cand"; echo "resuming: $RUN_DIR"; break; }
  done
  [ -n "$RUN_DIR" ] || { RUN_DIR="$CELL_DIR/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$RUN_DIR"; echo "new run dir: $RUN_DIR"; }
fi
T0=$(date +%s)
rail() { [ $(( $(date +%s) - T0 )) -gt "$MAX_SECONDS" ] && die "time rail tripped — re-run to resume"; return 0; }

# ---------- 1. environment anchors ----------
note "1. environment anchors"
LINES="$REPO_DIR/pipeline/FROZEN-LINES.json"
date -u; hostname || true
echo "pipeline_rev=$(git -C "$REPO_DIR" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
echo "spec_sha256=$EFFIQ_SPEC_SHA256"

if [ "${STAGE15_SKIP_GPU:-0}" != "1" ]; then
  GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)"
  [[ "$GPU_NAME" == *"$EFFIQ_GPU_EXPECT"* ]] || die "expected $EFFIQ_GPU_EXPECT, found '$GPU_NAME' (hardware scope)"
  GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l)"
  [ "$GPU_COUNT" = "1" ] || die "expected exactly 1 GPU, found $GPU_COUNT (single-card scope)"
  echo "gpu: $GPU_NAME (count=1)"
else
  echo "TEST HOOK: STAGE15_SKIP_GPU=1"
fi

if [ "${STAGE15_SKIP_ENV:-0}" = "1" ]; then
  echo "TEST HOOK: STAGE15_SKIP_ENV=1"
else
  LINES="$LINES" python3 - <<'PY' || {
import importlib, json, os
L = json.load(open(os.environ["LINES"]))["env_stack"]
def ver(m):
    try: return importlib.import_module(m).__version__
    except Exception: return None
ok = True
for mod, want, mode in [("torch",L["torch_prefix"],"prefix"),("vllm",L["vllm"],"exact"),
    ("compressed_tensors",L["compressed_tensors"],"exact"),("transformers",L["transformers"],"exact"),
    ("llmcompressor",L["llmcompressor"],"exact"),("datasets",L["datasets"],"exact"),
    ("accelerate",L["accelerate"],"exact")]:
    got = ver(mod)
    good = got is not None and (got.startswith(want) if mode=="prefix" else got==want)
    ok &= good
    print(f"  {mod}: want {want} ({mode}), got {got} {'OK' if good else 'MISMATCH'}")
raise SystemExit(0 if ok else 1)
PY
    echo "golden stack mismatch — pinned repair sequence (engine deps immovable; builder adapts)"
    # Amendment-02 guard: Debian-managed python packages ship without RECORD files,
    # so pip cannot uninstall them and dies ("uninstall-no-record-file" — PyJWT 2.7.0
    # killed the first cell-1 ignition at this spot). Pre-install pip-managed copies
    # of every RECORD-less package that can appear in the engine dependency tree;
    # the Debian copies stay untouched for system tools (pure-python/wheel only —
    # never touch dbus-python/PyGObject/python-apt & friends).
    pip install -q --ignore-installed PyJWT blinker cryptography distro httplib2 oauthlib pyparsing six
    V=$(python3 -c "import json;L=json.load(open('$LINES'))['env_stack'];print(' '.join([L['vllm'],L['llmcompressor'],L['transformers'],L['datasets'],L['accelerate']]))")
    read -r VLLM_V LC_V TF_V DS_V AC_V <<< "$V"
    pip install -q "vllm==$VLLM_V"
    pip install -q --no-deps "llmcompressor==$LC_V"
    pip install -q "transformers==$TF_V" "datasets==$DS_V" "accelerate==$AC_V" loguru nvidia-ml-py pillow httpx
    echo "repair applied — re-verified on next run phase"
  }
fi
pip freeze > "$RUN_DIR/pip_freeze.txt"

mkdir -p "$EFFIQ_HOME"   # df target must exist — a missing dir made df fail silently under set -e (staging dry-run lesson)
MIN_FREE_GB="${STAGE15_MIN_FREE_GB:-150}"
[ "$MIN_FREE_GB" = "150" ] || echo "TEST HOOK: STAGE15_MIN_FREE_GB=$MIN_FREE_GB"
DF_GB=$(df -BG --output=avail "$EFFIQ_HOME" 2>/dev/null | tail -1 | tr -dc '0-9')
[ "${DF_GB:-0}" -ge "$MIN_FREE_GB" ] || die "disk < ${MIN_FREE_GB}GB free (avail=${DF_GB:-?}GB on \$EFFIQ_HOME)"
[ -w "$VOLUME_DIR" ] || die "volume not writable at $VOLUME_DIR (private-file backup discipline)"
echo "disk ${DF_GB}GB ok; volume writable"
rail

# ---------- 2. model custody ----------
note "2. model custody ($EFFIQ_MODEL @ ${EFFIQ_MODEL_REV:0:12}…)"
MODEL_DIR="$CKPT_ROOT/$EFFIQ_CELL_ID/base"
mkdir -p "$MODEL_DIR"
if [ "${STAGE15_SKIP_DOWNLOAD:-0}" = "1" ]; then
  echo "TEST HOOK: STAGE15_SKIP_DOWNLOAD=1"
  echo "mock-weights" > "$MODEL_DIR/weights.mock"
else
  if [ ! -f "$MODEL_DIR/.download_complete" ]; then
    MODEL="$EFFIQ_MODEL" REV="$EFFIQ_MODEL_REV" DEST="$MODEL_DIR" python3 - <<'PY'
import os
from huggingface_hub import snapshot_download
snapshot_download(os.environ["MODEL"], revision=os.environ["REV"],
                  local_dir=os.environ["DEST"], local_dir_use_symlinks=False)
open(os.path.join(os.environ["DEST"], ".download_complete"), "w").write("ok")
PY
  fi
fi
# full-tree byte identity of the cell under test
TREE_SHA=$(MODEL_DIR="$MODEL_DIR" python3 - <<'PY'
import hashlib, os
h = hashlib.sha256()
root = os.environ["MODEL_DIR"]
for dp, _, fns in sorted(os.walk(root)):
    for fn in sorted(fns):
        if fn == ".download_complete": continue
        p = os.path.join(dp, fn)
        h.update(os.path.relpath(p, root).encode())
        h.update(hashlib.sha256(open(p, "rb").read()).digest())
print(h.hexdigest())
PY
)
echo "model_tree_sha256=$TREE_SHA" | tee "$RUN_DIR/model_tree.sha256"
rail

# ---------- 3. load trace acquisition ----------
note "3. load trace (source=$EFFIQ_TRACE_SOURCE lang=$EFFIQ_LANG)"
TRACE_JSONL="$RUN_DIR/trace.jsonl"
if [ ! -f "$TRACE_JSONL" ]; then
  TRACE_JSONL="$TRACE_JSONL" SOURCE="$EFFIQ_TRACE_SOURCE" FILTER="$EFFIQ_TRACE_FILTER" \
  LANG="$EFFIQ_LANG" SYNTH_SEED="$EFFIQ_SYNTHETIC_SEED" RUN_DIR="$RUN_DIR" python3 - <<'PY'
import json, os, random, sys
src, lang = os.environ["SOURCE"], os.environ["LANG"]
out = os.environ["TRACE_JSONL"]
need = 150 + 40 + 256  # frozen + screen + calib
note = {"source": src, "filter": os.environ["FILTER"], "lang": lang}
if src.startswith("wildchat"):
    from datasets import load_dataset
    ds = load_dataset("allenai/WildChat-1M", split="train", streaming=True)
    want_ar = (src == "wildchat-ar")
    rows = []
    for ex in ds:
        if ex.get("language") != ("Arabic" if want_ar else "English") and want_ar:
            continue
        if not want_ar and ex.get("language") == "Arabic":
            continue
        conv = ex.get("conversation") or []
        if not conv or not conv[0].get("content"):
            continue
        rows.append({"id": str(ex.get("conversation_hash") or len(rows)),
                     "text": conv[0]["content"][:4000]})
        if len(rows) >= 2000: break          # pool; sampler takes what it needs
    if len(rows) < need:
        print(f"FATAL: harvested {len(rows)} < {need}; declare synthetic top-up via addendum", file=sys.stderr)
        sys.exit(1)
elif src == "synthetic":
    seed = os.environ["SYNTH_SEED"]
    if not seed: print("FATAL: synthetic trace without declared seed", file=sys.stderr); sys.exit(1)
    rng = random.Random(int(seed))
    rows = [{"id": f"syn-{i:05d}", "text": f"synthetic prompt {i} " + " ".join(rng.choices("abcdefgh", k=50))}
            for i in range(need)]
    note["disclosed_via"] = "addendum (v4.2 synthetic-fallback clause)"
else:
    print(f"FATAL: unknown trace_source {src}", file=sys.stderr); sys.exit(1)
with open(out, "w", encoding="utf-8") as f:
    for r in rows: f.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n")
with open(os.path.join(os.environ["RUN_DIR"], "trace_provenance.json"), "w") as f:
    json.dump(note, f, indent=1)
print(f"trace rows: {len(rows)}")
# streaming teardown race (observed 2026-10-17, exit 134): pyarrow/huggingface_hub
# prefetch threads can outlive the workload and abort interpreter finalization
# (PyGILState_Release) after all artifacts are written. Skip finalization so the
# exit code reflects the completed work, not the race.
sys.stdout.flush(); sys.stderr.flush(); os._exit(0)
PY
fi
TRACE_SHA=$(sha_file "$TRACE_JSONL")
echo "trace_sha256=$TRACE_SHA"
rail

# ---------- 4. anchor derivation ----------
note "4. anchor derivation (frozen 150 / screening 40 / calib 256 / blind map)"
if [ ! -f "$RUN_DIR/anchors.json" ]; then
  python3 "$REPO_DIR/pipeline/stages/derive_cell_anchors.py" \
    --trace "$TRACE_JSONL" --out "$RUN_DIR" \
    --derive-seed "$EFFIQ_DERIVE_SEED" --blind-seed "$EFFIQ_BLIND_SEED" \
    --n-frozen "$EFFIQ_N_FROZEN" --n-screen "$EFFIQ_N_SCREEN" --n-calib "$EFFIQ_N_CALIB_TEXTS"
fi
echo "anchors: $(sha_file "$RUN_DIR/frozen_set.jsonl") $(sha_file "$RUN_DIR/screening_set.jsonl")"
rail

# ---------- 5. H100 operating-point recalibration (frozen rule) ----------
note "5. operating-point recalibration (grid frozen; SLO TTFT<=${SLO_TTFT_S}s TPOT<=${SLO_TPOT_MS}ms >=${COMPLIANCE_MIN})"
echo "$WATERMARK" > "$RUN_DIR/CALIBRATION_WATERMARK.txt"
CHOSEN_JSON="$RUN_DIR/chosen_point.json"
if [ "${STAGE15_MOCK_CALIB:-0}" = "1" ]; then
  echo '{"concurrency": 16, "max_tokens": 256, "compliance": 1.0, "mock": true}' > "$CHOSEN_JSON"
  echo "TEST HOOK: STAGE15_MOCK_CALIB=1"
elif [ "${STAGE15_SKIP_SERVER:-0}" = "1" ]; then
  echo "TEST HOOK: STAGE15_SKIP_SERVER=1 (calibration deferred)"
else
  # frozen craft: walk GRID_ORDER under decreasing offered load, BF16 arm,
  # tier-1 live abort / tier-2 window-end abort; first >=95% compliant wins;
  # all-fail -> lightest config with fallback disclosure (002 stage-02 rule).
  GRID_ORDER="$GRID_ORDER" SLO_TTFT_S="$SLO_TTFT_S" SLO_TPOT_MS="$SLO_TPOT_MS" \
  COMPLIANCE_MIN="$COMPLIANCE_MIN" MODEL_DIR="$MODEL_DIR" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" \
  PORT="$PORT" CHOSEN_JSON="$CHOSEN_JSON" RUN_DIR="$RUN_DIR" REQ_TIMEOUT_S="$REQ_TIMEOUT_S" \
  CLIENT_CONC="$CLIENT_CONC" FILLER_SEED="$FILLER_SEED" MAX_TOKENS_CAP="$EFFIQ_MAX_TOKENS_CAP" \
  bash "$REPO_DIR/pipeline/lib_calibrate.sh"   # extracted 002/004 calibration body, unchanged rule
fi
rail

# ---------- 6. hardware-local references ----------
note "6. reference generation (gen_A frozen150, gen_R screening40; BF16, temp 0, conc $EFFIQ_GEN_CONC)"
if [ "${STAGE15_SKIP_SERVER:-0}" = "1" ]; then
  echo "TEST HOOK: STAGE15_SKIP_SERVER=1 (references deferred)"
  # sandbox completeness: downstream stages require gen_A/gen_R to exist.
  # Fill deterministic mock rows — watermarked, never valid as evidence.
  # (Mock-ignition lesson: run_cell-driven sandbox runs have no external
  #  harness to backfill these; the stage must be self-complete.)
  RUN_DIR="$RUN_DIR" python3 - <<'PY'
import json, os
run = os.environ["RUN_DIR"]
for src, dst in [("frozen_set.jsonl", "gen_A.jsonl"), ("screening_set.jsonl", "gen_R.jsonl")]:
    with open(os.path.join(run, src)) as fi, open(os.path.join(run, dst), "w") as fo:
        for line in fi:
            r = json.loads(line)
            # mirror lib_generate.sh row schema exactly: id / prompt(=text) / output
            fo.write(json.dumps({"id": r["id"], "prompt": r.get("text", ""),
                                 "output": "MOCK-REFERENCE (sandbox SKIP_SERVER) — not evidence",
                                 "mock": True}, ensure_ascii=False) + "\n")
print("mock references written (sandbox only, watermarked)")
PY
else
  GEN_CONC="$EFFIQ_GEN_CONC" MODEL_DIR="$MODEL_DIR" PORT="$PORT" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" \
  SERVE_EXTRA="$EFFIQ_SERVE_EXTRA" MAX_TOKENS_CAP="$EFFIQ_MAX_TOKENS_CAP" TEMPERATURE="$EFFIQ_TEMPERATURE" \
  bash "$REPO_DIR/pipeline/lib_generate.sh" \
    --set "$RUN_DIR/frozen_set.jsonl"    --out "$RUN_DIR/gen_A.jsonl" \
    --set "$RUN_DIR/screening_set.jsonl" --out "$RUN_DIR/gen_R.jsonl"
fi

# ---------- custody ----------
note "custody"
{
  echo "spec_sha256=$EFFIQ_SPEC_SHA256"
  echo "model_tree_sha256=$TREE_SHA"
  echo "trace_sha256=$TRACE_SHA"
  echo "frozen_set=$(sha_file "$RUN_DIR/frozen_set.jsonl")"
  echo "screening_set=$(sha_file "$RUN_DIR/screening_set.jsonl")"
  echo "calibration_texts=$(sha_file "$RUN_DIR/calibration_texts.jsonl")"
  echo "blind_map=$(sha_file "$RUN_DIR/blind_map.jsonl")"
  [ -f "$RUN_DIR/gen_A.jsonl" ] && echo "gen_A=$(sha_file "$RUN_DIR/gen_A.jsonl")"
  [ -f "$RUN_DIR/gen_R.jsonl" ] && echo "gen_R=$(sha_file "$RUN_DIR/gen_R.jsonl")"
  [ -f "$CHOSEN_JSON" ] && echo "chosen_point=$(sha_file "$CHOSEN_JSON")"
} | tee "$RUN_DIR/custody.sha256"

touch "$RUN_DIR/COMPLETE"
note "STAGE 15 COMPLETE (cell=$EFFIQ_CELL_ID) — verify: bash stages/15-cell-preflight.sh --verify $RUN_DIR"
