# RQ2 convex parity-distance diagnostic at 1.5 dB

Experiment: `RQ2-CONVEX-PARITY-DISTANCE-001`

Population: exposed frames `61969:62168`, all 200 cases

Status: **complete-valid candidate execution and post-commit score; the
optimization outcome is unresolved at the frozen update cap**

## Result in one sentence

The frozen fixed-step projected-gradient method recovered **0/200**
transmitted words and produced **0/200** parity-valid hard-decision estimates
through 6000 updates, but all 200 cases stopped above the registered
projected-gradient-mapping tolerance, so this result does not determine what
the convex objective's global minimizers decode to.

## Frozen method

The candidate minimized

```math
F(b)=\frac{1}{n}\left[L^{\mathsf T}b+
\frac{96}{2}\sum_c\operatorname{dist}^2(S_cb,P_c)\right]
```

over `b in [0,1]^n`.  Each local distance used the exact degree-six
Euclidean parity-polytope projection implemented in binary64 arithmetic.  The
only update was componentwise box-projected negative gradient with the global
Lipschitz step `1/288`.  Initialization, hard-decision rule, tie rule,
population, checkpoints, and the 6000-update cap were frozen prospectively in
the experiment card.

The candidate packet contained no transmitted-word, retained-outcome, BP, or
comparison-decoder fields, and the frozen candidate code path references none.
The transmitted word was opened only by the scorer after the candidate commit
and deterministic replay gate passed.

## Decoder counts

| Attempted updates | Transmitted-word recoveries | Any parity-valid latch | Wrong valid word | Stored-checkpoint tie coordinates |
|---:|---:|---:|---:|---:|
| 30 | 0/200 | 0/200 | 0/200 | 0 |
| 90 | 0/200 | 0/200 | 0/200 | 0 |
| 300 | 0/200 | 0/200 | 0/200 | 0 |
| 1000 | 0/200 | 0/200 | 0/200 | 0 |
| 3000 | 0/200 | 0/200 | 0/200 | 0 |
| 6000 | 0/200 | 0/200 | 0/200 | 0 |

No parity-valid hard-decision estimate appeared at any intervening update, so
there was no hidden transient recovery between checkpoints.

## Terminal classification

All 200 cases reached update 6000.  Every terminal projected-gradient mapping
was above `1e-8`, so the registered classification is:

| Terminal class | Count |
|---|---:|
| Numerical global optimum under the frozen tolerance | 0/200 |
| Optimization unresolved at the update cap | 200/200 |

The terminal mapping norm ranged from `2.4881e-5` to `1.15097e-2`, with
median `2.27729e-4`.  Because no case met the tolerance, none may be called a
minimizer, a parity-penalty failure, or a fractional global optimum under this
experiment ID.

## Trajectory mechanism fields

| Update | Median coded-bit errors | Median syndrome weight | Median mapping norm | Median fractional coordinates |
|---:|---:|---:|---:|---:|
| 0 | 1199 | 2035.5 | 33.4252 | 10200 |
| 30 | 901 | 1365.5 | 2.52990 | 5739.5 |
| 90 | 714 | 919 | 1.18939 | 4489.5 |
| 300 | 538 | 571 | 0.368281 | 3640 |
| 1000 | 419.5 | 418.5 | 0.0654415 | 3328.5 |
| 3000 | 384.5 | 386 | 0.00476410 | 3276.5 |
| 6000 | 382 | 387 | 0.000227729 | 3274 |

At update 6000, coded-bit errors ranged from 148 to 595 and syndrome weight
from 224 to 508.  The median maximum local check distance was `0.102299`, and
the median number of coordinates farther than `1e-8` from both box endpoints
was 3274.  The median normalized-objective decrease from update 3000 to 6000
was only `2.17763e-7`, positive on all 200 cases.  These fields show a late
objective/readout plateau with residual parity inconsistency and
fractionality, but they do not replace the failed stationarity gate.

## Validity and replay gates

- Synthetic projection, derivative, convexity, descent, and replay tests:
  `71859/71859` passed.
- Sealed source identities: all eight fields matched on `200/200` cases.
- Candidate scientific trace SHA-256:
  `2020306bb9d09d20e025528c2b9eba8a398f67e8c896b7329c8b3411c1c1dd20`.
- Primary and replay scientific traces were equal.  Timing and allocation
  telemetry were excluded from scientific equality as registered.
- Candidate commit SHA-256:
  `a22f2174336332b8512a43236d9d124228ff334c6871df57e9551e0c16382310`.
- Score commit SHA-256:
  `18d799cd6a3428459f3e8e4fc3e08ed9e5348e7369e47e3d5cbc57d9c9b116fa`.
- BP was neither opened nor run.

All source, packet, receipt, candidate, and score SHA-256 manifests verify
without a missing or changed member.
The primary pass used 1251.25 seconds summed over cases and the replay used
1249.21 seconds; all cases performed the frozen 6000 updates.

## Interpretation and next discriminating test

The prospective prediction said that at least one recovery would occur if
removing the nonconvex `J_C` wells and the historical shifted-sigmoid update
were sufficient.  The observed decoder count was zero, but the card also
required every zero-recovery case to meet the mapping tolerance before drawing
a conclusion about the global minimizer.  That condition failed on 200/200
cases.

Therefore this result closes only the frozen `lambda=96`, step `1/288`,
initialization, readout, and 6000-update protocol on this exposed population.
It does **not** close the convex objective, another convergent step sequence,
an exact constrained parity-polytope formulation, check-local replicas with
multipliers, or another objective.

A subsequent source-only gate implemented deterministic acceleration and
local-curvature backtracking on the unchanged function and screened them,
together with direct bound-constrained L-BFGS-B, on a production-size
synthetic graph.  All reduced the residual, but none reached the same `1e-8`
projected-stationarity tolerance.  No second population run was opened.  That
follow-up is recorded in `SOLVER_SOURCE_GATE.md`; it is solver-feasibility
evidence, not a new 1.5-dB decoder result or evidence against the objective.

## Canonical artifacts

- Prospective card: `../../../research/rq2_convex_parity_distance_001_card.md`
- Candidate commit: `candidate/CANDIDATE_COMMITTED.txt`
- Candidate manifest: `candidate/CANDIDATE_MANIFEST.sha256`
- Candidate trace: `candidate/candidate_trace.csv`
- Post-commit score: `score/score_summary.csv`
- Score commit: `score/SCORE_COMMITTED.txt`
- Score manifest: `score/SCORE_MANIFEST.sha256`
- Successor source gate: `SOLVER_SOURCE_GATE.md`

This exposed-population result leaves the two-hop Stage-B chain and every
reserved untouched range unchanged.
