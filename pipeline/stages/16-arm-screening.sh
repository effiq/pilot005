#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 16: ARM SCREENING (spec-driven generalization of 004 st.11)
#
# Frozen craft carried over byte-in-substance from Pilot 004:
#   - Two-phase anti-p-hacking: THIS stage is the cheap phase; the winner
#     gets ONE confirmation shot in stage 18. No second shot without addendum.
#   - Wave 1 arms (lever classes are model-agnostic; recipe bodies live in
#     the gate-layer ~/pilot-env/arms-recipes.json, pod-only):
#       b0-control        stock FP8 (vLLM dynamic) — no build
#       b1-profile-exempt profile-driven minimal exemption (composed here)
#       b2-smooth-exempt  activation smoothing + minimal exemption
#       b3-a4-kv          sensitive-exemption + KV-cache FP8
#   - Wave 2: one arm composed by the deterministic rule merge(top1, top2)
#     of the wave-1 ranking (tie-break: overall delta, then arm_id).
#   - Sensitivity profiling: per-module relative output MSE of FP8-E4M3
#     fake-quantized modules vs BF16 over the cell's 256 calibration texts;
#     module scope arrives as SPEC DATA (EFFIQ_PROFILE_SCOPE) — this script
#     contains no architecture-conditional logic (v4.2 classification test).
#   - Screening judge: ONE judge (first seated chief from stage 14
#     panel.json). Screening numbers are indicative; stage 18 uses the panel.
#   - Winner: argmax clarity delta among non-control arms; tie-breaks
#     overall delta, fewer levers, arm_id. PROCEED iff winner clarity
#     delta >= -0.05 (frozen margin, FROZEN-LINES.json); otherwise
#     SCREENING-EXHAUSTED — a legitimate publishable FAIL (exit 2).
#   - Profile priors (frozen rule, H2 material): same-family cells MAY reuse
#     a prior profile (decision recorded in run archive); cross-family cells
#     MUST profile fresh. Implemented as data: gate-layer file either carries
#     "reuse_profile_of" or not; this script records which path ran.
#
# Requires: lib_spec.sh env; stage 15 COMPLETE (anchors + gen_R reference).
# Verify: bash stages/16-arm-screening.sh --verify [run_dir]
# Test hooks (sandbox): STAGE16_OUT_DIR, STAGE16_MOCK_BUILD,
#   STAGE16_MOCK_PROFILE, STAGE16_MOCK_JUDGE, STAGE16_SKIP_SERVER, PORT,
#   MAX_SECONDS, JUDGE_TOKEN_CAP, RECIPES_FILE, CKPT_ROOT
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
LOGS_DIR="${LOGS_DIR:-$EFFIQ_HOME/pilot-logs}"
REPO_DIR="${EFFIQ_REPO_ROOT:-$EFFIQ_HOME/pilot005}"
CELL_DIR="${EFFIQ_CELL_DIR:?set by run_cell.sh}"
STAGE_NAME="16-arm-screening"
CKPT_ROOT="${CKPT_ROOT:-$HOME/effiq/p005-ckpt}/$EFFIQ_CELL_ID"
RECIPES_FILE="${RECIPES_FILE:-$HOME/pilot-env/arms-recipes.json}"
KEY_FILE="${KEY_FILE:-$HOME/pilot-env/openrouter-key}"
OR_BASE_URL="${OR_BASE_URL:-https://openrouter.ai/api/v1}"
PORT="${PORT:-8000}"
MAX_SECONDS="${MAX_SECONDS:-28800}"
JUDGE_TOKEN_CAP="${JUDGE_TOKEN_CAP:-4000000}"

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage16][ERROR] %s\n' "$*" >&2; exit 1; }

# ---------- locate stage-15 COMPLETE anchors ----------
S15="$(ls -d "$CELL_DIR/15-cell-preflight"/run_* 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort (mtime is meaningless after a fresh clone)
[ -n "$S15" ] && [ -f "$S15/COMPLETE" ] || die "stage 15 COMPLETE not found for cell $EFFIQ_CELL_ID"
SCREEN_JSONL="$S15/screening_set.jsonl"
CALIB_TXT="$S15/calibration_texts.jsonl"
GENR_JSONL="$S15/gen_R.jsonl"
PANEL_JSON="$(ls -d "$CELL_DIR/14-judge-calibration"/run_*/panel.json 2>/dev/null | sort | tail -1 || true)"   # A-12: name-sort
[ -f "$PANEL_JSON" ] || die "stage 14 panel.json not found (judges must be seated first)"
for f in "$SCREEN_JSONL" "$CALIB_TXT" "$GENR_JSONL"; do [ -f "$f" ] || die "missing stage-15 artifact: $f"; done

