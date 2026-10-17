#!/usr/bin/env bash
# =====================================================================
# preflight_smoke.sh — Amendment-07 (R16). Pre-ignition dress rehearsal.
#
# Runs OUTSIDE the frozen window, BEFORE any cell ignition: no ledger, no
# custody, no pilot-logs contact, zero intervention-budget cost. It downloads
# a tiny model (Qwen3-0.6B, ~1.5GB) and exercises the REAL code paths that
# staging/mocks historically hid from us (Pilot003 start_server, D10, D11,
# D12 all belonged to the class "real path never executed"):
#
#   1. lib_serve.sh ensure_server      — real vLLM bring-up, real GPU
#   2. lib_calibrate.sh full body      — env validation, grid probe, chosen.json
#   3. lib_generate.sh full body       — --set/--out pairs, marker reuse, output rows
#   4. marker reuse + teardown         — second lib must NOT duplicate bring-up
#
# Usage (on the pod, AFTER git pull of the amended pipeline, BEFORE ignition):
#   bash ~/effiq/pilot005/pipe005/pipeline/preflight_smoke.sh
# Exit 0 + "PREFLIGHT SMOKE: PASS" = safe to ignite. Anything else = do not
# ignite; paste the output.
# =====================================================================
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_HOME="${SMOKE_HOME:-/tmp/effiq-smoke}"
SMOKE_PORT="${SMOKE_PORT:-18099}"
MODEL_REPO="${SMOKE_MODEL_REPO:-Qwen/Qwen3-0.6B}"
say() { echo "[smoke $(date -u +%H:%M:%S)] $*"; }
fail() { echo "PREFLIGHT SMOKE: FAIL — $*" >&2; exit 1; }

teardown() {
  [ -f /tmp/.effiq-server-pid ] && kill "$(cat /tmp/.effiq-server-pid)" 2>/dev/null || true
  rm -f /tmp/.effiq-server-up /tmp/.effiq-server-pid
}
trap teardown EXIT

say "0/4 sanity: no real server may be running on $SMOKE_PORT"
curl -sf "http://127.0.0.1:${SMOKE_PORT}/v1/models" >/dev/null 2>&1 && fail "port $SMOKE_PORT already serving — is a real run alive? refuse to proceed"
rm -rf "$SMOKE_HOME"; mkdir -p "$SMOKE_HOME/run"

say "1/4 fetching tiny model $MODEL_REPO (real HF path, real weights)"
python3 - "$MODEL_REPO" "$SMOKE_HOME/model" <<'PY'
import sys
from huggingface_hub import snapshot_download
snapshot_download(sys.argv[1], local_dir=sys.argv[2])
print("weights ready")
PY
[ -d "$SMOKE_HOME/model" ] || fail "model dir missing after download"

export MODEL_DIR="$SMOKE_HOME/model" PORT="$SMOKE_PORT" MAX_MODEL_LEN=2048

say "2/4 lib_serve.sh real bring-up (vLLM load ~1-3 min for 0.6B)"
export SERVE_EXTRA=""
source "$PIPELINE_DIR/lib_serve.sh"
ensure_server || fail "ensure_server returned non-zero"
curl -sf "http://127.0.0.1:${PORT}/v1/models" >/dev/null || fail "server up-marker set but /v1/models dead"

say "3/4 lib_calibrate.sh real body (trivially-pass SLOs; we test the path, not the numbers)"
GRID_ORDER="1 64" SLO_TTFT_S=60 SLO_TPOT_MS=5000 COMPLIANCE_MIN=0.0 MODEL_DIR="$MODEL_DIR" MAX_MODEL_LEN="$MAX_MODEL_LEN" PORT="$PORT" CHOSEN_JSON="$SMOKE_HOME/chosen.json" RUN_DIR="$SMOKE_HOME/run" REQ_TIMEOUT_S=120 CLIENT_CONC=1 FILLER_SEED=0 MAX_TOKENS_CAP=64   bash "$PIPELINE_DIR/lib_calibrate.sh" > "$SMOKE_HOME/calibrate.out" 2>&1   || { tail -20 "$SMOKE_HOME/calibrate.out" >&2; fail "lib_calibrate.sh exited non-zero"; }
python3 -c "import json;d=json.load(open('$SMOKE_HOME/chosen.json'));assert 'concurrency' in d;print('  chosen.json valid:',d)"   || fail "chosen.json missing/invalid"

say "4/4 lib_generate.sh real body (marker-reuse path: server must NOT restart)"
printf '{"id":"smoke-1","text":"Reply with the single word: OK"}\n' > "$SMOKE_HOME/in.jsonl"
MODEL_DIR="$MODEL_DIR" PORT="$PORT" MAX_MODEL_LEN="$MAX_MODEL_LEN" GEN_CONC=1 MAX_TOKENS_CAP=32 TEMPERATURE=0 bash "$PIPELINE_DIR/lib_generate.sh" --set "$SMOKE_HOME/in.jsonl" --out "$SMOKE_HOME/out.jsonl" > "$SMOKE_HOME/generate.out" 2>&1 || { tail -20 "$SMOKE_HOME/generate.out" >&2; fail "lib_generate.sh exited non-zero"; }
python3 - "$SMOKE_HOME/out.jsonl" <<'PY' || fail "out.jsonl missing/invalid"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert len(rows) == 1 and rows[0].get("output", "").strip(), rows
print("  generation row valid:", rows[0]["output"][:40].strip() or "(empty)")
PY

say "teardown: killing smoke server, clearing marker"
teardown
trap - EXIT
echo "PREFLIGHT SMOKE: PASS — lib_serve + lib_calibrate + lib_generate all exercised on real vLLM. Safe to ignite."
