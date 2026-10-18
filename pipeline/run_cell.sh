#!/usr/bin/env bash
# =====================================================================
# run_cell.sh — Effiq Pilot 005 cell runner (hands-only entry point)
#
#   nohup bash <package>/pipeline/run_cell.sh specs/<cell>.json > ~/run_cell.out 2>&1 &
#   (<package> = wherever the pipeline package sits, e.g. ~/effiq/pilot005/pipe005)
#
# Spec in, verdict out. One run = one cell. This orchestrator is
# model-agnostic: it contains no model names and no model-conditional
# logic. All variation arrives as spec data via lib_spec.sh.
#
# What it enforces (Protocol Lock v4.2):
#   - spec mechanical validation BEFORE anything runs (spec_check.py);
#   - two-phase wall clock (frozen, v4.2): development phase untimed
#     (durations recorded and published; verdict line = monotonic
#     decrease across cells); confirmation phase = 72h continuous
#     calendar rail per cell, cumulative across attempts (cap 2, no
#     reset), queueing stays on the clock, waiting-for-operator events
#     billed at min(actual, 1h) from machine-timestamped wait ledger,
#     sole carve-out = provider status-page outage (declared via
#     addendum file $ENV_DIR/outage-addendum.json and disclosed);
#   - intervention ledger: every human action that alters run state is
#     counted here (ignition, resume, stop, upload, decision points);
#     passive observation never counts; watchdog actions inside the
#     frozen playbook are machine actions — logged and published, but
#     not counted (Appendix A, published);
#   - adaptation-edit meter: pipeline repo must stay byte-clean vs the
#     frozen upload commit throughout the run (git diff --exit-code);
#   - leak scan before every push (unchanged from Pilot 004 tonight.sh);
#   - run-validity: void/rerun ONLY with contemporaneous provider
#     status-page evidence attached (symmetric rule, v4.2).
#
# Private-file discipline (three-layer disclosure): unchanged from 004 —
# ~/pilot-env/{github.token,openrouter-key,arms-recipes.json,
# spec-private-<cell>.json} never enter any repo, never leave the pod.
# =====================================================================
set -euo pipefail

REPO_URL="${EFFIQ_REPO_URL:-https://github.com/effiq/pilot005.git}"   # sandbox hook: EFFIQ_REPO_URL
LOGS_URL="${EFFIQ_LOGS_URL:-https://github.com/effiq/pilot-logs.git}" # sandbox hook: EFFIQ_LOGS_URL
EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
REPO_DIR="$EFFIQ_HOME/pilot005"
LOGS_DIR="$EFFIQ_HOME/pilot-logs"
ENV_DIR="$HOME/pilot-env"
TOKEN_FILE="$ENV_DIR/github.token"
VOLUME_DIR="${VOLUME_DIR:-/workspace}"
DATE_STR="$(date -u +%Y-%m-%d)"

say() { echo "[run_cell $(date -u +%H:%M:%S)] $*"; }
die() { echo "FATAL: $*" >&2; exit 1; }

# ---------- -1. single-instance lock (D12 repair, Amendment-07) ----------
# attempt-3 postmortem: a second run_cell was ignited while the previous one
# was still in its server health-wait; the two instances shared the log file
# and the pilot-logs working tree, and the addendum-A2 guard (correctly)
# refused to run. Concurrency is now impossible: first action of any instance
# is to take an exclusive flock; a second instance dies loudly, instantly,
# BEFORE touching repos, ledger, or clock. The lock auto-releases on process
# death, so resume-after-crash is unaffected.
LOCK_DIR="${EFFIQ_LOCK_DIR:-$HOME/.effiq}"
mkdir -p "$LOCK_DIR"
exec 9>"$LOCK_DIR/run_cell.lock"
flock -n 9 || die "another run_cell instance is alive (lock: $LOCK_DIR/run_cell.lock) — refusing concurrent run (Amendment-07 R14). Verify with: ps aux | grep run_cell"

[ -n "${1:-}" ] || die "usage: bash pipeline/run_cell.sh specs/<cell>.json"
SPEC_ARG="$1"

