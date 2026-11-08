# Prospective convex parity-distance diagnostic

Experiment ID: `RQ2-CONVEX-PARITY-DISTANCE-001`

Registration date: 8 November 2026

Status: **registered for the user-requested exposed-population diagnostic; no
case outcome had been opened when this card was frozen**

## Research objective branch

This is an exposed-population mechanism diagnostic. It tests whether removing
the nonglobal local wells of the product-and-binary-attraction objective is
enough to obtain useful decoding at 1.5 dB. Relative to `J_C`, it changes the
objective and coordinate system. Relative to retained parity-polytope work,
the objective family is not new: the changed operation is the solver update.
It is not a continuation of `J_C`, a BP approximation, or a confirmatory
performance experiment.

The population is the already exposed 1.5 dB transfer population from
`RQ2-COMMON-COORDINATE-BUDGET-90-001`: frames `61969:62168`, all 200 cases,
with no case selection. The reserved untouched confirmation ranges and the
complete two-hop Stage-B chain are excluded and must remain unchanged.

The exact Budget-90 outer freeze-manifest digest used by this card is
`2b7451931df7bf9d3c53ebf6d0f6351ef470211ed8c8255eb0e94e5f3e25f444`.
The sealed input table digest is
`22baeb48556df1eebd36f1b4ea33e0cd213b0bfa192eebcc9e361e4defca4c19`,
and its input-manifest digest is
`ba4d1c833c5bfc586b5ea250858d4c56b0685d9a87e7cd76e1b134e9ca4ef709`.
The completed 1.5 dB Budget-90 result-manifest digest is
`6125385b0ab981b602f7849b827186aa119850ca8db19f30f08dd9541fdc5c68`.

For efficient candidate execution, the runner may read the already exported
read-only LLR and adjacency caches only after rechecking them against every
sealed per-frame LLR hash and the frozen graph identity. Their frozen file
digests are:

| Read-only cache | SHA-256 |
|---|---|
| 400-column Float64 LLR cache (use columns 201:400 only) | `1ca690bf3f4ed7ae2f92a21ceb68abdabad2144c7101ea0388fec4d5b33d4116` |
| 6-by-5100 Int32 adjacency cache | `18b46e41ee01464498085aeebf98a1ae489058739255a5d4994cd93e4d89246c` |
| cache index | `03c4f58ff1cff8bef91634a6dad4bb4717d858365ff2e919b07d9c8bd5e2b16f` |

These caches are transport only, not scientific authority. Any mismatch with
the sealed Budget-90 identities invalidates the run.

## One question

On those 200 exposed cases, does ordinary projected gradient descent on a
smooth convex signal-plus-exact-parity-polytope-distance objective reach a
tie-free parity-valid hard-decision estimate, and when it reaches numerical
projected stationarity, what prevents a correct hard decision: residual local
parity infeasibility, a fractional point in the fundamental polytope, or a
binary parity-valid competitor?

## Classification and closest retained experiment

Classification: **exposed-population solver/update ablation on a retained
convex objective family, and a coordinate/objective transfer relative to
`J_C`**. The recovery counts are descriptive only.

The closest retained fixed-parameter experiment is
`R5-PROJECTED-PARITY-AWGN-AUDIT-001`. That 24-frame 1.5 dB audit used one
scalar in `[0,1]` per bit, a linear signal term, and squared positive odd-set
violations, but its iteration applied a shifted sigmoid after the gradient
step. It therefore was not ordinary projected gradient descent on the convex
cost whose partial derivatives it computed. It reported 0/24 exact recoveries
under its frozen 40-update rule.

`R5-TRAINED-RESTARTED-PG-AWGN-001` is a stronger retained solver variant on
the same squared odd-set objective family. It used trained per-update
coefficients, the shifted sigmoid, 100 updates, and ten random starts, and
reported 0/200 parity-valid and 0/200 transmitted-word recoveries at 1.5 dB.
Those trained/restarted/sigmoid operations are not reopened here.

For a degree-six local state `u in [0,1]^6`, at most one forbidden odd-set
inequality is positive. If its positive violation is `v`, then

```math
\operatorname{dist}^2(u,P_c)=\frac{v^2}{6}.
```

Consequently, one-half squared odd-set violation with coefficient `beta` is
the same local penalty as one-half squared parity-polytope distance with
`lambda=6 beta`, subject to matching the signal normalization. The historical
fixed `beta=4` corresponds to `lambda=24`; this card's independently fixed
`lambda=96` corresponds to `beta=16`. The objective is therefore not claimed
as a new mechanism.

