#!/usr/bin/env python3
"""lib_pairjudge.py — blind pairwise judging machinery for Pilot 005 (R1 instrument).

Implements SPEC-PAIRJUDGE-v5.0. One judge call = one axis-targeted comparison
of two blind responses. Frozen conventions carried from lib_judge.py:
null/empty content = error; temperature 0; max_tokens 4096; reasoning policy
derived live from the /models capability map at panel time; this file contains
no model names, no prices, and no cell-conditional logic — those arrive as DATA.

Direction is by construction (ADDENDUM-08): the exam item carries `gold`
('A'|'B'); the judge answers 'A'|'B'|'T'; a tie scores 0.5. Certification:
score >= TAU (70/96) on EVERY axis (std variant items only). The lenmatch
variant subset is a verbosity-bias probe — reported, never gated.

CLI:
  python3 lib_pairjudge.py --exam delta_items.jsonl --judge <model-id> \
      --out results.jsonl --summary summary.json \
      [--key-file ~/pilot-env/openrouter-key] [--base https://openrouter.ai/api/v1] \
      [--mock --mock-skill 0.85] [--probe-pairs 12] [--tau 70]
"""
import argparse, hashlib, json, sys, time, urllib.request

AXES = ["clarity", "correctness", "completeness", "overall"]
TAU = 70  # wins out of 96 per axis; every axis binds (SPEC-PAIRJUDGE-v5.0 sec.5)

INSTR = {
    "clarity": ("You are comparing two responses to the same prompt. Judge ONLY clarity: "
                "organization, coherence, and readability. Ignore factual accuracy and coverage."),
    "correctness": ("You are comparing two responses to the same prompt. Judge ONLY correctness: "
                    "factual and logical accuracy. Ignore style, organization, and coverage."),
    "completeness": ("You are comparing two responses to the same prompt. Judge ONLY completeness: "
                     "coverage of everything the prompt asks. Ignore style and minor factual issues."),
    "overall": ("You are comparing two responses to the same prompt. Judge overall quality, "
                "weighing clarity, correctness, and completeness together."),
}

def build_pair_prompt(axis, prompt, a, b):
    """Single source of truth for the pairwise judge prompt (mirrors the
    Amendment-04 rule: the calibration probe IS the production probe)."""
    return (INSTR[axis] + "\n\nPROMPT:\n" + prompt +
            "\n\nRESPONSE A:\n" + a + "\n\nRESPONSE B:\n" + b +
            f"\n\nWhich response is better on {axis}? "
            "Reply with exactly one letter: A, B, or T (tie), nothing else.")

def parse_verdict(text):
    """First token, uppercased, in {A,B,T}; anything else = error (None)."""
    if not text or not text.strip():
        return None
    tok = text.strip().split()[0].strip('.').upper()
    return tok if tok in ("A", "B", "T") else None

def h(key):
    return int(hashlib.sha256(key.encode()).hexdigest(), 16)

def mock_verdict(judge, item, skill):
    """Deterministic local anchor: correct with probability `skill`, otherwise
    a wrong letter or a tie (50/50). No network. Used for harness dry-runs."""
    u = (h(f'{judge}|{item["item_id"]}|{item["axis"]}') % 1000) / 1000.0
    if u < skill:
        return item["gold"]
    wrong = [x for x in ("A", "B") if x != item["gold"]][0]
    return wrong if h(f'{item["item_id"]}|flip') % 2 == 0 else "T"