# self-locate the package: the pipeline may live at repo root OR in a
# subdirectory (e.g. pipe005/) — never assume repo layout. Stages get the
# package root via lib_spec.sh's EFFIQ_REPO_ROOT export; this orchestrator
# uses PIPELINE_DIR for its own references. (Ignition-day fix: the repo
# upload nested the package under pipe005/.)
PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(dirname "$PIPELINE_DIR")"

# ---------- 0. private files present (existence + perms only) ----------
[ -f "$TOKEN_FILE" ] || die "missing $TOKEN_FILE (chmod 600)"
[ -f "$ENV_DIR/openrouter-key" ] || die "missing $ENV_DIR/openrouter-key"
[ -f "$ENV_DIR/arms-recipes.json" ] || die "missing $ENV_DIR/arms-recipes.json"
for f in "$TOKEN_FILE" "$ENV_DIR/openrouter-key" "$ENV_DIR/arms-recipes.json"; do
  [ "$(stat -c '%a' "$f")" = "600" ] || die "$f must be chmod 600"
done
TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE")

# ---------- 1. clone or pull (token-embedded; addendum-A2 discipline) ----------
mkdir -p "$EFFIQ_HOME"
clone_or_pull() {
  local url="$1" dir="$2"
  local auth="$url"
  case "$url" in
    https://*) auth="https://x-access-token:${TOKEN}@${url#https://}" ;;
  esac
  if [ ! -d "$dir/.git" ]; then
    say "cloning $url (token-embedded)"
    git clone "$auth" "$dir"
  else
    git -C "$dir" remote set-url origin "$auth"
    git -C "$dir" fetch origin
    # addendum-A2 guard: refuse to destroy LOCAL work. A merely-behind clean
    # clone has nothing to lose — fast-forward it; only uncommitted changes
    # or unpushed local commits are sacred.
    [ -z "$(git -C "$dir" status --porcelain)" ] || die "UNCOMMITTED local state in $dir — refusing reset --hard (addendum A2). Commit+push or clean manually, then re-run."
    if git -C "$dir" rev-parse --verify -q origin/main >/dev/null; then
      AHEAD=$(git -C "$dir" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
      [ "$AHEAD" = "0" ] || die "UNPUSHED local commits in $dir ($AHEAD ahead) — refusing reset --hard (addendum A2). Push first, then re-run."
      git -C "$dir" reset --hard origin/main >/dev/null
    fi
  fi
}
clone_or_pull "$REPO_URL" "$REPO_DIR"
clone_or_pull "$LOGS_URL" "$LOGS_DIR"

SPEC_PATH="$PKG_ROOT/$SPEC_ARG"
[ -f "$SPEC_PATH" ] || die "spec not found in package: $SPEC_ARG (looked at $SPEC_PATH)"

# ---------- 2. spec load (validates first; REFUSED beats RUN) ----------
source "$PIPELINE_DIR/lib_spec.sh" "$SPEC_PATH"
[ "$EFFIQ_CELL_ROLE" != "regression" ] || die "regression cell runs the original Pilot 004 frozen scripts, not this pipeline (L4 byte-reproduction discipline)"

# private segment sha check (gate layer, existence + hash only — content never read here)
PRIVSEG="$ENV_DIR/spec-private-$EFFIQ_CELL_ID.json"
[ -f "$PRIVSEG" ] || die "missing gate-layer private segment: $PRIVSEG"
[ "$(sha256sum "$PRIVSEG" | cut -d' ' -f1)" = "$EFFIQ_PRIVSEG_SHA" ] || die "private segment sha mismatch vs spec"

# ---------- 3. run dir + intervention ledger + wall-clock rail ----------
CELL_DIR="$LOGS_DIR/pilot005/$EFFIQ_CELL_ID"
mkdir -p "$CELL_DIR"
RUN_ID="run_$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ROOT="$CELL_DIR/$RUN_ID"
mkdir -p "$RUN_ROOT"
LEDGER="$CELL_DIR/interventions.jsonl"
# two-phase wall clock (v4.2): EFFIQ_PHASE is REQUIRED — development | confirmation.
# development: informational clock only, no rail (the phase is untimed;
#   per-cell durations are published; monotonic decrease is checked at
#   verdict time, not here).
# confirmation: 72h continuous calendar rail, cumulative across attempts
#   (cap 2), operator-wait credit min(actual, 1h) per machine-timestamped
#   event, provider-outage carve-out via addendum file.
PHASE="${EFFIQ_PHASE:?EFFIQ_PHASE required (development|confirmation) — two-phase wall clock, Protocol Lock v4.2}"
[ "$PHASE" = "development" ] || [ "$PHASE" = "confirmation" ] || die "EFFIQ_PHASE must be development|confirmation"
CLOCK="$CELL_DIR/wallclock-$PHASE.json"

# intervention ledger: one jsonl line per human action that alters run state.
# Count HUMAN actions only (v4.2: machine actions are "logged and published,
# but not counted") — run-complete rows are machine bookkeeping appended after
# a run's last human action. Defect fix (2026-10-18, ADDENDUM-02): the raw
# wc -l count included those rows; after cell-1 development (5 human ignitions
# + 1 machine row) a single confirmation resume would have tripped the cap at
# 9 raw lines, locking the phase out of its frozen second attempt.
log_intervention() {  # $1 = action label
  printf '{"ts":"%s","cell":"%s","action":%s}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$EFFIQ_CELL_ID" \
    "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" >> "$LEDGER"
}
intervention_count() { [ -f "$LEDGER" ] && { grep -cv '"action":"run-complete:' "$LEDGER" || true; } || echo 0; }
INTERVENTIONS_MAX=$(python3 -c "import json,os;print(json.load(open(os.environ['EFFIQ_LINES']))['gates']['interventions_max'])")
WALLCLOCK_H=$(python3 -c "import json,os;print(json.load(open(os.environ['EFFIQ_LINES']))['gates']['wallclock_hours_per_cell'])")
CONF_ATTEMPTS_MAX=$(python3 -c "import json,os;print(json.load(open(os.environ['EFFIQ_LINES']))['gates']['confirmation_attempts_max'])")

log_intervention "ignition:$RUN_ID (phase=$PHASE)"
N_INT=$(intervention_count)
say "interventions so far this cell: $N_INT (frozen cap: $INTERVENTIONS_MAX — Appendix A published)"
if [ "$N_INT" -gt "$INTERVENTIONS_MAX" ]; then
  die "INTERVENTION CAP EXCEEDED ($N_INT > $INTERVENTIONS_MAX) — cell verdict line 2 broken; disclose and stop (no silent continuation)"
fi

# wall clock: first ignition timestamp of the phase persists for the cell
NOW=$(date +%s)
if [ ! -f "$CLOCK" ]; then
  printf '{"cell":"%s","phase":"%s","t_start":%d,"attempts":0,"outage_seconds":0,"outage_addenda":[],"wait_events":[]}\n' \
    "$EFFIQ_CELL_ID" "$PHASE" "$NOW" > "$CLOCK"
fi
if [ "$PHASE" = "confirmation" ]; then
  # attempt accounting: each confirmation ignition is one attempt (cap frozen, clock cumulative)
  ATTEMPTS=$(CLOCK="$CLOCK" python3 -c 'import json,os;print(json.load(open(os.environ["CLOCK"]))["attempts"])' )
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -gt "$CONF_ATTEMPTS_MAX" ]; then
    die "CONFIRMATION ATTEMPT CAP EXCEEDED (> ${CONF_ATTEMPTS_MAX}) — verdict line broken; disclose and stop"
  fi
  CLOCK="$CLOCK" ATTEMPTS="$ATTEMPTS" python3 - <<'PY'
