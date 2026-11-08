# Differentiable convex-parity SNR threshold result

Experiment: `RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001`

Status: complete-valid exposed-development threshold audit

Date: 8 November 2026

## Answer

For the frozen differentiable convex parity-distance objective, initialization,
accelerated projected-gradient schedule, and 30-update budget, the stable
working threshold under the active `candidate >= BP - 30` recovery-count rule
is **4.4 dB** on the tested exposed-development population.

Two stricter reference points are:

- **4.5 dB:** the first tested level with at least 190/200 transmitted-word
  recoveries;
- **4.8 dB:** the first tested level with 200/200 recoveries, equal to exact
  sum-product BP's count on that level.

This is not a code threshold or an untouched confirmation result. It is the
lowest tested exposed-development SNR at which this exact method and work
budget met the registered target and every higher tested fine-grid level also
met it.

Source tables: [`coarse snr_summary.csv`](coarse_score/snr_summary.csv),
[`fine snr_summary.csv`](fine_score/snr_summary.csv), and
[`fine threshold_summary.txt`](fine_score/threshold_summary.txt).

## Frozen method

The caller-visible state is one scalar `b_i in [0,1]` per bit, initialized by

```math
b_i^{(0)}=\frac{1-\tanh(L_i/2)}{2}.
```

The normalized objective is

```math
F(b)=\frac{1}{n}\left[L^\mathsf{T}b
+48\sum_c \operatorname{dist}^2(S_cb,\mathcal P_c)\right],
```

where `\mathcal P_c` is check `c`'s exact degree-six even-parity polytope. The candidate
used the frozen global curvature `288`, exact Euclidean parity-polytope
projection, componentwise box projection, and feasible accelerated recurrence
for exactly 30 updates. It did not call BP or open the transmitted word during
candidate execution.

The objective is continuously differentiable. The polytope and box
projections in the optimization path are differentiable almost everywhere.
The hard decision, tie test, syndrome, and first-valid latch are evaluation
operations outside that differentiable path; this result does not claim that
the discrete scorer is differentiable.

## Coarse sweep

The registered coarse population used all 24 frames `20001:20024` at each SNR
from 1.5 to 12.0 dB in 0.5-dB steps. Exact sum-product BP recovered 24/24 at
every level. The candidate recovered:

| SNR range | Candidate | BP |
|---|---:|---:|
| 1.5--3.5 dB | 0/24 at every level | 24/24 |
| 4.0 dB | 11/24 | 24/24 |
| 4.5--12.0 dB | 24/24 at every level | 24/24 |

The first provisional coarse crossing was therefore 4.5 dB. The coarse sweep
selected, but did not itself establish, the fine-grid threshold.

## Fine sweep

The registered fine population used all 200 frames `30001:30200` at every
level from 4.0 to 5.0 dB in 0.1-dB steps. There was no case selection.

| Es/N0 (dB) | Candidate | BP | Candidate - BP | BP-minus-30 target | At least 190 |
|---:|---:|---:|---:|:---:|:---:|
| 4.0 | 87/200 | 200/200 | -113 | fail | no |
| 4.1 | 122/200 | 200/200 | -78 | fail | no |
| 4.2 | 150/200 | 200/200 | -50 | fail | no |
| 4.3 | 161/200 | 200/200 | -39 | fail | no |
| **4.4** | **177/200** | **200/200** | **-23** | **pass** | no |
| **4.5** | **190/200** | **200/200** | **-10** | **pass** | **yes** |
| 4.6 | 195/200 | 200/200 | -5 | pass | yes |
| 4.7 | 199/200 | 200/200 | -1 | pass | yes |
| **4.8** | **200/200** | **200/200** | **0** | **pass** | **yes** |
| 4.9 | 200/200 | 200/200 | 0 | pass | yes |
| 5.0 | 200/200 | 200/200 | 0 | pass | yes |

At every fine-grid level, the candidate had zero wrong parity-valid words,
zero terminal tie cases, and zero tie coordinates across the complete
30-update traces. Every level from 4.4 through 5.0 dB passed, so 4.4 dB is a
stable suffix rather than an isolated crossing.

The terminal projected-gradient mapping norms remained well above the earlier
`1e-8` continuous-stationarity tolerance, including at recovered levels.
Recovery here is therefore a parity-valid hard-decision event during a fixed
30-update path, not evidence that the continuous optimizer reached a global
minimum.

## Integrity and execution boundary

- source-only and synthetic preflight: 139/139 assertions passed;
- graph SHA-256:
  `94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d`;
- coarse activation SHA-256:
  `77865a4d872c0eb5e3c10298c312e3a9e833623d7d21733474e911bff2f8c794`;
- fine activation SHA-256:
  `0038c40991ae4485800cbacc640fa9c12d3d6f18ace1beb0946d95065f3936be`;
- coarse candidate scientific trace SHA-256:
  `a181af8be06fd8a059d2943ea3e92085da3b12e4be79cf93f42660000ca0dda8`;
- fine candidate scientific trace SHA-256:
  `092f7e79433ab58b000533bca8df5b4c85a2d815bd21b9cac7a56085c8aee487`;
- coarse committed-score SHA-256:
  `cc0a7c8dc0ac9bf5611b2ff7710cdfb6cd3385722515475fc6fe36f782ab60d7`;
- fine committed-score SHA-256:
  `85baa88fdff064fcb85f7d785e74a6e7710eee39cbe83fe3005835eb27f96d72`;
- coarse score-manifest SHA-256:
  `b48769fe4a4d0b2a3847a124b2e9b1ad4c3c39e922ed30e58ec18f0733814800`;
- fine score-manifest SHA-256:
  `fd9d1b7d27649083151cd2d7746003bbb4ccdc39cedfe1f8916436228d869d2d`.

The first coarse scoring attempt failed before opening truth or BP because of
a Julia 1.12 world-age dispatch error. A prospective trusted-scorer-only
remediation was registered, source-tested, and activated. The complete coarse
population was then replayed into the valid `v2` path. Its preregistered LLR,
case-index, candidate-case, candidate-trace, and scientific-trace identities
matched the first candidate execution exactly. The scorer did not rerun the
candidate.

## Claim boundary and next decision

The result establishes that the differentiable convex parity-distance path is
viable under the fixed 30-update budget, but at a materially higher SNR than
1.5 dB. On this exposed population, the active performance target starts at
4.4 dB, the stricter 190/200 target starts at 4.5 dB, and exact recovery-count
agreement with BP starts at 4.8 dB.

It does not establish generalization to another graph, rate, block length,
channel, initialization, penalty, solver, update budget, or untouched
population. A confirmation claim requires freezing one operating point and
running a separately collision-audited population that was not used for
development.
