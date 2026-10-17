#!/usr/bin/env bash
# =============================================================================
# Pilot 005 — IGNITION-DAY HELPER: pin model revisions
#
# Fills each spec's model.revision with the repo's current HEAD 40-hex
# commit sha (HF API). Run ONCE at ignition, then backfill
# private_segment_sha256, then git commit the specs BEFORE the first run.
#
# Rationale (frozen protocol): a cell's byte identity is its pinned
# revision; "latest within the gate" is resolved at ignition moment and
# frozen for the whole window. Placeholder text in a revision field is
# forbidden in any run — spec_check.py enforces 40-hex.
#
# This script touches ONLY the revision field. It never edits verdict
# lines, judge panels, seeds, or any other spec content.
# =============================================================================
set -euo pipefail

PKG="$(cd "$(dirname "$0")/.." && pwd)"

fetch_head() {  # repo_id -> 40-hex HEAD sha (HF primary, mirror fallback)
  local repo="$1" sha=""
  sha=$(curl -s --max-time 30 "https://huggingface.co/api/models/$repo" \
        | python3 -c "import json,sys;print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || true)
  if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[warn] HF direct failed for $repo — trying mirror" >&2
    sha=$(curl -s --max-time 30 "https://hf-mirror.com/api/models/$repo" \
          | python3 -c "import json,sys;print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || true)
  fi
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "FATAL: cannot resolve HEAD for $repo" >&2; exit 1; }
  echo "$sha"
}

for spec in "$PKG"/specs/*.json; do
  repo=$(python3 -c "import json;print(json.load(open('$spec'))['model']['repo_id'])")
  cur=$(python3 -c "import json;print(json.load(open('$spec'))['model']['revision'])")
  if [[ "$cur" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[skip] $(basename "$spec"): already pinned ($cur)"
    continue
  fi
  sha=$(fetch_head "$repo")
  SPEC="$spec" SHA="$sha" python3 - <<'PY'
import json, os
p = os.environ["SPEC"]
s = json.load(open(p))
s["model"]["revision"] = os.environ["SHA"]
json.dump(s, open(p, "w"), ensure_ascii=False, indent=1)
print(f"[pin] {os.path.basename(p)}: revision={os.environ['SHA']}")
PY
done

echo
echo "== post-pin status =="
for spec in "$PKG"/specs/*.json; do
  if python3 "$PKG/pipeline/spec_check.py" "$spec" "$PKG" >/dev/null 2>&1; then
    echo "[green] $(basename "$spec")"
  else
    echo "[pending] $(basename "$spec"): $(python3 "$PKG/pipeline/spec_check.py" "$spec" "$PKG" 2>&1 | head -1)"
  fi
done

echo
echo "NEXT: 1) backfill private_segment_sha256 (ignition-day trace split)"
echo "      2) spec_check all green  3) git commit specs BEFORE first run"
