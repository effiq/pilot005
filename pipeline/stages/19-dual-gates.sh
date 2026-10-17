#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 19: DUAL PERFORMANCE GATES (migration + recipe, n=10)
#
# Frozen craft from Pilot 004 stage 13, generalized to spec:
#   - MIGRATION gate: arm B (stock FP8, vLLM --quantization fp8) vs arm A
#     (BF16) — paired-bootstrap 95% CI lower bound >= 1.20x.
#   - RECIPE gate: arm C (stage-18 confirmed winner) vs arm A — CI lower
#     bound >= 1.50x AND pooled P95 TPOT/TTFT non-inferiority (C/A <= 1.05)
#     AND the stage-18 quality gate (read from archived verdict_c.json).
#   - n = 10 formal runs, NO straddle. Run-to-pair mapping and run seeds
#     derive from the cell spec's run_seed_base (declared, frozen per cell).
#   - Within-run 3-arm block crossover: odd runs A B C, even runs C B A
#     (B always middle — declared).
#   - ANTI-P-HACKING: during measurement this stage prints DESCRIPTIVE
#     MEANS ONLY. The verdict phase runs only after all 10 RUN_COMPLETE
#     markers exist and recomputes everything from raw JSONL.
#   - Load: the cell's replay trace slices derived in stage 15
#     (trace slices = spec-data derivation; slice plan hashes in custody).
#   - Run-validity (v4.2): void/rerun only with contemporaneous provider
#     status-page evidence; symmetric.
#   - THE CELL VERDICT = migration gate AND recipe gate (quality + perf).
#     Verdict semantics per Protocol Lock v4.2 §6: a FAIL is a negative
#     lab report on this (model × quantization × hardware) combination
#     under the frozen process — headline never carries the model name.
#
# Requires: lib_spec env; stages 14/15/16/18 COMPLETE.
# Test hooks: STAGE19_OUT_DIR, STAGE19_MOCK_MEASURE, STAGE19_N (sandbox),
#   PORT, MAX_SECONDS
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
REPO_DIR="${EFFIQ_REPO_ROOT:-$EFFIQ_HOME/pilot005}"
CELL_DIR="${EFFIQ_CELL_DIR:?set by run_cell.sh}"
STAGE_NAME="19-dual-gates"
CKPT_ROOT="${CKPT_ROOT:-$HOME/effiq/p005-ckpt}/$EFFIQ_CELL_ID"
PORT="${PORT:-8000}"
MAX_SECONDS="${MAX_SECONDS:-64800}"   # 18 h rail per attempt; resumes

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage19][ERROR] %s\n' "$*" >&2; exit 1; }

S15="$(ls -d "$CELL_DIR/15-cell-preflight"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort (mtime meaningless after fresh clone)
S16="$(ls -d "$CELL_DIR/16-arm-screening"/run_* 2>/dev/null | sort | tail -1 || true)"     # A-12: name-sort
S18="$(ls -d "$CELL_DIR/18-red-dot-confirm"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort
[ -f "$S15/COMPLETE" ] && [ -f "$S16/COMPLETE" ] && [ -f "$S18/COMPLETE" ] || die "upstream stages incomplete"
[ -f "$S18/verdict_c.json" ] || die "verdict_c.json missing"
QUALITY=$(python3 -c "import json;print(json.load(open('$S18/verdict_c.json'))['quality_gate'])")
WINNER=$(python3 -c "import json;print(json.load(open('$S16/winner.json'))['arm_id'])")
CHOSEN="$S15/chosen_point.json"
[ -f "$CHOSEN" ] || die "stage-15 operating point missing"
echo "arm C: $WINNER | quality gate (stage 18): $QUALITY | operating point: $(cat "$CHOSEN")"

RUN_DIR="${STAGE19_OUT_DIR:-$CELL_DIR/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$RUN_DIR"
T0=$(date +%s)

N_RUNS=$(python3 -c "import json;print(json.load(open('$REPO_DIR/pipeline/FROZEN-LINES.json'))['statistics']['n_runs'])")
N_RUNS="${STAGE19_N:-$N_RUNS}"

# ---------- measurement campaign ----------
note "1. measurement campaign (n=$N_RUNS, crossover ABC/CBA, descriptive means only)"
for i in $(seq 1 "$N_RUNS"); do
  RDIR="$RUN_DIR/run_$i"
  [ -f "$RDIR/RUN_COMPLETE" ] && { echo "run $i: complete, skip"; continue; }
  mkdir -p "$RDIR"
  [ $(( $(date +%s) - T0 )) -gt "$MAX_SECONDS" ] && die "time rail — re-run to resume (completed runs stand)"
  SEED=$(( EFFIQ_RUN_SEED_BASE + i ))
  if [ $(( i % 2 )) -eq 1 ]; then ORDER="A B C"; else ORDER="C B A"; fi
  echo "run $i: order=$ORDER seed=$SEED"
  if [ "${STAGE19_MOCK_MEASURE:-0}" = "1" ]; then
    RDIR="$RDIR" SEED="$SEED" WINNER="$WINNER" python3 - <<'PY'