# Amendment-12: own-dir resume (same pattern as stage-15). Previously every
# entry minted a NEW run dir, forcing full rebuild+regen after any crash.
if [ -n "${STAGE16_OUT_DIR:-}" ]; then
  RUN_DIR="$STAGE16_OUT_DIR"
else
  RUN_DIR=""
  for cand in $(ls -d "$CELL_DIR/$STAGE_NAME"/run_* 2>/dev/null | sort -r); do   # A-12: name-sort, newest first
    [ -f "$cand/COMPLETE" ] || { RUN_DIR="$cand"; echo "resuming: $RUN_DIR"; break; }
  done
  [ -n "$RUN_DIR" ] || { RUN_DIR="$CELL_DIR/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)"; echo "new run dir: $RUN_DIR"; }
fi
mkdir -p "$RUN_DIR"
T0=$(date +%s)
rail() { [ $(( $(date +%s) - T0 )) -gt "$MAX_SECONDS" ] && die "time rail — re-run to resume"; return 0; }

PROFILE_JSON="$CKPT_ROOT/profile.json"             # gate-layer, pod-only
PROFILE_REF="$RUN_DIR/profile_ref.json"            # public: sha + method only
RECIPE_LOG="$RUN_DIR/recipes_executed.jsonl"       # public: hashes + labels only
LOCAL_RECIPE_LOG="$CKPT_ROOT/recipes-local.jsonl"  # pod-only full bodies
CKPT_LOG="$RUN_DIR/checkpoints.jsonl"
touch "$RECIPE_LOG" "$CKPT_LOG"
mkdir -p "$CKPT_ROOT"

note "0. custody inputs"
sha256sum "$SCREEN_JSONL" "$CALIB_TXT" "$GENR_JSONL" "$PANEL_JSON" | tee "$RUN_DIR/input_shas.txt"
[ -f "$RECIPES_FILE" ] || die "gate-layer recipes file missing: $RECIPES_FILE"
SCREEN_JUDGE=$(python3 -c "import json;print(json.load(open('$PANEL_JSON'))['seated']['chief'])")
echo "screening judge (indicative): $SCREEN_JUDGE"

# Amendment-12 (D19): local-fallback judging path. When the seated judge is the
# sentinel (pool exhausted in stage 14, limitation disclosed), judging runs on
# the pod-local anchor (base model, BF16, served via the single-owner lib_serve
# contract). Server is brought up only around judging phases and torn down
# before any GPU-hungry build/gen phase.
LOCAL_JUDGE_ACTIVE=0
if [[ "$SCREEN_JUDGE" == *LOCAL-FALLBACK* ]]; then
  LOCAL_JUDGE_ARGS=(--local-base "http://127.0.0.1:$PORT/v1")
else
  LOCAL_JUDGE_ARGS=()
fi
judge_server_up() {
  [[ "$SCREEN_JUDGE" == *LOCAL-FALLBACK* ]] || return 0
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  sleep 5
  source "$REPO_DIR/pipeline/lib_serve.sh"
  MODEL_DIR="$CKPT_ROOT/base" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" PORT="$PORT" SERVE_EXTRA="" ensure_server \
    || die "anchor judge server failed to start (local-fallback path)"
  LOCAL_JUDGE_ACTIVE=1
  echo "  local-fallback judge: anchor server up on :$PORT (base model, BF16, thinking disabled per-call)"
}
judge_server_down() {
  [ "$LOCAL_JUDGE_ACTIVE" = "1" ] || return 0
  rm -f /tmp/.effiq-server-up
  kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  rm -f /tmp/.effiq-server-pid
  LOCAL_JUDGE_ACTIVE=0
  echo "  anchor judge server down"
}

# ---------- 1. sensitivity profiling (or declared same-family reuse) ----------
# teardown any inherited server before GPU-exclusive phases (D15 repair,
# Amendment-09): stage-15 leaves its vLLM server holding ~75GB; the profiler
# below needs the whole card. Mirrors the per-arm teardown in gen_arm().
rm -f /tmp/.effiq-server-up
kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
rm -f /tmp/.effiq-server-pid
for i in $(seq 1 12); do
  used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0)
  [ "${used:-0}" -lt 2048 ] && break
  sleep 5
done

