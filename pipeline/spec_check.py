#!/usr/bin/env python3
"""spec_check.py — mechanical validator for effiq-spec/v1 (Pilot 005).

Any breach = REFUSED (exit 1) before ignition. This validator is model-agnostic:
it contains NO model names and NO model-conditional logic. All variation lives
in the spec data it validates. (Protocol Lock v4.2 classification test.)
"""
import hashlib, json, os, re, sys

FORBIDDEN_SEED_BASES = {20263000, 20264000, 20265000}  # pilots 002/003/004 families
SIZES = {"n_frozen": 150, "n_screen": 40, "n_calib_texts": 256}
ROLES = {"verdict-bearing", "shakedown", "regression"}
TRACE_SOURCES = {"wildchat", "wildchat-ar", "synthetic"}
TOP_KEYS = {"schema", "cell", "model", "hardware", "load", "generation", "rubric", "anchors", "private_segment_sha256"}

def die(msg):
    print(f"REFUSED: {msg}", file=sys.stderr); sys.exit(1)

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

def main(spec_path, repo_root):
    try:
        spec = json.load(open(spec_path))
    except Exception as e:
        die(f"spec is not valid JSON: {e}")

    unknown = set(spec) - TOP_KEYS
    if unknown: die(f"unknown top-level fields: {sorted(unknown)}")
    missing = TOP_KEYS - set(spec)
    if missing: die(f"missing top-level fields: {sorted(missing)}")

    if spec["schema"] != "effiq-spec/v1":
        die(f"schema must be effiq-spec/v1, got {spec['schema']!r}")

    cell = spec["cell"]
    if cell.get("role") not in ROLES: die(f"cell.role must be one of {sorted(ROLES)}")
    if not cell.get("id"): die("cell.id empty")

    m = spec["model"]
    if not re.fullmatch(r"[0-9a-f]{40}", str(m.get("revision", ""))):
        die("model.revision must be a 40-hex commit sha (branches/tags forbidden)")
    if "/" not in str(m.get("repo_id", "")): die("model.repo_id must be owner/name")
    if not m.get("family"): die("model.family required (profile-prior rule input)")
    if int(m.get("max_model_len", 0)) <= 0: die("model.max_model_len must be positive")
    rx = m.get("profile_scope_regex", "")
    if not rx or rx.startswith("PIN_AT_IGNITION"): die("model.profile_scope_regex must be a real regex (pin before ignition)")
    try: re.compile(rx)
    except re.error as e: die(f"model.profile_scope_regex does not compile: {e}")

    hw = spec["hardware"]
    if hw.get("gpu") != "H100" or int(hw.get("count", 0)) != 1:
        die("hardware must be a single H100 (Pilot 005 scope)")

    load = spec["load"]
    if load.get("trace_source") not in TRACE_SOURCES:
        die(f"load.trace_source must be one of {sorted(TRACE_SOURCES)}")
    if load["trace_source"] == "synthetic" and load.get("synthetic_seed") is None:
        die("synthetic trace requires synthetic_seed (declared, reproducible)")

    gen = spec["generation"]
    if float(gen.get("temperature", -1)) != 0.0: die("generation.temperature must be 0 (frozen craft)")
    if gen.get("natural_stopping") is not True: die("generation.natural_stopping must be true")

    rub = spec["rubric"]
    rp = os.path.join(repo_root, rub.get("file", ""))
    if not os.path.isfile(rp): die(f"rubric file not found in repo: {rub.get('file')}")
    rub_sha = sha(rp)

    a = spec["anchors"]
    for k, want in SIZES.items():
        if a.get(k) != want: die(f"anchors.{k} must be {want} (frozen craft)")
    for sk in ("derive_seed", "run_seed_base", "blind_seed"):
        v = a.get(sk)
        if not isinstance(v, int): die(f"anchors.{sk} must be an integer")
        if v in FORBIDDEN_SEED_BASES: die(f"anchors.{sk}={v} collides with a sealed-pilot seed family")
    if cell["role"] == "regression" and not a.get("reuse"):
        die("regression cell must set anchors.reuse (byte-reproduction discipline)")
    if cell["role"] != "regression" and a.get("reuse"):
        die("anchors.reuse is regression-only")

    psha = spec.get("private_segment_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", str(psha)):
        die("private_segment_sha256 must be a 64-hex sha256 of the gate-layer file")

    spec_sha = sha(spec_path)
    print(json.dumps({
        "SPEC_OK": True, "cell_id": cell["id"], "role": cell["role"],
        "spec_sha256": spec_sha, "rubric_sha256": rub_sha,
        "model": m["repo_id"], "revision": m["revision"], "family": m["family"],
    }, indent=1))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: spec_check.py <spec.json> <repo_root>", file=sys.stderr); sys.exit(2)
    main(sys.argv[1], sys.argv[2])
