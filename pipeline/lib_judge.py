#!/usr/bin/env python3
"""lib_judge.py — blind judging machinery for Pilot 005 (stages 16/18).

One judge call = one rubric-scored response. Amendment-01/02 mechanics (frozen):
reasoning excluded from the response (several frozen-pool endpoints make
reasoning mandatory, so it cannot be disabled — Amendment-02); null/empty
content = error; max_tokens 1024; temperature 0. The rubric text arrives as
DATA (spec.rubric.file) — this file contains no model names and no
cell-conditional logic.

CLI:
  python3 lib_judge.py --panel panel.json --rubric rubric.md \
      --blind blind_map.jsonl --candidates gen_C.jsonl --reference gen_A.jsonl \
      --frozen frozen_set.jsonl --out scores.jsonl \
      [--key-file ~/pilot-env/openrouter-key] [--mock]

Score row: {"blind_id","frozen_index","judge","axis_scores":[c,co,cm,o]}
Panel rule lives in the CALLER (worst-judge binding is a stage concern).
"""
import argparse, hashlib, json, os, random, sys, time, urllib.request

AXES = ["clarity", "correctness", "completeness", "overall"]

def sha(p): return hashlib.sha256(open(p, "rb").read()).hexdigest()

def load_jsonl(p):
    return [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]

def build_prompt(rubric, prompt, response):
    """Single source of truth for the judge prompt (Amendment-04).
    Stage-14 calibration imports this so the calibration probe IS the
    production probe — not an imitation of it (Amendment-03 aligned the
    axis contract but left the rubric body out of the probe; D7)."""
    return (rubric.strip() + "\n\nPROMPT:\n" + prompt + "\n\nRESPONSE:\n" + response +
            "\n\nReply with exactly 4 integers (clarity, correctness, completeness, overall), space-separated, nothing else.")

def judge_one(model, rubric, prompt, response, key, base, mock, local_base=None):
    if mock:
        # mock scores keyed on (judge, prompt) only → candidate/reference deltas ≈ 0,
        # so the mock chain exercises the PASS path deterministically
        rng = random.Random(hash((model, sha_str(prompt))) & 0xFFFFFFFF)
        return [max(1, min(10, round(7 + rng.gauss(0, 1.0)))) for _ in AXES]
    user = build_prompt(rubric, prompt, response)
    if "LOCAL-FALLBACK" in model:
        # Amendment-12 (D19): the sentinel is a seat marker, not an OpenRouter id.
        # Route to the pod-local anchor server (started by the CALLER via lib_serve;
        # served-model-name is "cell-model" by lib_serve contract). Score rows keep
        # the sentinel string as judge identity — honest labeling, disclosed.
        # chat_template_kwargs.enable_thinking=False: Qwen3 thinks by default and
        # would burn the 4096 budget on reasoning before the 4 integers.
        if not local_base:
            sys.exit(f"FATAL: local-fallback sentinel {model!r} seated but --local-base "
                     "not provided — caller must bring up the anchor server (Amendment-12)")
        body = json.dumps({"model": "cell-model", "messages": [{"role": "user", "content": user}],
                           "chat_template_kwargs": {"enable_thinking": False},
                           "max_tokens": 4096, "temperature": 0}).encode()
        base, key = local_base, "EMPTY"
    else:
        body = json.dumps({"model": model, "messages": [{"role": "user", "content": user}],
                           "reasoning": {"exclude": True}, "max_tokens": 4096, "temperature": 0}).encode()  # 4096: mandatory reasoning starved the 1024 budget (Amendment-03)
    req = urllib.request.Request(f"{base}/chat/completions", data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        content = json.loads(r.read())["choices"][0]["message"]["content"]
    if not content or not content.strip():
        raise RuntimeError("empty judge content = error (Amendment-01)")
    nums = [int(t) for t in content.replace(",", " ").split() if t.lstrip("-").isdigit()][:4]
    if len(nums) != 4:
        raise RuntimeError(f"unparseable judge reply: {content[:120]!r}")
    return [max(1, min(10, n)) for n in nums]

def sha_str(s): return hashlib.sha256(s.encode()).hexdigest()[:16]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--panel", required=True)      # from stage 14 panel.json (seated judges)
    ap.add_argument("--judge", default=None)       # optional single-judge override (screening)
    ap.add_argument("--rubric", required=True)
    ap.add_argument("--blind", required=True)
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--reference", required=True)
    ap.add_argument("--frozen", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key-file", default="$HOME/pilot-env/openrouter-key".replace("$HOME", __import__("os").path.expanduser("~")))
    ap.add_argument("--base", default="https://openrouter.ai/api/v1")
    ap.add_argument("--local-base", default=None,
                    help="local anchor server base URL (e.g. http://127.0.0.1:8000/v1) for LOCAL-FALLBACK seats")
    ap.add_argument("--mock", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="test hook: cap items")
    a = ap.parse_args()

    rubric = open(a.rubric, encoding="utf-8").read()
    blind = load_jsonl(a.blind)
    cand = {r["id"]: r for r in load_jsonl(a.candidates)}
    ref = {r["id"]: r for r in load_jsonl(a.reference)}
    frozen = load_jsonl(a.frozen)
    if a.limit: blind = blind[: a.limit]

    panel = json.load(open(a.panel))
    judges = [a.judge] if a.judge else [panel["seated"][s] for s in ("chief", "second", "third")]
    # Amendment-12 (D19): local-fallback sentinels route to the pod-local anchor
    # via --local-base (per-judge routing in judge_one). Fail loudly if a sentinel
    # is seated but the caller brought no local endpoint.
    if any("LOCAL-FALLBACK" in j for j in judges) and not a.local_base and not a.mock:
        sys.exit("FATAL: local-fallback sentinel among seated judges but --local-base "
                 "not provided — caller must bring up the anchor server (Amendment-12)")
    key = "" if a.mock else open(a.key_file).read().strip()

    n_done = 0
    # Amendment-12: atomic output — write to .tmp and rename on success, so a
    # crash mid-judging never leaves a partial file that resume-skip guards
    # would mistake for a completed arm.
    tmp_out = a.out + ".tmp"
    with open(tmp_out, "w", encoding="utf-8") as out:
        for entry in blind:
            item = frozen[entry["frozen_index"]]
            for which, pool in (("candidate", cand), ("reference", ref)):
                if item["id"] not in pool:
                    print(f"FATAL: {which} output missing for {item['id']}", file=sys.stderr); sys.exit(1)
            for j in judges:
                for which, pool in (("candidate", cand), ("reference", ref)):
                    scores = judge_one(j, rubric, item["text"], pool[item["id"]]["output"], key, a.base, a.mock, a.local_base)
                    out.write(json.dumps({
                        "blind_id": entry["blind_id"], "frozen_index": entry["frozen_index"],
                        "item_id": item["id"], "judge": j, "which": which,
                        "axes": dict(zip(AXES, scores)),
                    }, ensure_ascii=False, sort_keys=True) + "\n")
                    n_done += 1
                    if n_done % 40 == 0:
                        out.flush(); print(f"  judged {n_done} rows…", flush=True)
    os.replace(tmp_out, a.out)   # commit only on clean completion
    print(f"JUDGE_OK rows={n_done} out={a.out}")
    print(f"custody: rubric={sha(a.rubric)[:16]}… blind={sha(a.blind)[:16]}… panel={sha(a.panel)[:16]}…")

if __name__ == "__main__":
    main()