note "1. sensitivity profile (scope=$EFFIQ_PROFILE_SCOPE)"
PROFILE_PATH_NOTE="fresh-profiling"
if grep -q '"reuse_profile_of"' "$RECIPES_FILE"; then
  # same-family reuse path (H2 material): the gate-layer file declares reuse;
  # the prior profile must be staged at $PROFILE_JSON by the operator BEFORE
  # this stage — the declaration and its source sha are recorded in the archive.
  [ -f "$PROFILE_JSON" ] || die "profile reuse declared in gate-layer file but no profile staged at $PROFILE_JSON — stage it (operator action, counts in Appendix A) and re-run"
  PROFILE_PATH_NOTE="reused-per-frozen-prior-rule (declaration in gate-layer file; source recorded)"
  echo "profile reuse path (frozen same-family rule): $PROFILE_PATH_NOTE"
  echo "{\"path\": \"reuse\", \"profile_sha256\": \"$(sha256sum "$PROFILE_JSON" | cut -d' ' -f1)\", \"rule\": \"same-family reuse permitted; H2 material\"}" > "$RUN_DIR/profile_path.json"
fi
if [ -f "$PROFILE_JSON" ]; then
  echo "profile.json present — resume skip ($(sha256sum "$PROFILE_JSON" | cut -c1-16)…)"
elif [ "${STAGE16_MOCK_PROFILE:-0}" = "1" ]; then
  python3 -c "
import json, os, random
rng = random.Random(1)
mods = [f'model.layers.{i}.self_attn.{p}' for i in range(8) for p in ('q_proj','k_proj','v_proj','o_proj')]
doc = {'method': 'MOCK (sandbox)', 'scope': os.environ.get('SCOPE_RX', 'mock'), 'modules': sorted(({'module': m, 'mse_rel': rng.random()} for m in mods), key=lambda r: -r['mse_rel'])}
json.dump(doc, open('$PROFILE_JSON', 'w'))"
  echo "TEST HOOK: STAGE16_MOCK_PROFILE=1"
else
  MODEL_DIR="$CKPT_ROOT/base"
  [ -d "$MODEL_DIR" ] || MODEL_DIR="$CKPT_ROOT/../$EFFIQ_CELL_ID/base"
  [ -d "$MODEL_DIR" ] || die "base weights not found under $CKPT_ROOT — stage 15 must complete first"
  MODEL_DIR="$MODEL_DIR" CALIB_JSONL="$CALIB_TXT" SCOPE_RX="$EFFIQ_PROFILE_SCOPE" \
  PROFILE="$PROFILE_JSON" START_TS="$T0" MAX_SECONDS="$MAX_SECONDS" python3 - <<'PY'
import hashlib, json, os, re, time
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

RESERVOIR = 4096; RES_SEED = 20265002; MAX_TOK = 1024   # frozen profiling craft
SCOPE = re.compile(os.environ["SCOPE_RX"])               # module scope = SPEC DATA
calib = [json.loads(l)["text"] for l in open(os.environ["CALIB_JSONL"])]
tok = AutoTokenizer.from_pretrained(os.environ["MODEL_DIR"])
model = AutoModelForCausalLM.from_pretrained(os.environ["MODEL_DIR"],
        torch_dtype=torch.bfloat16, device_map="cuda")
model.eval()
rng = torch.Generator().manual_seed(RES_SEED)
caps, counts = {}, {}
def mk_hook(name):
    def hook(mod, args):
        x = args[0].detach(); rows = x.reshape(-1, x.shape[-1]); n = rows.shape[0]
        counts[name] = counts.get(name, 0) + n
        take = min(RESERVOIR - (caps[name].shape[0] if name in caps else 0), n)
        if take > 0:
            idx = torch.randperm(n, generator=rng)[:take]
            add = rows[idx].to(torch.float32).cpu()
            caps[name] = add if name not in caps else torch.cat([caps[name], add], 0)
    return hook
handles = [m.register_forward_pre_hook(mk_hook(n)) for n, m in model.named_modules()
           if SCOPE.match(n) and isinstance(m, torch.nn.Linear)]
assert handles, f"profiling scope matched ZERO modules — spec regex wrong for this architecture: {SCOPE.pattern}"
print(f"hooks on {len(handles)} modules", flush=True)
with torch.no_grad():
    for i in range(0, len(calib), 8):
        if time.time() - int(os.environ["START_TS"]) > int(os.environ["MAX_SECONDS"]):
            raise SystemExit("time rail during profiling — re-run to resume")
        b = tok(calib[i:i+8], return_tensors="pt", padding=True, truncation=True, max_length=MAX_TOK).to("cuda")
        model(**b)
