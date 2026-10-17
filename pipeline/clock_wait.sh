#!/usr/bin/env bash
# =====================================================================
# clock_wait.sh — operator-wait event recorder (Protocol Lock v4.2,
# confirmation-phase SLA accounting).
#
# Records waiting-for-operator events with MACHINE timestamps into the
# cell's confirmation clock file ($CELL_DIR/wallclock-confirmation.json).
# Events are billed at min(actual_seconds, 3600) each by the rail math
# in run_cell.sh — the 1h SLA cap is applied at accounting time, never
# by truncating the record.
#
# Usage:
#   bash pipeline/clock_wait.sh <CELL_DIR> start <reason-label>
#   bash pipeline/clock_wait.sh <CELL_DIR> stop
# start/stop pairs are strictly nested: exactly one open event at a time.
# Labels are sanitized (no model/parameter content), e.g. "operator-decision".
# =====================================================================
set -euo pipefail

CELL_DIR="${1:?usage: clock_wait.sh <CELL_DIR> start|stop [label]}"
ACTION="${2:?start|stop}"
LABEL="${3:-operator-wait}"
CLOCK="$CELL_DIR/wallclock-confirmation.json"

[ -f "$CLOCK" ] || { echo "FATAL: no confirmation clock at $CLOCK (phase not armed?)" >&2; exit 1; }

case "$ACTION" in
  start)
    CLOCK="$CLOCK" LABEL="$LABEL" python3 - <<'PY'
import json, os, time
p = os.environ["CLOCK"]
c = json.load(open(p))
ev = c.setdefault("wait_events", [])
if ev and "t_end" not in ev[-1]:
    raise SystemExit("FATAL: a wait event is already open — stop it before starting another")
ev.append({"t_start": int(time.time()), "label": os.environ["LABEL"]})
json.dump(c, open(p, "w"))
print("wait event opened (machine timestamp)")
PY
    ;;
  stop)
    CLOCK="$CLOCK" python3 - <<'PY'
import json, os, time
p = os.environ["CLOCK"]
c = json.load(open(p))
ev = c.get("wait_events", [])
if not ev or "t_end" in ev[-1]:
    raise SystemExit("FATAL: no open wait event to stop")
ev[-1]["t_end"] = int(time.time())
ev[-1]["seconds"] = ev[-1]["t_end"] - ev[-1]["t_start"]
json.dump(c, open(p, "w"))
print(f"wait event closed: {ev[-1]['seconds']}s actual (billed min(actual, 3600))")
PY
    ;;
  *)
    echo "FATAL: unknown action $ACTION (start|stop)" >&2; exit 1 ;;
esac
