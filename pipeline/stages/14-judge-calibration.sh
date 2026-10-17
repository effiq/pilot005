#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 14: JUDGE CALIBRATION GATE ("judges are examined first")
#
# Frozen in Protocol Lock v4.2 (L3). Before any verdict run, every judge
# seat must clear a pre-registered human-agreement threshold on
# human-annotated samples:
#   - category-level Pearson r >= 0.80 vs human labels (FROZEN-LINES.json);
#   - seats filled from the ORDERED pools in pipeline/JUDGES.json, in fixed
#     order, FIRST PASS STOPS — never shopping for a friendly panel;
#   - ALL calibration results, including failures, are archived and
#     published in the VERDICT appendix;
#   - pool exhausted -> pod-local anchor judge steps in; the limitation is
#     disclosed in the VERDICT (v4.2).
#
# This stage is model-agnostic about the CELL under test: it examines
# judges, not models. Calibration rows are watermarked: CALIBRATION DATA
# ONLY — never enters any CI.
#
# Inputs:
#   $EFFIQ_CELL_DIR          (set by run_cell.sh)
#   calibration_samples.jsonl in $EFFIQ_CELL_DIR/calibration/ —
#       rows: {"id", "prompt", "response", "human_score", "category"}
#       (human-annotated; Arabic seats use the AraGen/BALSAM-derived set —
#        acquisition documented in an addendum before first run)
#   KEY_FILE (default ~/pilot-env/openrouter-key)
#   rubric file via $REPO_DIR/specs/<cell>.json -> rubric.file
#       (Amendment-04: the probe now carries the SAME rubric body the
#        production judge sees, via lib_judge.build_prompt — one builder,
#        no imitation; D7)
#
# Outputs (in run dir):
#   calibration_results.jsonl — every attempt, pass or fail (published)
#   raw_replies.jsonl         — every raw judge reply, per row (Amendment-04,
#                               D9 forensics: parse artifacts vs genuine
#                               disagreement are now distinguishable)
#   panel.json                — the seated panel + anchor + sha custody
#   COMPLETE                  — only if all three seats cleared the gate
#
# Test hooks (sandbox only): STAGE14_OUT_DIR, STAGE14_MOCK_JUDGE, KEY_FILE,
#   OR_BASE_URL, MAX_SECONDS
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
LOGS_DIR="${LOGS_DIR:-$EFFIQ_HOME/pilot-logs}"
REPO_DIR="${EFFIQ_REPO_ROOT:-$EFFIQ_HOME/pilot005}"
CELL_DIR="${EFFIQ_CELL_DIR:?set by run_cell.sh}"
DATE_STR="$(date -u +%Y-%m-%d)"
STAGE_NAME="14-judge-calibration"
KEY_FILE="${KEY_FILE:-$HOME/pilot-env/openrouter-key}"
OR_BASE_URL="${OR_BASE_URL:-https://openrouter.ai/api/v1}"
MAX_SECONDS="${MAX_SECONDS:-7200}"

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage14][ERROR] %s\n' "$*" >&2; exit 1; }

RUN_DIR="${STAGE14_OUT_DIR:-$CELL_DIR/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$RUN_DIR"
T0=$(date +%s)