This experiment is not a repetition because its only iteration is the exact
box-projected negative gradient of the declared convex function. Its partial
derivative is evaluated through the exact Euclidean projection, and there is
no shifted sigmoid, temperature, training, random restart, visited-word
selection, binary-attraction term, multiplier, recurrence, BP quantity, or
learned/state-dependent matrix.

The closest retained `J_C` control is the native compound arm in
`RQ2-COMMON-COORDINATE-BUDGET-90-001`. Relative to it, this diagnostic changes
both the coordinate system and objective, specifically replacing the
nonconvex product penalty and binary attraction with convex parity-polytope
distance.

Exact constrained LP decoding is a separate retained boundary, not this
finite differentiable penalty: its first locked 1.5 dB case had a fractional
global optimum. That result makes a fractional terminal a prospective
mechanism rather than a post-outcome explanation.

## State, sign convention, and initialization

The graph is the retained regular `(3,6)` LDPC Tanner graph with `n=10200`,
`m=5100`, graph seed `169616412`, variable degree three, and check degree six.
A positive channel LLR `L_i` favors bit zero.

The persistent optimization state is one scalar `b_i in [0,1]` per bit. The
frozen initialization is the exact coordinate transform of the retained
native initialization:

```math
b_i^{(0)}=\frac{1-\tanh(L_i/2)}{2}.
```

The hard-decision estimate is bit one iff `b_i>1/2`. Freeze `1e-12` as the
readout-tie tolerance: `abs(b_i-1/2)<=1e-12` is a tie. A readout containing a
tie cannot be latched as a valid decode. Parity validity is an independently
recomputed zero binary syndrome.

## Objective and partial derivatives

For check `c`, let `S_c b` select its six incident coordinates and let
`P_c` be the convex hull of its 32 even-parity binary patterns. Freeze

```math
F(b)=\frac{1}{n}\left[
L^{\mathsf T}b+
\frac{\lambda}{2}\sum_c
\operatorname{dist}^2(S_cb,P_c)\right],
\qquad \lambda=96.
```

The implementation evaluates the equivalent unnormalized function `nF` to
avoid small arithmetic scales. Its partial derivatives are

```math
\nabla(nF)(b)=L+\lambda\sum_c S_c^{\mathsf T}
\left(S_cb-\Pi_{P_c}(S_cb)\right).
```

The value `lambda=96` is fixed before any case opens. It is not selected from
case outcomes: at an odd degree-six hard pattern the Euclidean projection
residual has magnitude `1/6` in each coordinate, so `lambda/6=16` matches the
LLR-equivalent per-coordinate pull of the retained `J_C` parity term with
`w_p=2`; the local penalty value `lambda/12=8` also matches the retained
violated-check value `4w_p=8` before the common `1/n` normalization.

For inputs already in `[0,1]^6`, the local projector uses the exact
cut-search characterization of the even-parity polytope followed by the
one-dimensional box-constrained half-space projection. It must reject an
out-of-box input rather than silently changing the mathematical problem.

## Frozen update, work, and stopping rule

Because the gradient of one-half squared distance to a closed convex set is
one-Lipschitz and `sum_c S_c^T S_c=3I`, the partial derivatives of the penalty
have Lipschitz constant at most `3lambda=288`. The only update is

```math
b^{(t+1)}=\Pi_{[0,1]^n}\left(
b^{(t)}-\frac{1}{288}\nabla(nF)(b^{(t)})\right).
```

There is no line search, momentum, restart, continuation, perturbation,
sigmoid, adaptive scaling, or parameter sweep. Record update zero, but the
first eligible decoder readout is after update one. Latch the first tie-free
parity-valid hard-decision estimate for decoder scoring, then continue the
same optimization for the landscape audit.

Freeze checkpoints at updates `30`, `90`, `300`, `1000`, `3000`, and `6000`.
Stop the audit at
the first checkpoint state satisfying

```math
\left\|G(b)\right\|_\infty\le 10^{-8},\qquad
G(b)=288\left[b-\Pi_{[0,1]^n}
\left(b-\nabla(nF)(b)/288\right)\right],
```

or at the 6000-update cap. A cap terminal is `optimization_unresolved`; it is
not called a minimizer or evidence against the objective. Reaching the finite
tolerance is `numerical_global_optimum` because the objective and box are
convex, while retaining the explicit finite-tolerance qualification.

Each degree-six projection has fixed `O(6 log 6)` work. One full update is
therefore `O(E)` and the algorithm-core memory is `O(E+n)` including the
graph. Runtime, allocations, and diagnostic serialization are reported
separately.

