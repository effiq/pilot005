# Pilot 005 — Cell-2 Verdict: Recomputation Sheet

Everything on this page is recomputed from the per-run measurement rows below
with the frozen algorithm in `pipeline/stages/19-dual-gates.sh`. No number in
the verdict rests on authority; each rests on arithmetic you can redo.

## 1. Per-run measurement rows (stage-19 run `run_20261022T043544Z`)

Throughput in tokens/second, at the full precision of the archived
`meas_{A,B,C}.json` rows. A = BF16 baseline, B = stock FP8, C = winning recipe
arm (b4-w2, recipe sha256 `a9b66ffa…`).

| run | A (BF16) | B (stock FP8) | C (recipe) | B/A | C/A |
|---|---|---|---|---|---|
| 1  | 79.43228685353277 | 118.2467330064798 | 101.23939879886494 | 1.488648 | 1.274537 |
| 2  | 69.20076863546582 | 98.03515725004611 | 89.62448361714566 | 1.416677 | 1.295137 |
| 3  | 75.5975844636505 | 110.30131456541105 | 98.36259490516812 | 1.459059 | 1.301134 |
| 4  | 76.95672787893817 | 109.38850610685405 | 98.7365872623821 | 1.421429 | 1.283014 |
| 5  | 80.43747411747714 | 117.29458287707806 | 107.9417400692843 | 1.458208 | 1.341933 |
| 6  | 75.76296436788617 | 111.95310935381477 | 101.62012569854609 | 1.477676 | 1.341290 |
| 7  | 76.14784119315055 | 115.40845758310547 | 99.68992358610527 | 1.515584 | 1.309163 |
| 8  | 79.52594576418812 | 114.28825617624294 | 101.8794178762617 | 1.437119 | 1.281084 |
| 9  | 77.64106913018202 | 111.28911073752464 | 99.92490094447083 | 1.433379 | 1.287011 |
| 10 | 78.1670603137626 | 115.76531553094502 | 103.10564974290368 | 1.480999 | 1.319042 |

## 2. Frozen verdict algorithm

From `pipeline/FROZEN-LINES.json`: `n_runs = 10`,
`bootstrap_resamples = 100000`, `bootstrap_seed = 20262002`,
`migration_ci_lower = 1.20`, `recipe_ci_lower = 1.50`. Run directories are
ordered lexicographically (`run_1, run_10, run_2, …, run_9`) exactly as the
frozen code's `sorted(glob(...))` does — the bootstrap draw sequence depends
on that order.

```python
import random, statistics

A = [79.43228685353277, 69.20076863546582, 75.5975844636505, 76.95672787893817,
     80.43747411747714, 75.76296436788617, 76.14784119315055, 79.52594576418812,
     77.64106913018202, 78.1670603137626]
B = [118.2467330064798, 98.03515725004611, 110.30131456541105, 109.38850610685405,
     117.29458287707806, 111.95310935381477, 115.40845758310547, 114.28825617624294,
     111.28911073752464, 115.76531553094502]
C = [101.23939879886494, 89.62448361714566, 98.36259490516812, 98.7365872623821,
     107.9417400692843, 101.62012569854609, 99.68992358610527, 101.8794178762617,
     99.92490094447083, 103.10564974290368]
# lexicographic run order (run_1, run_10, run_2, ..., run_9), as the frozen code sorts
order = [0, 9, 1, 2, 3, 4, 5, 6, 7, 8]
A = [A[i] for i in order]; B = [B[i] for i in order]; C = [C[i] for i in order]

def ci_lower(base, arm, resamples=100000, seed=20262002):
    rng = random.Random(seed)
    ratios = [x / y for x, y in zip(arm, base)]
    m = len(ratios); boots = []
    for _ in range(resamples):
        boots.append(statistics.mean(ratios[rng.randrange(m)] for _ in range(m)))
    boots.sort()
    return boots[int(0.05 * len(boots))], statistics.mean(ratios)

mig_lo, mig_mean = ci_lower(A, B)   # expect 1.443269663846213, 1.4588778450245719 -> >= 1.20 PASS
rec_lo, rec_mean = ci_lower(A, C)   # expect 1.291763319281766, 1.3033346355694 -> < 1.50 FAIL
```

Expected output — bit-exact equality with the sealed `VERDICT.json` when the
script is run as written on the full-precision rows:

| quantity | recomputed | sealed | line | outcome |
|---|---|---|---|---|
| migration CI lower | 1.443269663846213 | 1.443269663846213 | 1.20 | PASS |
| migration mean | 1.4588778450245719 | 1.4588778450245719 | — | — |
| recipe CI lower | 1.291763319281766 | 1.291763319281766 | 1.50 | FAIL |
| recipe mean | 1.3033346355694 | 1.3033346355694 | — | — |

## 3. Quality gate arithmetic (stage-18, n=150)

Frozen tolerances: `quality_tolerance_axis = -0.1`,
`quality_tolerance_overall = -0.1`; worst-judge binds. Per-judge deltas are
listed in VERDICT.md. The minimum per-axis delta across seats is
deepseek-chat-v3-0324's correctness −0.1067 < −0.1 → quality gate FAIL,
regardless of the other two seats. Cell verdict = recipe performance FAIL
∧ quality FAIL → FAIL, with `straddle=false`.

## 4. What is not on this page

- Raw per-request logs (`raw_A/B/C.jsonl`), judge transcripts, and generation
  outputs are archived in the evidence repository under per-stage
  `custody.sha256` chains; available on request for audit.
- Gate-layer recipe parameters (profiling / smoothing / calibration values)
  are trade-secret by design; their sha256 is pinned in custody without
  disclosure of content.
- Environment stack at run time is pinned in FROZEN-LINES `env_stack`
  (torch 2.13.0, vllm 0.31.0, compressed-tensors 0.17.0, transformers 5.10.4,
  llmcompressor 0.12.0).