import json, os
p = os.environ["CLOCK"]
c = json.load(open(p))
c["attempts"] = int(os.environ["ATTEMPTS"])
json.dump(c, open(p, "w"))
PY
  if [ "$ATTEMPTS" -eq 1 ]; then
    log_intervention "confirmation_phase_declared:$RUN_ID"
  fi
  ELAPSED=$(CLOCK="$CLOCK" NOW="$NOW" python3 - <<'PY'
import json, os
c = json.load(open(os.environ["CLOCK"]))
# operator-wait SLA: each machine-timestamped wait event bills min(actual, 1h)
wait_credit = sum(min(int(e.get("seconds", 0)), 3600) for e in c.get("wait_events", []))
print(int(os.environ["NOW"]) - c["t_start"] - int(c.get("outage_seconds", 0)) - wait_credit)
PY
)
  say "confirmation wall clock: ${ELAPSED}s elapsed of $((WALLCLOCK_H*3600))s (attempt ${ATTEMPTS}/${CONF_ATTEMPTS_MAX}; carve-outs: see $CLOCK)"
  if [ "$ELAPSED" -gt $((WALLCLOCK_H*3600)) ]; then
    die "WALL-CLOCK RAIL TRIPPED (> ${WALLCLOCK_H}h net) — verdict line broken; disclose and stop"
  fi
