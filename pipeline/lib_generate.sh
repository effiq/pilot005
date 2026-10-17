#!/usr/bin/env bash
# lib_generate.sh — serve a model dir with vLLM and generate outputs for
# one or more sets. Extracted Pilot 002/004 craft; rules unchanged:
# temperature 0, natural stopping, spec concurrency; serve flags arrive as
# DATA (SERVE_EXTRA) — this script contains no model-conditional logic.
#
# Required env: MODEL_DIR PORT MAX_MODEL_LEN GEN_CONC MAX_TOKENS_CAP TEMPERATURE
# Optional env: SERVE_EXTRA (verbatim extra flags string, from spec data)
# Args: repeated  --set <in.jsonl> --out <out.jsonl>  pairs
set -euo pipefail

: "${MODEL_DIR:?}" "${PORT:?}" "${MAX_MODEL_LEN:?}" "${GEN_CONC:?}" "${MAX_TOKENS_CAP:?}" "${TEMPERATURE:?}"
SERVE_EXTRA="${SERVE_EXTRA:-}"

pairs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --set) pairs+=("SET:$2"); shift 2;;
    --out) pairs+=("OUT:$2"); shift 2;;
    *) echo "bad arg: $1" >&2; exit 2;;
  esac
done
[ "${#pairs[@]}" -gt 0 ] || { echo "no --set/--out pairs" >&2; exit 2; }

# serve: single-owned bring-up (Amendment-07, R15). SERVE_EXTRA honored inside.
source "$(dirname "${BASH_SOURCE[0]}")/lib_serve.sh"
ensure_server || exit 1

# generate
PORT="$PORT" GEN_CONC="$GEN_CONC" MAX_TOKENS_CAP="$MAX_TOKENS_CAP" TEMPERATURE="$TEMPERATURE" \
PAIRS="$(printf '%s\n' "${pairs[@]}")" python3 - <<'PY'
import json, os, urllib.request
from concurrent.futures import ThreadPoolExecutor
port = os.environ["PORT"]; conc = int(os.environ["GEN_CONC"])
cap = int(os.environ["MAX_TOKENS_CAP"]); temp = float(os.environ["TEMPERATURE"])
pairs = {}
cur = None
for line in os.environ["PAIRS"].splitlines():
    k, v = line.split(":", 1)
    if k == "SET": cur = v; pairs[cur] = None
    else: pairs[cur] = v

def gen(prompt):
    body = json.dumps({"model": "cell-model", "prompt": prompt,
                       "temperature": temp, "max_tokens": cap}).encode()
    req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())["choices"][0]["text"]

for set_path, out_path in pairs.items():
    rows = [json.loads(l) for l in open(set_path, encoding="utf-8") if l.strip()]
    with ThreadPoolExecutor(max_workers=conc) as ex:
        outs = list(ex.map(lambda r: gen(r["text"]), rows))
    with open(out_path, "w", encoding="utf-8") as f:
        for r, o in zip(rows, outs):
            f.write(json.dumps({"id": r["id"], "prompt": r["text"], "output": o},
                               ensure_ascii=False, sort_keys=True) + "\n")
    print(f"generated {len(outs)} -> {out_path}")
PY
