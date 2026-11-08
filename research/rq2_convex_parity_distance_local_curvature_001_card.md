# Prospective local-curvature step diagnostic

Experiment ID: `RQ2-CONVEX-PARITY-DISTANCE-LOCAL-CURVATURE-001`

Registration date: 8 November 2026

Status: **prospective source and synthetic tests only; no population input,
candidate outcome, scorer outcome, transmitted word, or BP output may be
opened under this card without a separate execution approval**

## Research objective branch

This is a solver-step successor to `RQ2-CONVEX-PARITY-DISTANCE-001`. It asks
whether the conservative global step `1/288`, rather than the unchanged convex
objective, is responsible for slow convergence to projected stationarity.
It is a parameter/solver study, not a new parity representation, objective, or
decoding mechanism.

The reserved untouched confirmation ranges `72065:72560`, every two-hop
Stage-B input, and all candidate and scorer outcomes from the predecessor are
excluded. The source created under this card has no population, frame, truth,
BP, result-reader, scorer, or launcher interface.

## Question

Can deterministic local-curvature projected-gradient backtracking reach the
same fixed-`1/288` projected-stationarity criterion in materially fewer
accepted updates and full objective evaluations than the fixed-step solver?

## Classification and closest retained experiment

Classification: **prospective solver-step parameter study on an unchanged
convex objective**.

The closest experiment is `RQ2-CONVEX-PARITY-DISTANCE-001`. The state,
coordinate transform, vector of channel LLRs, sign convention, initialization,
objective, parity-polytope projector, box, hard-decision estimate, tie rule,
syndrome test, first-valid latch, truth firewall, and fixed stationarity
mapping are identical. The only changed operation is the scalar step rule.

This is not evidence for a better objective. If the predecessor's global
minimizer is fractional, parity-infeasible at finite penalty, or gives a wrong
hard-decision estimate, faster optimization of the same function cannot by
itself repair that mechanism.

## Unchanged fingerprint

- State: one scalar `b_i in [0,1]` per bit.
- Positive channel LLR: favors bit zero.
- Initialization:

  ```math
  b_i^{(0)}=\frac{1-\tanh(L_i/2)}{2}.
  ```

- Objective, evaluated as `nF`:

  ```math
  nF(b)=L^{\mathsf T}b+
  \frac{96}{2}\sum_c\operatorname{dist}^2(S_cb,P_c).
  ```

- Partial derivatives:

  ```math
  g(b)=L+96\sum_cS_c^{\mathsf T}
  \left(S_cb-\Pi_{P_c}(S_cb)\right).
  ```

- Hard-decision estimate: bit one iff `b_i>1/2`; values within `1e-12` of
  `1/2` are ties and cannot be latched.
- Validity: independently recomputed zero binary syndrome with no ties.
- Fixed audit mapping:

  ```math
  G_{288}(b)=288\left[b-\Pi_{[0,1]^n}(b-g(b)/288)\right].
  ```

## Only changed operation

Let `L_t` denote a scalar curvature, not a channel LLR. On the first update,
freeze the seed `L_seed=1`. After an accepted displacement
`s=b_t-b_{t-1}` with gradient difference `y=g_t-g_{t-1}`, use

```math
L_{BB}=\frac{s^{\mathsf T}y}{s^{\mathsf T}s}
```

when both denominator and numerator are positive and the quotient is finite.
Clip it to `[1,288]`. If that quotient is unavailable, seed with the last
accepted curvature divided by two, again clipped to `[1,288]`.

For a trial curvature `L`, form

```math
z(L)=\Pi_{[0,1]^n}(b-g(b)/L),\qquad d(L)=z(L)-b.
```

Accept the first trial satisfying

```math
nF(z(L))\le nF(b)+g(b)^{\mathsf T}d(L)+
\frac{L}{2}\lVert d(L)\rVert_2^2.
```

Rejected trials double `L`, capped at `288`. The frozen candidates are
`L_seed, 2L_seed, 4L_seed, ...`, with `288` inserted as the final cap; at most
ten trials are possible because the smallest seed is one. The implementation
also requires the accepted endpoint not to exceed the current objective beyond
a reported `256 eps(Float64)` scale allowance. There is no momentum,
extrapolation, restart, perturbation, randomization, nonmonotone window,
training, or parameter sweep.