else
  ELAPSED=$(CLOCK="$CLOCK" NOW="$NOW" python3 - <<'PY'
import json, os
c = json.load(open(os.environ["CLOCK"]))
print(int(os.environ["NOW"]) - c["t_start"])
PY
)
  say "development phase: untimed — ${ELAPSED}s since first development ignition (informational; durations published per cell)"
fi

# ---------- 4. adaptation-edit meter: pipeline must stay byte-clean ----------
say "adaptation-edit meter: verifying pipeline repo is byte-clean vs origin/main"
git -C "$REPO_DIR" diff --exit-code >/dev/null || die "PIPELINE DIRTY — uncommitted change in pipeline repo = potential adaptation edit (frozen: 0). Classify via addendum (defect-fix ceremony) before continuing."
git -C "$REPO_DIR" diff --cached --exit-code >/dev/null || die "PIPELINE STAGED CHANGES — same rule."

# ---------- 5. stage plan (fixed order; scripts are spec-driven) ----------
# Stage numbering continues the cross-pilot sequence (004 ended at 13).
# 17 is RESERVED for Objective 3 (frontier mapping, Protocol Lock v4.2 L0:
# "Objective 3 included, stage 17") — it runs once on the Pilot 004 cell on
# its own track, not per cell; per-cell flow is 14→15→16→18→19.
STAGES="14-judge-calibration 15-cell-preflight 16-arm-screening 18-red-dot-confirm 19-dual-gates"
STAGE_FILE="$CELL_DIR/STAGE"
if [ -f "$STAGE_FILE" ]; then CURRENT=$(tr -d '[:space:]' < "$STAGE_FILE"); else CURRENT=14-judge-calibration; fi
say "resuming at stage: $CURRENT"

# ---------- 6. leak scan (unchanged craft from Pilot 004 tonight.sh) ----------
scan_repo() {
  local repo="$1" hits=0
  local patterns='ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-or-v1-[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{40,}'
  if git -C "$repo" grep -nI -E "$patterns" -- . ':(exclude).git' >/dev/null 2>&1; then
    echo "LEAK SCAN [$repo]: token-pattern hits" >&2; hits=1
  fi
  if git -C "$repo" ls-files | grep -E '(^|/)arms-recipes\.json$|recipes-local\.jsonl$|(^|/)profile\.json$|spec-private-.*\.json$' >/dev/null 2>&1; then
    echo "LEAK SCAN [$repo]: private file tracked" >&2; hits=1
  fi
  local dollar_hits
  dollar_hits=$(git -C "$repo" diff --cached -U0 -- . ':(exclude).git' ':(exclude)pipeline/' ':(exclude)*.jsonl' 2>/dev/null \
    | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E '\$[0-9]+\.?[0-9]*' | head -20 || true)
  if [ -n "$dollar_hits" ]; then echo "LEAK SCAN [$repo]: dollar figures in new lines" >&2; hits=1; fi
  return "$hits"
}
push_repo() {
  local repo="$1" label="$2"
  ( cd "$repo" && git add -A )
  if git -C "$repo" diff --cached --quiet; then say "$label: nothing new"; return 0; fi
  scan_repo "$repo" || die "LEAK SCAN FAILED in $label — refusing to push"
  git -C "$repo" -c user.name="effiq-pod" -c user.email="pod@effiq.invalid" commit -m "pilot005 $EFFIQ_CELL_ID artifacts $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
  git -C "$repo" push origin HEAD:main
  say "$label pushed"
}