for h in handles: h.remove()
prof = []
for name, mod in model.named_modules():
    if name not in caps: continue
    W = mod.weight.detach().to(torch.float32)
    scale = (W.abs().max().clamp_min(1e-12)) / 448.0
    Wq = (torch.clamp(W / scale, -448.0, 448.0).to(torch.float8_e4m3fn).to(torch.float32)) * scale
    X = caps[name]; num = den = 0.0
    for j in range(0, X.shape[0], 512):
        xb = X[j:j+512].cuda()
        num += float((((W - Wq).cuda() @ xb.t()) ** 2).sum()); den += float(((W.cuda() @ xb.t()) ** 2).sum())
        del xb
    prof.append({"module": name, "mse_rel": num / max(den, 1e-20), "rows_seen": counts[name]})
    torch.cuda.empty_cache()
prof.sort(key=lambda r: (-r["mse_rel"], r["module"]))
doc = {"method": "per-module relative output MSE of FP8_E4M3 fake-quantized modules vs BF16 (per-tensor symmetric scale=amax/448)",
       "scope": SCOPE.pattern,
       "calibration_texts_sha256": hashlib.sha256(open(os.environ["CALIB_JSONL"], "rb").read()).hexdigest(),
       "n_texts": len(calib), "reservoir_rows": RESERVOIR, "reservoir_seed": RES_SEED, "modules": prof}
json.dump(doc, open(os.environ["PROFILE"], "w"), indent=2, sort_keys=True)
print(f"profile.json: {len(prof)} modules, max mse_rel={prof[0]['mse_rel']:.6f} ({prof[0]['module']})")
PY
fi
# public sha-only reference
python3 - "$PROFILE_JSON" "$PROFILE_REF" <<'PY'
import hashlib, json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
json.dump({"profile_sha256": hashlib.sha256(open(src, "rb").read()).hexdigest(),
           "method": d["method"], "scope": d["scope"], "n_modules": len(d["modules"]),
           "note": "profile content is gate-layer (pod-only); this sha pins it into the custody chain"},
          open(dst, "w"), indent=1, sort_keys=True)
print("profile_ref.json written (sha-only)")
PY
[ -f "$RUN_DIR/profile_path.json" ] || \
  echo "{\"path\": \"fresh\", \"profile_sha256\": \"$(sha256sum "$PROFILE_JSON" | cut -d' ' -f1)\", \"rule\": \"cross-family or no reuse declaration: fresh profiling required\"}" > "$RUN_DIR/profile_path.json"
rail

# ---------- 2. compose b1/b2 from profile + gate-layer parameters ----------
note "2. compose b1/b2 recipes (deterministic top-k ∪ over-threshold)"
if ! grep -q '"arm_id": "b1-profile-exempt"' "$RECIPE_LOG"; then
  PROFILE_JSON="$PROFILE_JSON" RECIPES_FILE="$RECIPES_FILE" RECIPE_LOG="$RECIPE_LOG" \
  LOCAL_RECIPE_LOG="$LOCAL_RECIPE_LOG" python3 - <<'PY'
import hashlib, json, os, re
prof = json.load(open(os.environ["PROFILE_JSON"]))["modules"]
gate = json.load(open(os.environ["RECIPES_FILE"]))
P = gate.get("profiling") or sys.exit("gate-layer profiling parameters missing (k/threshold) — pod-only file")
k, thr = int(P["top_k"]), float(P["mse_rel_threshold"])
by_rank = [m["module"] for m in prof[:k]]
over = [m["module"] for m in prof if m["mse_rel"] >= thr]
raw = sorted(set(by_rank) | set(over))
# Amendment-10/11 (D17/D18): Pilot004 addendum A3 ported byte-in-substance —
# vLLM fuses q/k/v (and gate/up) shards and requires a uniform scheme within
# each fused module, so exempting one shard implies exempting its siblings.
# The 004 craft expands BOTH fused groups; the first 005 patch covered only
# q/k/v (symptom-driven). Full A3 parity restored: the gate/up group cannot
# fire under the current attention-only scope, but the craft rule is ported
# complete, not per symptom. (D17 evidence: "Found different quantization
# schemes for the shards of ...qkv_proj".)
def _expand_fused(mods):
    out = set(mods)
    for m in mods:
        for grp in (("q_proj", "k_proj", "v_proj"), ("gate_proj", "up_proj")):
            for shard in grp:
                if m.endswith("." + shard):
                    base = m[: -len(shard)]
                    out.update(base + s for s in grp)
    return out