The global partial-derivative Lipschitz bound remains `288`, so the final trial
is guaranteed in exact arithmetic. Projection optimality gives

```math
g(b)^{\mathsf T}d(L)+L\lVert d(L)\rVert_2^2\le0.
```

Together with the acceptance inequality,

```math
nF(b+d)\le nF(b)-\frac{L}{2}\lVert d\rVert_2^2.
```

Accepted step sizes lie in `[1/288,1]`. Consequently, exact-arithmetic
projected-gradient iterates have vanishing stationarity residuals, and every
limit point is a global minimizer of the unchanged convex objective over the
unchanged box. The secant estimate affects only the first tested curvature;
it cannot bypass the majorization gate.

## Counterfactual prediction

If conservative global curvature is the main cause of slow convergence, then
local curvature will reduce accepted updates to the fixed mapping tolerance by
at least a factor of three on the eventual paired exposed-population audit,
and the median total count of full objective/partial-derivative evaluations
will be no more than half the predecessor's fixed-step update count. The
terminal mechanism classification and transmitted-word recovery count are not
predicted to improve materially because the objective is unchanged.

Failure of the speed gates prunes this successor as an engineering change. A
different recovery count would be reported as a path/readout effect of the
step rule, not evidence that the convex landscape changed.

## Locked future cases and stopping rule

No case is authorized by this source card. If separately approved, the only
eligible development population is the same exposed 1.5-dB population used by
the predecessor: frames `61969:62168`, all 200 cases, no selection. Its
candidate packet and truth firewall must be regenerated from the predecessor's
sealed source identities; predecessor outcome files may not enter the
candidate process.

The first eligible readout remains after update one. Latch the first tie-free
parity-valid hard-decision estimate, but continue the landscape audit. Freeze
checkpoints only in a later execution card after synthetic timing. Stop only
at a checkpoint where `norm(G_288(b),Inf)<=1e-8`, or at a separately frozen
work cap. A cap terminal remains `optimization_unresolved`.

## Work budget

One current-state evaluation is cached from the previously accepted endpoint.
Each trial is one full `O(E)` objective/partial-derivative evaluation. An
accepted update therefore uses one trial evaluation when its seed succeeds and
at most ten. State, previous-state, previous-gradient, trial, and three solver
workspaces require `O(E+n)` memory including the graph. Candidate timing,
allocation, trial counts, objective evaluations, projection calls, and edge
visits must be reported separately from scoring.

## Correctness and identity gates

- Import the predecessor module rather than reimplementing its objective,
  projector, initialization, mapping, or readout.
- Verify exact objective, partial-derivative, initialization, mapping, and
  readout agreement with the predecessor on synthetic states.
- Independently reproduce the accepted trial from its recorded seed,
  backtracks, and majorization inequality.
- Check the projection optimality inequality and monotone endpoint on every
  synthetic accepted step.
- Include deterministic replay and cache-invalidation tests.
- Benchmark only a deterministic synthetic regular degree-(3,6) graph before
  any execution card.
- Any future scientific runner must verify primary/replay equality and retain
  truth and BP exclusion through candidate commit.

## Metrics and decision rules

Primary speed metrics for a later paired audit:

1. accepted updates to `norm(G_288,Inf)<=1e-8`;
2. total full objective/partial-derivative evaluations to that point; and
3. elapsed one-thread candidate time.

Secondary metrics are first-valid update, parity validity, transmitted-word
recovery after candidate commit, coded-bit errors, terminal integrality, local
parity distance, and terminal objective. Every count must state the 1.5-dB
level, 200-case denominator, and work cap.

Continue only if the median accepted-update ratio is at most `1/3`, the median
full-evaluation ratio is at most `1/2`, no case loses deterministic replay, and
the fixed mapping is evaluated from the checkpoint state. Otherwise prune the
adaptive step. No outcome can establish a new objective mechanism because the
objective is held fixed.