def load_model_capabilities(key, base):
    req = urllib.request.Request(f"{base}/models", headers={"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return {m["id"]: m for m in json.load(r)["data"]}

def reasoning_policy(caps, model):
    """Live capability-derived policy (ADDENDUM-03 mechanics, unchanged)."""
    sup = (caps.get(model, {}).get("supported_parameters") or [])
    if "reasoning" in sup:
        return {"effort": "low", "exclude": True}
    return {"enabled": False}

def call_judge(key, base, model, text, caps):
    payload = {"model": model, "messages": [{"role": "user", "content": text}],
               "temperature": 0, "max_tokens": 4096,
               "reasoning": reasoning_policy(caps, model)}
    req = urllib.request.Request(f"{base}/chat/completions", data=json.dumps(payload).encode(),
                                 headers={"Authorization": f"Bearer {key}",
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        body = json.load(r)
    return body["choices"][0]["message"].get("content"), body.get("usage", {})

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exam", required=True)
    ap.add_argument("--judge", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--key-file")
    ap.add_argument("--base", default="https://openrouter.ai/api/v1")
    ap.add_argument("--mock", action="store_true")
    ap.add_argument("--mock-skill", type=float, default=0.5)
    ap.add_argument("--probe-pairs", type=int, default=12)
    ap.add_argument("--tau", type=int, default=TAU)
    a = ap.parse_args()

    items = [json.loads(l) for l in open(a.exam, encoding="utf-8") if l.strip()]
    std = [r for r in items if r["variant"] == "std"]
    probe = [r for r in items if r["variant"] == "lenmatch"]
    # deterministic probe subset: first N pair indices per axis by item_id order
    probe_sel, seen = [], {}
    for r in probe:
        pair = r["item_id"].rsplit("-o", 1)[0]
        seen.setdefault(r["axis"], [])
        if pair not in seen[r["axis"]] and len(seen[r["axis"]]) < a.probe_pairs:
            seen[r["axis"]].append(pair)
        if pair in seen[r["axis"]]:
            probe_sel.append(r)
    queue = std + probe_sel

    caps, key = {}, None
    if not a.mock:
        key = open(a.key_file).read().strip()
        caps = load_model_capabilities(key, a.base)

    n_done = 0
    with open(a.out, "w", encoding="utf-8") as f:
        for it in queue:
            text = build_pair_prompt(it["axis"], it["prompt"], it["response_a"], it["response_b"])
            rec = {"item_id": it["item_id"], "axis": it["axis"], "variant": it["variant"],
                   "judge": a.judge, "gold": it["gold"]}
            if a.mock:
                v = mock_verdict(a.judge, it, a.mock_skill)
                rec.update(verdict=v, score={"A": 1.0, "B": 1.0, "T": 0.5}[v] if v == it["gold"]
                           else (0.5 if v == "T" else 0.0), raw="MOCK")
            else:
                try:
                    content, usage = call_judge(key, a.base, a.judge, text, caps)
                except Exception as e:  # frozen: transport/HTTP failure = error row
                    rec.update(verdict=None, error=f"{type(e).__name__}: {e}", raw="")
                    f.write(json.dumps(rec, ensure_ascii=False) + "\n"); continue
                v = parse_verdict(content or "")
                rec.update(verdict=v, raw=content,
                           usage={"prompt_tokens": usage.get("prompt_tokens"),
                                  "completion_tokens": usage.get("completion_tokens")})
                if v is None:
                    rec["error"] = "unparseable-or-empty"
                else:
                    rec["score"] = 1.0 if v == it["gold"] else (0.5 if v == "T" else 0.0)
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            n_done += 1
            if n_done % 48 == 0:
                print(f"  ... {n_done}/{len(queue)}", file=sys.stderr)

    rows = [json.loads(l) for l in open(a.out, encoding="utf-8")]
    summary = {"judge": a.judge, "mock": a.mock, "tau": a.tau, "axes": {}, "errors": 0}
    for ax in AXES:
        got = [r for r in rows if r["axis"] == ax and r["variant"] == "std"]
        err = sum(1 for r in got if r.get("error"))
        scored = [r for r in got if not r.get("error")]
        wins = sum(r.get("score", 0) for r in scored)
        n = len(got)
        summary["axes"][ax] = {"n": n, "scored": len(scored), "errors": err,
                               "wins": round(wins, 1), "rate": round(wins / n, 4) if n else None,
                               "pass": err == 0 and wins >= a.tau}
        summary["errors"] += err
    summary["certified"] = all(s["pass"] for s in summary["axes"].values())
    # verbosity-bias probe (reported, never gated)
    probe_rows = [r for r in rows if r["variant"] == "lenmatch" and not r.get("error")]
    if probe_rows:
        pv = {}
        for ax in AXES:
            got = [r for r in probe_rows if r["axis"] == ax]
            if got:
                pv[ax] = round(sum(r.get("score", 0) for r in got) / len(got), 4)
        summary["lenmatch_probe_rate"] = pv
    json.dump(summary, open(a.summary, "w"), indent=1)
    print(json.dumps(summary, indent=1))

if __name__ == "__main__":
    main()
