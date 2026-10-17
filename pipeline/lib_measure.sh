#!/usr/bin/env bash
# lib_measure.sh — one formal measurement run for stage 19: replay the cell's
# trace slices at the stage-15 operating point under arms in crossover order,
# write raw per-request rows, seal the run.
#
# Required env: RDIR ORDER SEED WINNER CHOSEN CKPT_ROOT PORT MAX_MODEL_LEN TRACE_DIR REPO_DIR
set -euo pipefail
for v in RDIR ORDER SEED WINNER CHOSEN CKPT_ROOT PORT MAX_MODEL_LEN TRACE_DIR REPO_DIR; do
  [ -n "${!v:-}" ] || { echo "lib_measure: missing env $v" >&2; exit 2; }
done

arm_dir() {  # resolve serve path + extra flags per arm (data, not branches)
  case "$1" in
    A) echo "$CKPT_ROOT/base|";;
    B) echo "$CKPT_ROOT/base|--quantization fp8";;
    C) echo "$CKPT_ROOT/$WINNER|--quantization compressed-tensors";;
  esac
}

for arm in $ORDER; do
  IFS='|' read -r MPATH EXTRA <<< "$(arm_dir "$arm")"
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  sleep 5
  nohup python3 -m vllm.entrypoints.openai.api_server \
    --model "$MPATH" --served-model-name cell-model \
    --max-model-len "$MAX_MODEL_LEN" --port "$PORT" \
    --gpu-memory-utilization 0.9472 --no-enable-prefix-caching \
    $EXTRA > "/tmp/vllm-measure-$arm.log" 2>&1 &
  echo $! > /tmp/.effiq-server-pid
  for i in $(seq 1 180); do
    curl -sf "http://127.0.0.1:${PORT}/v1/models" >/dev/null 2>&1 && break; sleep 10
  done
  curl -sf "http://127.0.0.1:${PORT}/v1/models" >/dev/null || { echo "server failed for arm $arm" >&2; exit 1; }

  RDIR="$RDIR" ARM="$arm" SEED="$SEED" CHOSEN="$CHOSEN" PORT="$PORT" TRACE_DIR="$TRACE_DIR" \
  python3 - <<'PY'
import json, os, random, time, urllib.request
from concurrent.futures import ThreadPoolExecutor
chosen = json.load(open(os.environ["CHOSEN"]))
conc = int(chosen["concurrency"]); mtok = int(chosen["max_tokens"])
rng = random.Random(int(os.environ["SEED"]))
trace = [json.loads(l) for l in open(f"{os.environ['TRACE_DIR']}/trace.jsonl", encoding="utf-8")]
rng.shuffle(trace)
slice_rows = trace[: conc * 4]                      # replay slice sized to the operating point
port = os.environ["PORT"]; arm = os.environ["ARM"]
raw = open(f"{os.environ['RDIR']}/raw_{arm}.jsonl", "w")

def one(row):
    body = json.dumps({"model": "cell-model", "prompt": row["text"],
                       "temperature": 0, "max_tokens": mtok}).encode()
    t0 = time.time()
    req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        d = json.loads(r.read())
    dt = time.time() - t0
    n = max(1, d["usage"]["completion_tokens"])
    return {"id": row["id"], "arm": arm, "latency_s": dt, "completion_tokens": n,
            "tps": n / dt, "tpot_ms": dt / n * 1000}

t_start = time.time()
with ThreadPoolExecutor(max_workers=conc) as ex:
    res = list(ex.map(one, slice_rows))
wall = time.time() - t_start
for r in res: raw.write(json.dumps(r, sort_keys=True) + "\n")
raw.close()
tps = [r["tps"] for r in res]
tpot = sorted(r["tpot_ms"] for r in res)
agg = {"arm": arm, "throughput_tps": sum(r["completion_tokens"] for r in res) / wall,
       "p95_tpot_ms": tpot[int(0.95 * len(tpot))],
       "p95_ttft_s": None,  # streaming probe fills this; non-streaming leaves null (declared)
       "n_requests": len(res), "wall_s": round(wall, 1)}
json.dump(agg, open(f"{os.environ['RDIR']}/meas_{arm}.json", "w"), indent=1)
print(f"  arm {arm}: {agg['throughput_tps']:.1f} tok/s over {len(res)} req")
PY
done
touch "$RDIR/RUN_COMPLETE"
