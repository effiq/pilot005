#!/usr/bin/env python3
"""derive_cell_anchors.py — deterministic anchor derivation for a Pilot 005 cell.

Pilot 004 inherited its anchors from the sealed 002/003 archives BY HASH.
New cells have no archive — so the pipeline DERIVES them from the cell's
load trace by this single deterministic rule (frozen craft, same sizes as
002/003/004: 150 frozen / 40 screening / 256 calibration texts).

Determinism contract: same trace file + same seeds -> byte-identical outputs.
Every output sha256 is printed for the run archive. No model logic here —
this script never knows which model the cell carries.

Usage:
  python3 derive_cell_anchors.py --trace trace.jsonl --out DIR \
      --derive-seed N --blind-seed M [--lang ar]

Trace jsonl row: {"id": str, "text": str} (one conversation/prompt per row).
Outputs:
  frozen_set.jsonl       150 items (the verdict gate set)
  screening_set.jsonl     40 items (disjoint from frozen — asserted)
  calibration_texts.jsonl 256 texts (profiling texts; disjoint from both)
  blind_map.jsonl         frozen-set presentation order for judges
  anchors.json            sha256 of every output + derivation provenance
"""
import argparse, hashlib, json, random, sys

def sha_bytes(b): return hashlib.sha256(b).hexdigest()

def dump_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n")
    return sha_bytes(open(path, "rb").read())

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trace", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--derive-seed", type=int, required=True)
    ap.add_argument("--blind-seed", type=int, required=True)
    ap.add_argument("--n-frozen", type=int, default=150)
    ap.add_argument("--n-screen", type=int, default=40)
    ap.add_argument("--n-calib", type=int, default=256)
    args = ap.parse_args()

    rows = [json.loads(l) for l in open(args.trace, encoding="utf-8") if l.strip()]
    need = args.n_frozen + args.n_screen + args.n_calib
    if len(rows) < need:
        print(f"FATAL: trace has {len(rows)} rows, need >= {need} — enrich trace or declare synthetic top-up via addendum", file=sys.stderr)
        sys.exit(1)

    # deterministic order: sort by (sha256 of id+text) so derivation does not
    # depend on upstream row order, then seeded sample without replacement.
    rows.sort(key=lambda r: sha_bytes((r["id"] + "" + r["text"]).encode()))
    rng = random.Random(args.derive_seed)
    idx = list(range(len(rows)))
    rng.shuffle(idx)
    frozen = [rows[i] for i in idx[: args.n_frozen]]
    screen = [rows[i] for i in idx[args.n_frozen : args.n_frozen + args.n_screen]]
    calib  = [rows[i] for i in idx[args.n_frozen + args.n_screen : need]]

    frozen_ids = {r["id"] for r in frozen}
    screen_ids = {r["id"] for r in screen}
    calib_ids  = {r["id"] for r in calib}
    assert not (frozen_ids & screen_ids), "disjointness breach: frozen ∩ screening"
    assert not (frozen_ids & calib_ids), "disjointness breach: frozen ∩ calibration"
    assert not (screen_ids & calib_ids), "disjointness breach: screening ∩ calibration"

    # blind map: judge-facing presentation order over the frozen set
    brng = random.Random(args.blind_seed)
    order = list(range(len(frozen)))
    brng.shuffle(order)
    blind = [{"blind_id": f"b{k:03d}", "frozen_index": j} for k, j in enumerate(order)]

    import os
    os.makedirs(args.out, exist_ok=True)
    out = {}
    out["frozen_set.jsonl"] = dump_jsonl(f"{args.out}/frozen_set.jsonl", frozen)
    out["screening_set.jsonl"] = dump_jsonl(f"{args.out}/screening_set.jsonl", screen)
    out["calibration_texts.jsonl"] = dump_jsonl(f"{args.out}/calibration_texts.jsonl", calib)
    out["blind_map.jsonl"] = dump_jsonl(f"{args.out}/blind_map.jsonl", blind)

    anchors = {
        "derivation": {
            "rule": "sha-sort by (id,text); seeded sample w/o replacement; sizes 150/40/256; blind map by blind_seed",
            "trace_sha256": sha_bytes(open(args.trace, "rb").read()),
            "derive_seed": args.derive_seed, "blind_seed": args.blind_seed,
            "trace_rows": len(rows),
        },
        "files": out,
    }
    with open(f"{args.out}/anchors.json", "w") as f:
        json.dump(anchors, f, indent=1, sort_keys=True)

    for k, v in out.items():
        print(f"  {k}: {v}")
    print("DERIVE_OK — disjointness asserted; hashes printed for anchors.json custody")

if __name__ == "__main__":
    main()