exempt = sorted(_expand_fused(raw))
print(f"  fused-granularity expansion (A-10, A3-parity): {len(raw)} -> {len(exempt)} modules", flush=True)
# Amendment-11 (D18): standing craft exclusions. Every Pilot004 recipe carried
# lm_head + embed_tokens in its ignore list (output head and embeddings are
# never quantized in this craft family); the 005 compose rule omitted them,
# and a quantized lm_head makes vLLM refuse the checkpoint ("no module or
# parameter named 'lm_head.weight_scale'"). Restored byte-in-substance.
exempt = ["lm_head", "embed_tokens"] + exempt
print(f"  standing exclusions (A-11): +lm_head +embed_tokens -> {len(exempt)} modules", flush=True)
def canon(r): return hashlib.sha256(json.dumps(r, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
def recipe(arm, levers, extra):
    r = {"arm_id": arm, "builder": "llmcompressor-oneshot", "levers": levers,
         "quantization": {"targets": "Linear", "scheme": "FP8_DYNAMIC", "ignore": exempt},
         "calibration": gate["calibration"], "uses_base_model": False}
    r.update(extra); return r
b1 = recipe("b1-profile-exempt", ["profile-driven-minimal-exemption:attention"], {})
b2 = recipe("b2-smooth-exempt", ["activation-smoothing", "profile-driven-minimal-exemption:attention"],
            {"smoothing": gate["smoothing"]})
for r in (b1, b2):
    sha = canon(r)
    with open(os.environ["RECIPE_LOG"], "a") as f:
        f.write(json.dumps({"arm_id": r["arm_id"], "levers": r["levers"], "recipe_sha256": sha,
                            "composed_from": ["profile.json", "gate-layer params"]}) + "\n")
    with open(os.environ["LOCAL_RECIPE_LOG"], "a") as f:
        f.write(json.dumps({"arm_id": r["arm_id"], "recipe": r, "recipe_sha256": sha}) + "\n")
    print(f"  composed {r['arm_id']}: exempt={len(exempt)} modules sha={sha[:16]}…")
PY
fi
rail

# ---------- 3. build checkpoints (build-hash-delete custody) ----------
note "3. checkpoint builds (llmcompressor oneshot; hash is the anchor)"
build_arm() {  # $1 = arm_id
  local arm="$1" cdir="$CKPT_ROOT/$1"
  [ -d "$cdir" ] && grep -q "\"arm_id\": \"$arm\"" "$CKPT_LOG" && { echo "  $arm: reuse $cdir"; return 0; }
  if [ "${STAGE16_MOCK_BUILD:-0}" = "1" ]; then
    mkdir -p "$cdir"; echo "{\"mock\":true,\"arm\":\"$arm\"}" > "$cdir/config.json"
    echo "{\"arm_id\": \"$arm\", \"levers\": [], \"llmcompressor_version\": \"mock\", \"checkpoint_sha256\": \"$(sha256sum "$cdir/config.json" | cut -d' ' -f1)\", \"build_seconds\": 0, \"mock\": true}" >> "$CKPT_LOG"
    echo "  TEST HOOK mock build $arm (custody row written)"; return 0
  fi
  [ "$(df --output=avail -BG "$HOME" | tail -1 | tr -dc '0-9')" -ge 50 ] || die "disk < 50GB for build"
  MODEL_DIR="$CKPT_ROOT/base" RJSON_ARM="$arm" CKPT_DIR="$cdir" CALIB_JSONL="$CALIB_TXT" \
  RECIPES_FILE="$RECIPES_FILE" LOCAL_RECIPE_LOG="$LOCAL_RECIPE_LOG" RECIPE_LOG="$RECIPE_LOG" CKPT_LOG="$CKPT_LOG" \
  python3 - <<'PY'
import hashlib, json, os, time
arm = os.environ["RJSON_ARM"]
gate = json.load(open(os.environ["RECIPES_FILE"]))
r = gate["recipes"].get(arm)
if r is None:
    for l in open(os.environ["LOCAL_RECIPE_LOG"]):   # composed arms: last match wins
        e = json.loads(l)
        if e.get("arm_id") == arm: r = e["recipe"]
if r is None: raise SystemExit(f"no recipe for {arm}")
if r.get("uses_base_model"): print(f"{arm}: base-model arm, no build"); raise SystemExit(0)
from datasets import Dataset
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier
import llmcompressor
mods = []
if "smoothing" in r:
    from llmcompressor.modifiers.smoothquant import SmoothQuantModifier
    mods.append(SmoothQuantModifier(smoothing_strength=r["smoothing"]["strength"]))
qk = dict(targets=r["quantization"]["targets"], scheme=r["quantization"]["scheme"], ignore=r["quantization"]["ignore"])
if "kv_cache_scheme" in r:
    from compressed_tensors.quantization import QuantizationArgs
    qk["kv_cache_scheme"] = QuantizationArgs(**r["kv_cache_scheme"])
mods.append(QuantizationModifier(**qk))
calib = [json.loads(l)["text"] for l in open(os.environ["CALIB_JSONL"])]
t0 = time.time()
oneshot(model=os.environ["MODEL_DIR"], dataset=Dataset.from_list([{"text": t} for t in calib]),
        recipe=mods, output_dir=os.environ["CKPT_DIR"],
        num_calibration_samples=r["calibration"]["n_samples"], max_seq_length=r["calibration"]["max_seq_len"])
h = hashlib.sha256()
for dp, _, fns in sorted(os.walk(os.environ["CKPT_DIR"])):
    for fn in sorted(fns):
        p = os.path.join(dp, fn); h.update(os.path.relpath(p, os.environ["CKPT_DIR"]).encode())
        h.update(hashlib.sha256(open(p, "rb").read()).digest())
csha = h.hexdigest()
rec = {"arm_id": arm, "levers": r.get("levers", []), "llmcompressor_version": llmcompressor.__version__,
       "checkpoint_sha256": csha, "build_seconds": round(time.time()-t0, 1),
       "ts_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
for path in (os.environ["RECIPE_LOG"], os.environ["CKPT_LOG"]):
    with open(path, "a") as f: f.write(json.dumps(rec) + "\n")
print(f"  built {arm}: ckpt_sha={csha[:16]}… ({rec['build_seconds']}s)")
PY
}
for arm in b1-profile-exempt b2-smooth-exempt b3-a4-kv; do build_arm "$arm"; done
rail

# ---------- 4. screening generation + judging ----------
note "4. screening generation (screening 40 × arms) + single-judge scoring"
SERVE_PORT="$PORT"
gen_arm() {  # $1 = arm_id  $2 = serve_extra  $3 = model path
  local out="$RUN_DIR/gen_$1.jsonl"
  [ -f "$out" ] && { echo "  $1: gen exists, skip"; return 0; }
  if [ "${STAGE16_MOCK_BUILD:-0}" = "1" ] || [ "${STAGE16_SKIP_SERVER:-0}" = "1" ]; then
    python3 -c "
import json
rows = [json.loads(l) for l in open('$SCREEN_JSONL')]
open('$out','w').write(''.join(json.dumps({'id': r['id'], 'prompt': r['text'], 'output': 'MOCK OUTPUT for ' + r['id']}, sort_keys=True) + chr(10) for r in rows))"
    echo "  TEST HOOK mock gen $1"; return 0
  fi
  rm -f /tmp/.effiq-server-up
  [ -n "$3" ] && kill "$(cat /tmp/.effiq-server-pid 2>/dev/null)" 2>/dev/null || true
  MODEL_DIR="$3" PORT="$SERVE_PORT" MAX_MODEL_LEN="$EFFIQ_MAX_MODEL_LEN" GEN_CONC="$EFFIQ_GEN_CONC" \
  MAX_TOKENS_CAP="$EFFIQ_MAX_TOKENS_CAP" TEMPERATURE="$EFFIQ_TEMPERATURE" SERVE_EXTRA="$2" \
  bash "$REPO_DIR/pipeline/lib_generate.sh" --set "$SCREEN_JSONL" --out "$out"
}
gen_arm "b0-control" "--quantization fp8" "$CKPT_ROOT/base"
gen_arm "b1-profile-exempt" "--quantization compressed-tensors" "$CKPT_ROOT/b1-profile-exempt"
gen_arm "b2-smooth-exempt" "--quantization compressed-tensors" "$CKPT_ROOT/b2-smooth-exempt"
gen_arm "b3-a4-kv" "--quantization compressed-tensors" "$CKPT_ROOT/b3-a4-kv"
rail

# blind map over screening set (deterministic, cell blind seed)
SCREEN_BLIND="$RUN_DIR/screening_blind.jsonl"
python3 - "$SCREEN_JSONL" "$EFFIQ_BLIND_SEED" "$SCREEN_BLIND" <<'PY'
import json, random, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
idx = list(range(len(rows))); random.Random(int(sys.argv[2])).shuffle(idx)
with open(sys.argv[3], "w") as f:
    for k, j in enumerate(idx): f.write(json.dumps({"blind_id": f"s{k:03d}", "frozen_index": j}) + "\n")
PY

judge_server_up
for arm in b0-control b1-profile-exempt b2-smooth-exempt b3-a4-kv; do
  SCORES="$RUN_DIR/scores_$arm.jsonl"
  [ -s "$SCORES" ] && continue   # A-12: non-empty = complete (lib_judge writes atomically)
  if [ "${STAGE16_MOCK_JUDGE:-0}" = "1" ]; then MOCK="--mock"; else MOCK=""; fi
  python3 "$REPO_DIR/pipeline/lib_judge.py" --panel "$PANEL_JSON" --judge "$SCREEN_JUDGE" \
    --rubric "$REPO_DIR/$EFFIQ_RUBRIC_FILE" --blind "$SCREEN_BLIND" \
    --candidates "$RUN_DIR/gen_$arm.jsonl" --reference "$GENR_JSONL" \
    --frozen "$SCREEN_JSONL" --out "$SCORES" --key-file "$KEY_FILE" --base "$OR_BASE_URL" \
    "${LOCAL_JUDGE_ARGS[@]}" $MOCK
done
judge_server_down

# ---------- 5. winner selection + proceed rule (frozen) ----------
note "5. winner selection (argmax clarity delta; margin from FROZEN-LINES)"
RUN_DIR="$RUN_DIR" LINES="$REPO_DIR/pipeline/FROZEN-LINES.json" python3 - <<'PY'
import json, os, statistics, sys
rd = os.environ["RUN_DIR"]
margin = json.load(open(os.environ["LINES"]))["statistics"]["screening_proceed_margin"]
def deltas(arm):
    rows = [json.loads(l) for l in open(f"{rd}/scores_{arm}.jsonl")]
    by = {}
    for r in rows: by.setdefault((r["blind_id"], r["judge"]), {})[r["which"]] = r["axes"]
    per_axis = {}
    for axis in ("clarity", "correctness", "completeness", "overall"):
        ds = [v["candidate"][axis] - v["reference"][axis] for v in by.values()]
        per_axis[axis] = statistics.mean(ds) if ds else None
    return per_axis
table = {a: deltas(a) for a in ("b0-control","b1-profile-exempt","b2-smooth-exempt","b3-a4-kv")}
cands = {a: d for a, d in table.items() if a != "b0-control"}
winner = sorted(cands, key=lambda a: (-cands[a]["clarity"], -cands[a]["overall"], a))[0]
wd = cands[winner]
verdict = {"winner": winner, "clarity_delta": wd["clarity"], "margin": margin,
           "proceed": wd["clarity"] >= -margin, "table": table,
           "note": "screening is indicative; the winner gets ONE confirmation shot in stage 18"}
json.dump(verdict, open(f"{rd}/screening_verdict.json", "w"), indent=1, sort_keys=True)
json.dump({"arm_id": winner, "recipe_sha256": None, "source": "stage-16 screening",
           "note": "recipe sha resolved from recipes_executed.jsonl at stage 18"},
          open(f"{rd}/winner.json", "w"), indent=1)
print(json.dumps(verdict["table"], indent=1))
print(f"wave-1 leader: {winner} clarity_delta={wd['clarity']:+.3f} (indicative; final proceed decided after wave-2)")
PY

# ---------- 6. wave 2 (deterministic merge of top1+top2) ----------
note "6. wave-2 composition (merge(top1, top2), deterministic rule)"
RUN_DIR="$RUN_DIR" RECIPE_LOG="$RECIPE_LOG" LOCAL_RECIPE_LOG="$LOCAL_RECIPE_LOG" \
RECIPES_FILE="$RECIPES_FILE" PROFILE_JSON="$PROFILE_JSON" python3 - <<'PY'
import hashlib, json, os
rd = os.environ["RUN_DIR"]
verdict = json.load(open(f"{rd}/screening_verdict.json"))
table = verdict["table"]
cands = {a: d for a, d in table.items() if a != "b0-control"}
top2 = sorted(cands, key=lambda a: (-cands[a]["clarity"], -cands[a]["overall"], a))[:2]
def load_recipe(arm):
    gate = json.load(open(os.environ["RECIPES_FILE"]))
    if arm in gate.get("recipes", {}): return gate["recipes"][arm]
    r = None
    for l in open(os.environ["LOCAL_RECIPE_LOG"]):
        e = json.loads(l)
        if e.get("arm_id") == arm: r = e["recipe"]
    return r
r1, r2 = (load_recipe(a) for a in top2)
merged = {"arm_id": "b4-w2", "builder": "llmcompressor-oneshot",
          "levers": sorted(set(r1.get("levers", [])) | set(r2.get("levers", []))),
          "quantization": {"targets": "Linear", "scheme": "FP8_DYNAMIC",
                           "ignore": sorted(set(r1["quantization"]["ignore"]) | set(r2["quantization"]["ignore"]))},
          "calibration": r1["calibration"], "uses_base_model": False}
if "smoothing" in r1 or "smoothing" in r2:
    merged["smoothing"] = r1.get("smoothing") or r2.get("smoothing")
if "kv_cache_scheme" in r1 or "kv_cache_scheme" in r2:
    merged["kv_cache_scheme"] = r1.get("kv_cache_scheme") or r2.get("kv_cache_scheme")
sha = hashlib.sha256(json.dumps(merged, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
with open(os.environ["RECIPE_LOG"], "a") as f:
    f.write(json.dumps({"arm_id": "b4-w2", "levers": merged["levers"], "recipe_sha256": sha,
                        "composed_from": [f"merge({top2[0]},{top2[1]})"]}) + "\n")
with open(os.environ["LOCAL_RECIPE_LOG"], "a") as f:
    f.write(json.dumps({"arm_id": "b4-w2", "recipe": merged, "recipe_sha256": sha}) + "\n")
print(f"wave-2 arm b4-w2 = merge({top2[0]}, {top2[1]}), sha={sha[:16]}…")
PY
build_arm "b4-w2"
gen_arm "b4-w2" "--quantization compressed-tensors" "$CKPT_ROOT/b4-w2"
SCORES="$RUN_DIR/scores_b4-w2.jsonl"
if [ ! -s "$SCORES" ]; then   # A-12: non-empty = complete
  if [ "${STAGE16_MOCK_JUDGE:-0}" = "1" ]; then MOCK="--mock"; else MOCK=""; fi
  judge_server_up
  python3 "$REPO_DIR/pipeline/lib_judge.py" --panel "$PANEL_JSON" --judge "$SCREEN_JUDGE" \
    --rubric "$REPO_DIR/$EFFIQ_RUBRIC_FILE" --blind "$SCREEN_BLIND" \
    --candidates "$RUN_DIR/gen_b4-w2.jsonl" --reference "$GENR_JSONL" \
    --frozen "$SCREEN_JSONL" --out "$SCORES" --key-file "$KEY_FILE" --base "$OR_BASE_URL" \
    "${LOCAL_JUDGE_ARGS[@]}" $MOCK
  judge_server_down
fi
# final re-rank including wave-2; overwrite winner.json only if b4-w2 beats the wave-1 winner
set +e
RUN_DIR="$RUN_DIR" LINES="$REPO_DIR/pipeline/FROZEN-LINES.json" python3 - <<'PY'
import json, os, statistics, sys
rd = os.environ["RUN_DIR"]
margin = json.load(open(os.environ["LINES"]))["statistics"]["screening_proceed_margin"]
def deltas(arm):
    rows = [json.loads(l) for l in open(f"{rd}/scores_{arm}.jsonl")]
    by = {}
    for r in rows: by.setdefault((r["blind_id"], r["judge"]), {})[r["which"]] = r["axes"]
    return {ax: statistics.mean([v["candidate"][ax]-v["reference"][ax] for v in by.values()])
            for ax in ("clarity","correctness","completeness","overall")}
arms = ["b1-profile-exempt","b2-smooth-exempt","b3-a4-kv","b4-w2"]
table = {a: deltas(a) for a in arms}
winner = sorted(table, key=lambda a: (-table[a]["clarity"], -table[a]["overall"], a))[0]
wd = table[winner]
verdict = {"winner": winner, "clarity_delta": wd["clarity"], "margin": margin,
           "proceed": wd["clarity"] >= -margin, "table": table, "wave": 2,
           "note": "final screening verdict incl. deterministic wave-2 merge"}
json.dump(verdict, open(f"{rd}/screening_verdict.json", "w"), indent=1, sort_keys=True)
# resolve winner recipe sha from the public executed log
wsha = None
for l in open(f"{rd}/recipes_executed.jsonl"):
    e = json.loads(l)
    if e.get("arm_id") == winner: wsha = e.get("recipe_sha256")
if wsha is None: print("FATAL: winner recipe sha not in custody log", file=sys.stderr); sys.exit(1)
json.dump({"arm_id": winner, "recipe_sha256": wsha, "source": "stage-16 screening (wave-2 final)"},
          open(f"{rd}/winner.json", "w"), indent=1)
print(f"FINAL WINNER: {winner} clarity_delta={wd['clarity']:+.3f} proceed={verdict['proceed']}")
sys.exit(0 if verdict["proceed"] else 2)
PY
rc=$?
set -e
if [ "$rc" = "2" ]; then
  echo "SCREENING-EXHAUSTED after wave 2 — legitimate publishable FAIL"
  touch "$RUN_DIR/COMPLETE"
  exit 2
fi

touch "$RUN_DIR/COMPLETE"
note "STAGE 16 COMPLETE (cell=$EFFIQ_CELL_ID)"