# ---------- 7. run stages ----------
skip_past() {  # skip stages before CURRENT in the fixed order
  local found=1
  for s in $STAGES; do
    [ "$s" = "$CURRENT" ] && found=0
    [ "$found" = "0" ] && echo "$s"
  done
}
rc_overall=0
for s in $(skip_past); do
  say "=== stage $s (cell $EFFIQ_CELL_ID) ==="
  set +e
  EFFIQ_CELL_DIR="$CELL_DIR" bash "$PIPELINE_DIR/stages/$s.sh"
  rc=$?
  set -e
  say "stage $s exit: $rc"
  push_repo "$LOGS_DIR" "pilot-logs"   # evidence first, after every stage
  # terminal FAIL: screening exhausted (rc=2 at stage 16) = no viable arm —
  # a legitimate negative outcome under the frozen protocol. Record the
  # verdict and stop cleanly; never advance into a stage-18 crash loop.
  # (Mock-ignition review catch; branch verified by review, not executed —
  #  the sandbox judge always clears the bar.)
  if [ "$rc" = "2" ] && [ "$s" = "16-arm-screening" ]; then
    CELL="$EFFIQ_CELL_ID" SPEC_SHA="$EFFIQ_SPEC_SHA256" OUT="$CELL_DIR/VERDICT.json" python3 - <<'PY'
import json, os, time
v = {
  "verdict": "FAIL",
  "reason": "screening-exhausted — no recipe arm cleared the wave-2 clarity bar; cell terminated before measurement (frozen protocol: exhaustion is a legitimate negative outcome)",
  "cell": os.environ["CELL"],
  "spec_sha256": os.environ["SPEC_SHA"],
  "semantics": "Under the pre-registered process, budget, and statistical discipline, the lossless-speedup test on this model × quantization × hardware combination returned this result. A negative result is neither a defect verdict on the model nor a capability verdict on Effiq — it is a compressibility fact about the combination under the frozen process.",
  "headline_rule": "FAIL headlines never carry a model name (all cells, v4.2)",
  "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
json.dump(v, open(os.environ["OUT"], "w"), indent=1, sort_keys=True)
print("VERDICT recorded: FAIL (screening-exhausted)")
PY
    push_repo "$LOGS_DIR" "pilot-logs"
    exit 2
  fi
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
    echo "$s" > "$STAGE_FILE"
    say "stage incomplete (rc=$rc); checkpoint saved; re-run to resume"
    exit "$rc"
  fi
  # advance bookmark
  nxt=""
  for cand in $STAGES; do if [ "$nxt" = "__take" ]; then nxt="$cand"; break; fi; [ "$cand" = "$s" ] && nxt="__take"; done
  [ -n "$nxt" ] && [ "$nxt" != "__take" ] && echo "$nxt" > "$STAGE_FILE" || true
  rc_overall=$rc
done

# ---------- 8. final push + volume backup ----------
push_repo "$LOGS_DIR" "pilot-logs"
if [ -d "$VOLUME_DIR" ] && [ -w "$VOLUME_DIR" ]; then
  mkdir -p "$VOLUME_DIR/pilot-env-backup"
  cp -p "$ENV_DIR/arms-recipes.json" "$PRIVSEG" "$VOLUME_DIR/pilot-env-backup/" 2>/dev/null || true
  chmod 600 "$VOLUME_DIR/pilot-env-backup/"* 2>/dev/null || true
  say "private-file backup synced to volume"
fi

log_intervention "run-complete:$RUN_ID rc=$rc_overall"
unset TOKEN
say "done (cell=$EFFIQ_CELL_ID last_rc=$rc_overall)"
exit 0
