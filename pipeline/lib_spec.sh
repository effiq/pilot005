#!/usr/bin/env bash
# lib_spec.sh — load a validated cell spec into EFFIQ_* env vars.
# Model-agnostic by construction: no model names, no model-conditional logic.
# Usage:  source pipeline/lib_spec.sh <spec.json>
# After sourcing, every stage script reads ONLY these variables (data in, never code branches).

[ -n "${1:-}" ] || { echo "usage: source lib_spec.sh <spec.json>" >&2; return 2 2>/dev/null || exit 2; }
SPEC_FILE="$(readlink -f "$1")"
[ -f "$SPEC_FILE" ] || { echo "FATAL: spec not found: $SPEC_FILE" >&2; exit 1; }

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PIPELINE_DIR/.." && pwd)"

# mechanical validation first — REFUSED beats RUN
python3 "$PIPELINE_DIR/spec_check.py" "$SPEC_FILE" "$REPO_ROOT" >/dev/null || {
  echo "FATAL: spec failed mechanical validation: $SPEC_FILE" >&2; exit 1; }

# export spec as flat env (single read; sha pinned)
eval "$(SPEC_FILE="$SPEC_FILE" python3 - <<'PY'
import json, os, shlex
s = json.load(open(os.environ["SPEC_FILE"]))
def emit(k, v): print(f"export {k}={shlex.quote(str(v))}")
emit("EFFIQ_CELL_ID", s["cell"]["id"])
emit("EFFIQ_CELL_ROLE", s["cell"]["role"])
emit("EFFIQ_MODEL", s["model"]["repo_id"])
emit("EFFIQ_MODEL_REV", s["model"]["revision"])
emit("EFFIQ_MODEL_FAMILY", s["model"]["family"])
emit("EFFIQ_MAX_MODEL_LEN", s["model"]["max_model_len"])
emit("EFFIQ_SERVE_EXTRA", s["model"].get("serve_extra_flags", ""))
emit("EFFIQ_PROFILE_SCOPE", s["model"]["profile_scope_regex"])
emit("EFFIQ_GPU_EXPECT", s["hardware"]["gpu"])
emit("EFFIQ_TRACE_SOURCE", s["load"]["trace_source"])
emit("EFFIQ_TRACE_FILTER", s["load"].get("trace_filter", ""))
emit("EFFIQ_LANG", s["load"]["lang"])
emit("EFFIQ_SYNTHETIC_SEED", s["load"].get("synthetic_seed") or "")
emit("EFFIQ_TEMPERATURE", s["generation"]["temperature"])
emit("EFFIQ_GEN_CONC", s["generation"]["gen_concurrency"])
emit("EFFIQ_MAX_TOKENS_CAP", s["generation"]["max_tokens_cap"])
emit("EFFIQ_RUBRIC_FILE", s["rubric"]["file"])
emit("EFFIQ_RUBRIC_LANG", s["rubric"]["lang"])
emit("EFFIQ_N_FROZEN", s["anchors"]["n_frozen"])
emit("EFFIQ_N_SCREEN", s["anchors"]["n_screen"])
emit("EFFIQ_N_CALIB_TEXTS", s["anchors"]["n_calib_texts"])
emit("EFFIQ_DERIVE_SEED", s["anchors"]["derive_seed"])
emit("EFFIQ_RUN_SEED_BASE", s["anchors"]["run_seed_base"])
emit("EFFIQ_BLIND_SEED", s["anchors"]["blind_seed"])
emit("EFFIQ_PRIVSEG_SHA", s["private_segment_sha256"])
PY
)"
export EFFIQ_SPEC_FILE="$SPEC_FILE"
export EFFIQ_SPEC_SHA256="$(sha256sum "$SPEC_FILE" | cut -d' ' -f1)"
export EFFIQ_PIPELINE_DIR="$PIPELINE_DIR"
export EFFIQ_REPO_ROOT="$REPO_ROOT"

# frozen lines (the instrument) — read-only to stages
export EFFIQ_LINES="$PIPELINE_DIR/FROZEN-LINES.json"
export EFFIQ_JUDGES="$PIPELINE_DIR/JUDGES.json"
echo "[lib_spec] cell=$EFFIQ_CELL_ID role=$EFFIQ_CELL_ROLE spec_sha=${EFFIQ_SPEC_SHA256:0:16}…"