## Candidate-only record and post-run scorer

The candidate pass may receive only the frozen graph, the sealed clipped
channel-LLR vector, the frame key, and the constants above. It must not receive
the transmitted word, coded-bit error count, BP state or output, a retained
recovery label, or another decoder's direction.

For every checkpoint and terminal, record before scoring:

- state, hard-decision, trace, and input hashes;
- objective, signal term, and parity-distance term;
- projected-gradient mapping infinity norm;
- syndrome weight and exact tie count;
- sum and maximum of local squared distances;
- number of checks with nonzero local distance under the frozen numerical
  threshold;
- number of coordinates strictly inside `(0,1)` and number within the frozen
  readout-tie tolerance;
- first tie-free parity-valid update, if any; and
- updates, projection calls, edge visits, elapsed time, and allocation
  telemetry.

Freeze `1e-10` as the local-distance zero tolerance: a check is counted as
locally infeasible when its Euclidean distance exceeds `1e-10`. Freeze `1e-8`
as the integrality tolerance: a coordinate is classified as fractional when
it lies strictly between `1e-8` and `1-1e-8`. Exact values and counts are
retained as well, so these thresholds do not replace the numerical record.

Only after the candidate table is complete may the scorer compare the latched
and terminal hard decisions with the transmitted word and add coded-bit
errors, transmitted-word recovery, and wrong-valid-codeword indicators. No BP
execution is authorized or needed.

## Correctness, identity, and replay gates

Before opening frame 61969, all of the following must pass:

1. every even degree-six binary vertex is fixed by the projector;
2. every odd vertex, random convex combination, and random box point passes
   all box and odd-subset inequalities after projection;
3. idempotence, permutation equivariance (including ties), and the Euclidean
   projection variational inequality hold on deterministic fixtures;
4. analytic partial derivatives match central finite differences;
5. convexity, the registered Lipschitz bound, and fixed-step objective
   nonincrease pass deterministic synthetic tests;
6. the graph has the frozen `(3,6)` degrees;
7. every generated case matches the sealed source input-identity row,
   including graph, noise, received-sample, raw-LLR, clipped-LLR, and initial-
   state hashes; and
8. a primary and replay pass produce identical deterministic scientific
   traces. Timing, allocation, and peak-memory telemetry are measured
   separately and are not replay-equality fields.

An identity, projection, derivative, convexity, degree, denominator, or replay
failure invalidates the run. There is no automatic repair or retuning under
this experiment ID.

## Frozen counterfactual prediction and interpretation

The discriminating prediction is frozen before cases open:

- If the removed `J_C` product wells and the historical shifted-sigmoid update
  are the dominant limitations, at least one of the 200 cases will produce a
  transmitted-word-equal, tie-free, parity-valid hard-decision estimate by
  update 6000.
- If the result remains 0/200 and every case reaches the mapping tolerance,
  then nonglobal local wells are not needed to explain failure of this frozen
  convex relaxation; classify the numerical global optima rather than calling
  them trapped local minima.
- If any case reaches the update cap above tolerance, that case is
  optimization-unresolved and cannot support a conclusion about the global
  minimizer.

For a tolerance-qualified terminal, use this frozen classification:

1. maximum check distance above `1e-10`: finite quadratic-penalty limitation;
2. maximum check distance at most `1e-10` with at least one coordinate farther
   than `1e-8` from both box endpoints: fundamental-polytope
   fractional solution (pseudocodeword) limitation;
3. all coordinates within `1e-8` of a box endpoint and a parity-valid wrong
   hard decision: the linear signal cost selected another
   codeword; or
4. transmitted-word-equal hard decision: recovery.

The primary reported counts are transmitted-word recoveries out of all 200 at
updates 30, 90, 300, 1000, 3000, and 6000 (including any earlier latched
recovery), plus the number of tolerance-qualified and
optimization-unresolved terminals.
Parity-valid counts, wrong valid words, coded-bit errors, ties, fractional
coordinates, syndrome weights, distance statistics, work, and timing are
secondary mechanism fields.

## Claim boundary

A positive result establishes only the observed count for this frozen convex
objective, penalty, initialization, step, readout, stopping rule, graph, and
exposed 1.5 dB population. A 0/200 result closes only that same protocol. It
does not close other penalty weights, exact constrained optimization, other
initializations or steps, lifted formulations with persistent check-local
replicas and multipliers, state-dependent matrices, another objective, or any
general class of gradient-based decoder.

Convexity removes nonglobal local minima; it does not guarantee that the
global minimizer is integral, parity-feasible at finite penalty, or the
transmitted word.
