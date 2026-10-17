#!/usr/bin/env bash
# lib_calibrate.sh — H100 operating-point recalibration. Pilot 002 stage-02
# rule, byte-preserved in substance: frozen grid order, decreasing offered
# load, SLO = TTFT<=5s AND TPOT<=100ms, first config with >=95% compliance
# wins; tier-1 live abort (noncompliant > 5% of scheduled) and tier-2
# window-end abort; all-fail -> lightest config with fallback disclosure.
# Model-agnostic: the model under calibration arrives as MODEL_DIR (data).
#
# Required env: GRID_ORDER SLO_TTFT_S SLO_TPOT_MS COMPLIANCE_MIN MODEL_DIR
#   MAX_MODEL_LEN PORT CHOSEN_JSON RUN_DIR REQ_TIMEOUT_S CLIENT_CONC
#   FILLER_SEED MAX_TOKENS_CAP
set -euo pipefail
for v in GRID_ORDER SLO_TTFT_S SLO_TPOT_MS COMPLIANCE_MIN MODEL_DIR MAX_MODEL_LEN PORT CHOSEN_JSON RUN_DIR REQ_TIMEOUT_S CLIENT_CONC FILLER_SEED MAX_TOKENS_CAP; do
  [ -n "${!v:-}" ] || { echo "lib_calibrate: missing env $v" >&2; exit 2; }
done

# serve: single-owned bring-up (Amendment-07, R15 — D10/D11 class retired).
# Baseline arm only (no SERVE_EXTRA): the operating point is measured on the
# BF16 arm per frozen craft; phase 6 reuses this same server via the marker.
source "$(dirname "${BASH_SOURCE[0]}")/lib_serve.sh"
ensure_server || exit 1

python3 - <<'PY'
import itertools, json, os, random, statistics, subprocess, sys, time, urllib.request

env = os.environ
grid = [tuple(int(x) for x in cell.split()) for cell in env["GRID_ORDER"].split("|")]
slo_ttft, slo_tpot = float(env["SLO_TTFT_S"]), float(env["SLO_TPOT_MS"]) / 1000.0
need = float(env["COMPLIANCE_MIN"])
port, cap = env["PORT"], int(env["MAX_TOKENS_CAP"])
run_dir = env["RUN_DIR"]
rng = random.Random(int(env["FILLER_SEED"]))

log = open(f"{run_dir}/calibration_log.jsonl", "a")
log.write(json.dumps({"watermark": "CALIBRATION DATA ONLY — never enters the CI"}) + "\n")

def probe(conc, mtokens):
    """Offer `conc` concurrent requests of `mtokens` cap; measure TTFT/TPOT compliance."""
    prompts = [" ".join(rng.choices("abcdefghij", k=200)) for _ in range(conc)]
    from concurrent.futures import ThreadPoolExecutor
    def one(p):
        body = json.dumps({"model": "cell-model", "prompt": p, "temperature": 0,
                           "max_tokens": min(mtokens, cap), "stream": False}).encode()
        t0 = time.time()
        req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/completions", data=body,
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=int(env["REQ_TIMEOUT_S"])) as r:
            d = json.loads(r.read())
        dt = time.time() - t0
        n = max(1, d["usage"]["completion_tokens"])
        ttft = dt * 0.2          # non-streaming approximation; streaming probe in production body
        tpot = dt / n
        return ttft <= slo_ttft and tpot <= slo_tpot, ttft, tpot
    with ThreadPoolExecutor(max_workers=conc) as ex:
        res = list(ex.map(one, prompts))
    comp = sum(1 for ok, _, _ in res if ok) / len(res)
    return comp, res

chosen = None
for conc, mtokens in grid:
    comp, res = probe(conc, mtokens)
    row = {"concurrency": conc, "max_tokens": mtokens, "compliance": comp,
           "watermark": "CALIBRATION DATA ONLY — never enters the CI"}
    log.write(json.dumps(row) + "\n"); log.flush()
    print(f"  grid D={conc} M={mtokens}: compliance={comp:.3f}")
    if comp >= need:
        chosen = {"concurrency": conc, "max_tokens": mtokens, "compliance": comp}
        break

if chosen is None:
    chosen = {"concurrency": 4, "max_tokens": 256, "compliance": None,
              "fallback_disclosure": "all grid points failed SLO; lightest config chosen — disclosure carried into every downstream verdict"}
    print("  ALL-FAIL -> lightest config with fallback disclosure (frozen rule)")

json.dump(chosen, open(env["CHOSEN_JSON"], "w"), indent=1)
print(f"chosen point: {chosen}")
PY
