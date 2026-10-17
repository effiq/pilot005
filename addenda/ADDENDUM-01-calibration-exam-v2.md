# ADDENDUM-01 — Calibration Exam v2 Registration

**Status:** Ratified — owner review 2026-10-17
**Protocol:** Pilot005 Protocol Lock v4.2
**Date:** 2026-10-17
**Dual-track reference:** AMENDMENT-15 (internal numbering)

## 1. Scope

This addendum registers the Pilot005 judge-calibration exam (v2) into Appendix C of the Protocol. The exam is the instrument used to validate judge models before any cell ignition; its contents are calibration data only and are never used for training, evaluation reporting, or publication.

## 2. Registered artifacts

| File | Rows | SHA-256 |
|---|---|---|
| calibration-exam-v2-en.jsonl | 96 (+1 watermark line) | d42740d32280e28fde6411224986e60dfdb79496f26ff5c6a777071365095af2 |
| calibration-exam-v2-ar.jsonl | 96 (+1 watermark line) | 20c80ccef8287d91ca2f3664418089da14e1dab010a6c925205ead59e7f5ba1b |
| PROVENANCE.json | — | 6daacd9da42859e16a7cb1df3449b0e3910d977aca79b6b3a478c2bbdafef6e7 |

The exam content itself is held as private material (pod volume and operator custody); only the hashes above enter this repository.

## 3. Instrument design (summary)

- Four axes per language (clarity, completeness, correctness, overall); 24 items per axis; EN and AR volumes.
- Harvested axes use high-contrast selection (12 low + 12 high per axis) with deterministic, documented scoring rules over the source datasets' labels (full rules in PROVENANCE.json).
- The completeness axis is constructed, not harvested: each item is a multi-component prompt whose truth is carried by construction — a complete answer covering all requested components, and a paired abridged variant omitting components under a rule disclosed in the item's construction record. No verbosity proxy is used.
- Length caps: prompt ≤ 1000 chars, response ≤ 2000 chars (EN and AR).

## 4. Validation before freeze

Simulated-judge discrimination check (2000 trials per archetype per axis-cell; Pearson r of judge scores against carried truth):

- strong and mediocre archetypes: r ≥ 0.90 on all 8 axis-cells (acceptance bar: 0.80)
- weak archetype: r < 0.80 on all 8 axis-cells (the instrument discriminates judge quality)

## 5. Firewall

The exam was finalized and hashed on 2026-10-17 before any judge scoring data exists. Any modification after this registration requires a new addendum with a fresh firewall statement.

## 6. Effect on Appendix C

Appendix C of the Protocol is extended by the three hashes in §2. No existing line of the Protocol or of FROZEN-LINES.json is modified by this addendum.
