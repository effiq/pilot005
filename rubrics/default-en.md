# Judging Rubric (EN) — Pilot 005 default

Blind pairwise-absolute scoring, frozen from Pilot 002/004 craft. Score each axis 1–10 (integer). No explanations in the reply — numbers only, in the declared order.

1. **Clarity** — is the response understandable, well-structured, and free of rambling?
2. **Correctness** — is the substance right for the prompt as asked?
3. **Completeness** — does it cover the whole prompt with an appropriate amount of detail: no important part of the request left unanswered, and no unnecessary padding? (Amendment-04: definition aligned to the human-label construct in the calibration set — Addendum-01's completeness stratum is verbosity-anchored, i.e. appropriateness of detail.)
4. **Overall** — holistic quality as a production answer.

Gate semantics (frozen, pipeline-side): per judge, overall delta (candidate − reference) ≥ −0.1 AND every axis delta ≥ −0.1; the panel's worst judge binds.
