# Pilot 005 — Cell-1 Baseline: Recomputation Sheet

Everything on this page is recomputed from the per-run measurement rows below
with the frozen algorithm in `pipeline/stages/19-dual-gates.sh`. Read the
load-bearing caveats in VERDICT.md first: these figures were produced under
the pre-delta-calibration judge arrangement (ADDENDUM-15) and are not
scale-comparable with cell-2/3 results.

## 1. Per-run measurement rows (stage-19 confirmation run `run_20261018T005723Z`)

Throughput in tokens/second, at the full precision of the archived
`meas_{A,B,C}.json` rows. A = BF16 baseline, B = stock FP8, C = recipe arm
(b2-smooth-exempt — see caveat (b) in VERDICT.md).

| run | A (BF16) | B (stock FP8) | C (recipe) | B/A | C/A |
|---|---|---|---|---|---|
| 1  | 40.00231517839659 | 62.86646224494026 | 59.95008898643015 | 1.571571 | 1.498665 |
| 2  | 39.52438246892283 | 62.236464545434735 | 61.571083762542244 | 1.574635 | 1.557800 |
| 3  | 37.48882306090445 | 58.072091608522925 | 58.39133033729373 | 1.549051 | 1.557566 |
| 4  | 36.80286947688834 | 56.20629088106381 | 55.26120667205344 | 1.527226 | 1.501546 |
| 5  | 37.341993008899685 | 59.18088859699192 | 57.77799263492468 | 1.584835 | 1.547266 |
| 6  | 37.99800947305109 | 60.141164303719364 | 59.63367809220539 | 1.582745 | 1.569390 |
| 7  | 38.97625854979554 | 63.152739570528695 | 62.12697919692276 | 1.620287 | 1.593970 |
| 8  | 39.02346870197669 | 61.78605697744969 | 60.97452219461115 | 1.583305 | 1.562509 |
| 9  | 40.08552679521809 | 60.931589037576025 | 64.60587104118682 | 1.520040 | 1.611701 |
| 10 | 39.62603163168601 | 62.27201015521406 | 62.39568141309876 | 1.571492 | 1.574613 |

## 2. Frozen verdict algorithm

Same frozen parameters as all Pilot 005 cells (`pipeline/FROZEN-LINES.json`):
`n_runs = 10`, `bootstrap_resamples = 100000`, `bootstrap_seed = 20262002`,
`migration_ci_lower = 1.20`, `recipe_ci_lower = 1.50`; lexicographic run
order (`run_1, run_10, run_2, …, run_9`).

```python
import random, statistics

A = [40.00231517839659, 39.52438246892283, 37.48882306090445, 36.80286947688834,
     37.341993008899685, 37.99800947305109, 38.97625854979554, 39.02346870197669,
     40.08552679521809, 39.62603163168601]
B = [62.86646224494026, 62.236464545434735, 58.072091608522925, 56.20629088106381,
     59.18088859699192, 60.141164303719364, 63.152739570528695, 61.78605697744969,
     60.931589037576025, 62.27201015521406]
C = [59.95008898643015, 61.571083762542244, 58.39133033729373, 55.26120667205344,
     57.77799263492468, 59.63367809220539, 62.12697919692276, 60.97452219461115,
     64.60587104118682, 62.39568141309876]
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

mig_lo, mig_mean = ci_lower(A, B)   # expect 1.5537390325570835, 1.5685186336127843 -> >= 1.20 PASS
rec_lo, rec_mean = ci_lower(A, C)   # expect 1.5394831644488498, 1.5575026398261191 -> >= 1.50 PASS
```

Expected output — bit-exact equality with the sealed `VERDICT.json` when run
as written on the full-precision rows:

| quantity | recomputed | sealed | line | outcome |
|---|---|---|---|---|
| migration CI lower | 1.5537390325570835 | 1.5537390325570835 | 1.20 | PASS |
| migration mean | 1.5685186336127843 | 1.5685186336127843 | — | — |
| recipe CI lower | 1.5394831644488498 | 1.5394831644488498 | 1.50 | PASS |
| recipe mean | 1.5575026398261191 | 1.5575026398261191 | — | — |

## 3. Quality gate arithmetic (stage-18, n=150)

Single local-fallback judge seat (limitation disclosed; see VERDICT.md caveat
(a)). Overall delta +0.200, per-axis deltas clarity +0.193 / correctness
+0.213 / completeness +0.233 — all above the −0.1 tolerances → quality gate
PASS under the worst-judge rule (one seat, so that seat is the worst seat).

## 4. What is not on this page

- Raw per-request logs, judge transcripts, and generation outputs are
  archived in the evidence repository under per-stage `custody.sha256`
  chains; available on request for audit.
- Gate-layer recipe parameters are trade-secret by design; their sha256 is
  pinned in custody without disclosure of content.
- Environment stack at run time is pinned in FROZEN-LINES `env_stack`.
