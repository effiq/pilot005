#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — STAGE 17: HIGH-LOAD FRONTIER MAPPING (Objective 3)
#
# Frozen in Protocol Lock v4.2 (L0: Objective 3 included, stage 17). EXPLORATORY,
# DESCRIPTIVE, UNGATED — feeds no verdict. Runs ONCE on the Pilot 004 cell
# (the regression cell named in Protocol Lock v4.2 L4), not per 005 cell;
# it reuses the 004 tuned artifacts.
#
# Method: on the 004 cell's serving stack, push offered concurrency beyond
# the calibrated operating point in declared steps; record throughput /
# latency at each step; output the overload frontier curve + inflection
# position. Kill condition (frozen, L5): if overload behavior proves
# non-reproducible (instrumentation cannot anchor it), record and stop —
# no further budget consumed.
#
# Every row is watermarked: EXPLORATORY — descriptive only, never gated.
#
# Test hooks: STAGE17_OUT_DIR, STAGE17_MOCK, PORT, MAX_SECONDS
# =============================================================================
set -euo pipefail

EFFIQ_HOME="${EFFIQ_HOME:-$HOME/effiq}"
LOGS_DIR="${LOGS_DIR:-$EFFIQ_HOME/pilot-logs}"
STAGE_NAME="17-frontier-mapping"
PORT="${PORT:-8000}"
MAX_SECONDS="${MAX_SECONDS:-14400}"
WATERMARK="EXPLORATORY — descriptive only, never enters any gate or CI"

note() { printf '\n=== %s ===\n' "$*"; }
die()  { printf '\n[stage17][ERROR] %s\n' "$*" >&2; exit 1; }

RUN_DIR="${STAGE17_OUT_DIR:-$LOGS_DIR/pilot005/objective3/$STAGE_NAME/run_$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$RUN_DIR"
echo "$WATERMARK" > "$RUN_DIR/WATERMARK.txt"
T0=$(date +%s)

note "frontier mapping on the Pilot 004 cell (overload sweep)"
if [ "${STAGE17_MOCK:-0}" = "1" ]; then
  python3 - "$RUN_DIR" <<'PY'
import json, random, sys
rng = random.Random(1)
rows = []
for conc in [16, 32, 64, 128, 256, 512]:
    tps = 1800 * (1 - 2.71828 ** (-conc / 64)) * rng.uniform(0.97, 1.03)
    rows.append({"concurrency": conc, "throughput_tps": round(tps, 1),
                 "p95_tpot_ms": round(50 * (conc / 16) * rng.uniform(0.9, 1.1), 1),
                 "watermark": "EXPLORATORY — descriptive only"})
json.dump({"rows": rows, "inflection_note": "MOCK"}, open(f"{sys.argv[1]}/frontier.json", "w"), indent=1)
print("TEST HOOK: mock frontier written")
PY
else
  # Real craft: reuse the 004 cell's checkpoint + operating point from the
  # pilot-logs archive (004 stage-10 chosen point + stage-13 winner ckpt),
  # then sweep offered load beyond the operating point. Instrumentation
  # contract: each step must produce anchored raw rows; two consecutive
  # non-reproducible steps (variance anchor fails) -> kill line, record, stop.
  die "production path requires the 004 cell environment — run on the 004 evidence pod with its archived artifacts; see REPRODUCE. (Stays unrun until scheduled in the window plan.)"
fi

touch "$RUN_DIR/COMPLETE"
note "STAGE 17 COMPLETE — descriptive artifact: $RUN_DIR/frontier.json"