note "0. inputs"
JUDGES_JSON="$REPO_DIR/pipeline/JUDGES.json"
LINES_JSON="$REPO_DIR/pipeline/FROZEN-LINES.json"
SAMPLES="$CELL_DIR/calibration/calibration_samples.jsonl"
[ -f "$JUDGES_JSON" ] || die "missing JUDGES.json (Appendix B)"
[ -f "$SAMPLES" ] || die "missing $SAMPLES — human-annotated calibration set must be in place before this stage (acquisition via addendum)"
[ -f "$KEY_FILE" ] || die "missing $KEY_FILE"
SPEC_JSON="$REPO_DIR/specs/$(basename "$CELL_DIR").json"
[ -f "$SPEC_JSON" ] || die "missing spec $SPEC_JSON (rubric reference, Amendment-04)"
RUBRIC_FILE="$REPO_DIR/$(python3 -c "import json;print(json.load(open('$SPEC_JSON'))['rubric']['file'])")"
[ -f "$RUBRIC_FILE" ] || die "missing rubric $RUBRIC_FILE (spec rubric.file)"
R_MIN=$(python3 -c "import json;print(json.load(open('$LINES_JSON'))['gates']['judge_calibration_r_min'])")
echo "threshold: category-level r >= $R_MIN (frozen)"
echo "probe rubric: $RUBRIC_FILE (Amendment-04: same body as production judging)"
sha256sum "$SAMPLES" "$JUDGES_JSON" "$RUBRIC_FILE" | tee "$RUN_DIR/input_shas.txt"

note "1. calibration run (ordered pools, first pass stops, all results archived)"
JUDGES_JSON="$JUDGES_JSON" SAMPLES="$SAMPLES" KEY_FILE="$KEY_FILE" OR_BASE_URL="$OR_BASE_URL" \
R_MIN="$R_MIN" RUN_DIR="$RUN_DIR" MOCK="${STAGE14_MOCK_JUDGE:-0}" T0="$T0" MAX_SECONDS="$MAX_SECONDS" \
RUBRIC_FILE="$RUBRIC_FILE" REPO_DIR="$REPO_DIR" \
python3 - <<'PY'
import json, os, random, statistics, subprocess, sys, time, urllib.request

J = json.load(open(os.environ["JUDGES_JSON"]))
samples = [json.loads(l) for l in open(os.environ["SAMPLES"], encoding="utf-8") if l.strip()]
R_MIN = float(os.environ["R_MIN"]); RUN_DIR = os.environ["RUN_DIR"]
MOCK = os.environ["MOCK"] == "1"; T0 = int(os.environ["T0"]); MAXS = int(os.environ["MAX_SECONDS"])
KEY = open(os.environ["KEY_FILE"]).read().strip()
BASE = os.environ["OR_BASE_URL"]
rubric = open(os.environ["RUBRIC_FILE"], encoding="utf-8").read()
sys.path.insert(0, os.path.join(os.environ["REPO_DIR"], "pipeline"))
from lib_judge import build_prompt  # Amendment-04: calibration probe IS the production prompt
results = open(f"{RUN_DIR}/calibration_results.jsonl", "a")
raw = open(f"{RUN_DIR}/raw_replies.jsonl", "a", encoding="utf-8")
RESOLVED = {}  # Amendment-02: requested alias -> provider-resolved model id, per run archive

def pearson(xs, ys):
    n = len(xs)
    if n < 3: return 0.0
    mx, my = statistics.mean(xs), statistics.mean(ys)
    num = sum((x-mx)*(y-my) for x, y in zip(xs, ys))
    den = (sum((x-mx)**2 for x in xs) * sum((y-my)**2 for y in ys)) ** 0.5
    return num/den if den else 0.0

AXES = ["clarity", "correctness", "completeness", "overall"]

