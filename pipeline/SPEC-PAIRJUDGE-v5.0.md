# Effiq Pairwise Judging — Spec v5.0 (FROZEN 2026-10-20)

Status: FROZEN before the R1 seating run, as mandated by ADDENDUM-08 sec.6
(sealed addendum, private ops repo). Any change to this spec after the first
calibration API call requires a new owner-ratified addendum.

This spec defines the pairwise judging machinery for **both** the judge-calibration
exam and the production judging stages. One machinery, two consumers — the
calibration probe IS the production probe (Amendment-04 rule, carried).

## 1. Why pairwise (normative reference)

The retired absolute-calibration exam (v2) measured agreement with borrowed
coarse gold labels on a stretched 1–10 scale; one axis measured a disclosed
proxy construct. ADDENDUM-08 sec.1–4 records the autopsy and the first
principle: the production need is *ordinal discrimination between two blind
responses*, so the certification instrument measures exactly that, with
direction fixed by construction and zero human-subjective scoring.

## 2. Item contract (data)

Each exam/production item is a JSONL record:

```
item_id, lang, axis ∈ {clarity, correctness, completeness, overall},
variant ∈ {std, lenmatch}, orientation ∈ {0,1}, base_id,
prompt, response_a, response_b, gold ∈ {A,B}, operator_log, sha256
```

- Blinding: the judge sees only `prompt`, `response_a`, `response_b`, and the
  axis instruction. Item identity, axis-targeting operator, and gold never
  enter the prompt.
- Both orientations of every pair are judged (position-bias control).
- lenmatch variants (weak padded with neutral filler to ≥90% of strong length)
  are the verbosity-bias probe: reported, never gated.

## 3. Prompt contract (single source of truth)

`lib_pairjudge.build_pair_prompt(axis, prompt, a, b)`:

```
<axis instruction>            (fixed DATA strings in lib_pairjudge.INSTR)

PROMPT:
<prompt>

RESPONSE A:
<response_a>

RESPONSE B:
<response_b>

Which response is better on <axis>? Reply with exactly one letter: A, B, or T (tie), nothing else.
```

No rubric file, no few-shot, no model names anywhere in the machinery.

## 4. Call contract (frozen conventions carried from lib_judge.py)

- temperature 0, max_tokens 4096
- reasoning policy derived live from the `/models` capability map at panel
  time (`reasoning_policy`): `{"effort":"low","exclude":true}` when supported,
  else `{"enabled":false}` — pinned in the run's panel.json
- empty or unparseable content = error row (never silently rescored)
- parse rule: first whitespace-separated token, trailing '.' stripped,
  uppercased, must be ∈ {A, B, T}; anything else = error
- HTTP/transport failure = error row; retry policy is a stage concern and must
  be recorded in the run archive

## 5. Certification rule (seated judges)

Per candidate judge, per axis, over the 96 std items (48 pairs × 2 orientations):

```
score = wins + 0.5 × ties        (gold is never T; T scores 0.5 for either side)
PASS(axis) ⟺ score ≥ τ = 70      (binomial self-check in ADDENDUM-08 sec.5:
                                  skill 0.65 → ≈0% four-axis pass;
                                  0.80 → 86.7%; 0.90+ → ≈100%)
CERTIFIED ⟺ PASS on all four axes
```

Single run; no three-run protocol; no median. The lenmatch probe subset
(12 pairs/axis, deterministic selection by item_id order) is analyzed and
reported alongside, never part of τ.

## 6. Production adaptation (stages 16/18)

Production pairwise judging reuses `build_pair_prompt`, the call contract,
and the parse rule verbatim. Production items carry no `gold`; the verdict
letter plus orientation balancing replaces axis-score vectors. Worst-judge
binding and panel rules remain stage concerns (caller side), unchanged.

## 7. Frozen artifacts (hashes recorded in the private run archive)

- exam item set: `delta_items.jsonl` + `manifest.json` (constructor +
  seed archived alongside; constructor deterministic — identical manifest
  sha256 on re-run)
- this spec; `lib_pairjudge.py`; the run's `panel.json`
- verdict: every judgment row archived raw (prompt hash, raw reply, verdict,
  usage) before any aggregation