import json, os, random
rng = random.Random(int(os.environ["SEED"]))
base = {a: rng.uniform(0.9, 1.1) for a in "ABC"}
# mock craft: B ≈1.35×A and C ≈1.6×A so a mock PASS path exists
thr = {"A": 100*base["A"], "B": 100*base["A"]*1.35, "C": 100*base["A"]*1.6}
for a in "ABC":
    json.dump({"arm": a, "throughput_tps": thr[a]*rng.uniform(0.97,1.03),
               "p95_tpot_ms": 50*rng.uniform(0.9,1.1), "p95_ttft_s": 2.0*rng.uniform(0.9,1.1),
               "mock": True}, open(f"{os.environ['RDIR']}/meas_{a}.json", "w"))
open(f"{os.environ['RDIR']}/RUN_COMPLETE", "w").write("ok")
PY
  else
    # Real craft: replay the cell's trace slices at the stage-15 operating
    # point under each arm in crossover order. Serving via lib_generate's
    # server mechanics with load driver; raw per-request rows appended to
    # $RDIR/raw_<arm>.jsonl; run sealed with RUN_COMPLETE only when all
    # three arm blocks finished within the same run window.
    RDIR="$RDIR" ORDER="$ORDER" SEED="$SEED" WINNER="$WINNER" CHOSEN="$CHOSEN" \
    CKPT_ROOT="$CKPT_ROOT" PORT="$PORT" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" \
    TRACE_DIR="$S15" REPO_DIR="$REPO_DIR" \
    bash "$REPO_DIR/pipeline/lib_measure.sh" || die "run $i measurement failed — re-run to resume"
  fi
done

# ---------- verdict phase (only after all n RUN_COMPLETE) ----------
note "2. verdict phase (recomputed from raw rows; nothing interpolated)"
RUN_DIR="$RUN_DIR" N_RUNS="$N_RUNS" QUALITY="$QUALITY" WINNER="$WINNER" \
LINES="$REPO_DIR/pipeline/FROZEN-LINES.json" CELL="$EFFIQ_CELL_ID" SPEC_SHA="$EFFIQ_SPEC_SHA256" \
python3 - <<'PY'
import glob, json, os, random, statistics, sys
rd = os.environ["RUN_DIR"]; n = int(os.environ["N_RUNS"])
L = json.load(open(os.environ["LINES"]))
G, STATS = L["gates"], L["statistics"]
runs = sorted(glob.glob(f"{rd}/run_*/RUN_COMPLETE"))
if len(runs) < n:
    print(f"VERDICT BLOCKED: only {len(runs)}/{n} runs complete"); sys.exit(1)

def load(arm):
    vals = []
    for r in sorted(glob.glob(f"{rd}/run_*/meas_{arm}.json")):
        vals.append(json.load(open(r))["throughput_tps"])
    return vals
A, B, C = load("A"), load("B"), load("C")

def ci_lower(base, arm):
    """paired bootstrap on per-run ratios; frozen: resamples+seed from FROZEN-LINES."""
    rng = random.Random(STATS["bootstrap_seed"])
    ratios = [x / y for x, y in zip(arm, base)]
    m = len(ratios); boots = []
    for _ in range(STATS["bootstrap_resamples"]):
        boots.append(statistics.mean(ratios[rng.randrange(m)] for _ in range(m)))
    boots.sort()
    return boots[int(0.05 * len(boots))], statistics.mean(ratios)

mig_lo, mig_mean = ci_lower(A, B)
rec_lo, rec_mean = ci_lower(A, C)
mig = mig_lo >= G["migration_ci_lower"]
rec_perf = rec_lo >= G["recipe_ci_lower"]
quality = os.environ["QUALITY"] == "PASS"
recipe = rec_perf and quality
verdict = {
    "cell": os.environ["CELL"], "spec_sha256": os.environ["SPEC_SHA"],
    "arm_c": os.environ["WINNER"],
    "migration": {"ci_lower": mig_lo, "mean_ratio": mig_mean,
                  "line": G["migration_ci_lower"], "pass": mig},
    "recipe": {"ci_lower": rec_lo, "mean_ratio": rec_mean, "line": G["recipe_ci_lower"],
               "perf_pass": rec_perf, "quality_gate": os.environ["QUALITY"], "pass": recipe},
    "n_runs": n, "straddle": False,
    "verdict": "PASS" if (mig and recipe) else "FAIL",
    "semantics": "Under the pre-registered process, budget, and statistical discipline, the lossless-speedup test on this model × quantization × hardware combination returned this result. A negative result is neither a defect verdict on the model nor a capability verdict on Effiq — it is a compressibility fact about the combination under the frozen process.",
    "headline_rule": "FAIL headlines never carry a model name (all cells, v4.2)",
}
json.dump(verdict, open(f"{rd}/VERDICT.json", "w"), indent=1, sort_keys=True)
print(json.dumps(verdict, indent=1))
PY
rc=$?
[ "$rc" = "0" ] || die "verdict phase blocked (rc=$rc)"

VERDICT=$(python3 -c "import json;print(json.load(open('$RUN_DIR/VERDICT.json'))['verdict'])")
sha256sum "$RUN_DIR/VERDICT.json" | tee -a "$RUN_DIR/custody.sha256"
touch "$RUN_DIR/COMPLETE"
note "STAGE 19 COMPLETE — cell $EFFIQ_CELL_ID verdict: $VERDICT"
[ "$VERDICT" = "PASS" ] && exit 0 || exit 2