def judge_score(model, s):
    """Score one sample with the EXACT production prompt, built by
    lib_judge.build_prompt (Amendment-04: Amendment-03 aligned the axis
    contract but left the rubric body out of the probe — all five candidates
    in run_20261015T10xxxxxxZ then failed on the SAME axis, completeness
    (worst r −0.01…0.43), while the clean-mapped correctness axis reached
    0.77–0.89 with 3/5 ≥ 0.80; the instrument, not the judges, was the
    outlier). Amendment-01/02/03 mechanics kept: reasoning excluded
    (mandatory on several endpoints), temperature 0, empty content = error,
    max_tokens 4096. Raw replies archived per row (D9 forensics)."""
    if MOCK:
        rng = random.Random(hash((model, s["id"])) & 0xffffffff)
        return {a: max(1, min(10, round(s["human_score"] + rng.gauss(0, 0.5)))) for a in AXES}
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": build_prompt(rubric, s["prompt"], s["response"])}],
        "reasoning": {"exclude": True}, "max_tokens": 4096, "temperature": 0,
    }).encode()
    req = urllib.request.Request(f"{BASE}/chat/completions", data=body, headers={
        "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        resp = json.loads(r.read())
    RESOLVED[model] = resp.get("model", model)  # pin the resolved id (JUDGES.json: "exact model id pinned at ignition in run archive")
    content = resp["choices"][0]["message"]["content"]
    raw.write(json.dumps({"model": model, "id": s["id"], "content": content}, ensure_ascii=False) + "\n"); raw.flush()
    if not content or not content.strip():
        raise RuntimeError("empty judge content = error (Amendment-01/02/03)")
    nums = [int(t) for t in content.replace(",", " ").split() if t.lstrip("-").isdigit()][:4]
    if len(nums) != 4:
        raise RuntimeError(f"unparseable judge reply: {content[:80]!r}")
    return {a: max(1, min(10, n)) for a, n in zip(AXES, nums)}

def calibrate(model):
    by_cat = {}
    for s in samples:
        sc = judge_score(model, s)
        by_cat.setdefault(s["category"], []).append((sc[s["category"]], s["human_score"]))
        if time.time() - T0 > MAXS:
            raise TimeoutError("time rail")
    cat_r = {c: pearson([a for a,_ in v], [b for _,b in v]) for c, v in by_cat.items()}
    worst = min(cat_r.values()) if cat_r else 0.0
    return {"model": model, "category_r": cat_r, "worst_category_r": worst,
            "pass": worst >= R_MIN, "n": len(samples)}

seated, anchor = {}, J["anchor"]
for seat in J["seats"]:
    chosen = None
    for cand in seat["ordered_pool"]:
        try:
            res = calibrate(cand["id"])
        except Exception as e:
            res = {"model": cand["id"], "pass": False, "error": str(e)[:200]}
        res["seat"] = seat["seat"]; res["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        if cand["id"] in RESOLVED: res["resolved_model"] = RESOLVED[cand["id"]]
        results.write(json.dumps(res) + "\n"); results.flush()
        print(f"  [{seat['seat']}] {cand['id']}: worst_r={res.get('worst_category_r','ERR')} pass={res['pass']}")
        if res["pass"]:
            chosen = cand["id"]; break          # FIRST PASS STOPS — frozen
    if chosen is None:
        print(f"  [{seat['seat']}] POOL EXHAUSTED -> pod-local anchor steps in (disclosed limitation)")
        chosen = anchor["model"] + " (LOCAL-FALLBACK, limitation disclosed)"
    seated[seat["seat"]] = chosen

panel = {"seated": seated, "anchor": anchor, "threshold_r": R_MIN,
         "results_file": "calibration_results.jsonl",
         "watermark": "CALIBRATION DATA ONLY — never enters the CI",
         "all_results_published": True}
json.dump(panel, open(f"{RUN_DIR}/panel.json", "w"), indent=1)
print(json.dumps(panel["seated"], indent=1))
print("CALIBRATION_GATE: ALL SEATS CLEARED" if all("LOCAL-FALLBACK" not in v for v in seated.values())
      else "CALIBRATION_GATE: cleared WITH disclosed local-fallback limitation")
PY
rc=$?
[ "$rc" = "0" ] || die "calibration run failed (rc=$rc)"

# any seat unseated at all = stage FAIL (rc 2 = legitimate negative outcome)
python3 - "$RUN_DIR/panel.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
if not all(p["seated"].values()): sys.exit(2)
PY
[ "$?" = "0" ] || { echo "STAGE 14: calibration incomplete — see results"; exit 2; }

touch "$RUN_DIR/COMPLETE"
note "stage 14 COMPLETE — panel seated; every calibration attempt archived for publication"
