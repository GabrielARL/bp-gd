# Prospective constrained accelerated optimization diagnostic

Experiment ID: `RQ2-CONVEX-PARITY-DISTANCE-ACCELERATED-001`

Registration date: 8 November 2026

Status: **pruned at the synthetic source gate; no population input, candidate
outcome, scorer outcome, transmitted word, or BP output was opened, and this
card does not authorize a population run**

## Research objective branch and question

This is a solver successor to `RQ2-CONVEX-PARITY-DISTANCE-001`, created because
the global-step and local-curvature projected-gradient paths may still approach
the fixed projected-stationarity tolerance too slowly. It asks whether a
standard constrained accelerated projected-gradient schedule can reach the
same `G_288` tolerance within a practical evaluation and wall-time budget.

It is a solver/update ablation on the unchanged convex objective, not a new
objective, parity representation, or decoding mechanism. The reserved
untouched ranges `72065:72560`, all two-hop Stage-B inputs, and every existing
candidate and scorer outcome are excluded.

## Closest retained experiment and unchanged fingerprint

The closest experiment is `RQ2-CONVEX-PARITY-DISTANCE-001`. This successor
imports its source and preserves exactly:

- one scalar `b_i in [0,1]` per bit as the caller-visible state;
- positive channel LLR favoring bit zero;
- `b_i^(0)=(1-tanh(L_i/2))/2`;
- `nF(b)=L^T b+48 sum_c dist^2(S_c b,P_c)` and its partial derivatives;
- the exact degree-six parity-polytope projection and componentwise box;
- bit-one readout iff `b_i>1/2`, the `1e-12` tie rule, and independent syndrome;
- the first-valid latch and post-commit truth firewall; and
- the fixed audit mapping

  ```math
  G_{288}(b)=288[b-\Pi_{[0,1]^n}(b-\nabla(nF)(b)/288)].
  ```

Unlike the local-curvature successor, this arm changes the iteration schedule
and retains two auxiliary feasible points plus a cumulative partial-derivative
vector. It must therefore be interpreted as acceleration, not merely a scalar
step change.

## Only changed operation

Let `b_0` be the unchanged initialization and use zero-based iteration `k`.
The caller-visible output is `y_k`. The partial derivatives are evaluated at
`x_k`:

```math
\begin{aligned}
y_k &= \Pi_{[0,1]^n}(x_k-\nabla(nF)(x_k)/288),\\
p_k &= \sum_{i=0}^k \frac{i+1}{2}\nabla(nF)(x_i),\\
z_k &= \Pi_{[0,1]^n}(b_0-p_k/288),\\
x_{k+1} &= \frac{k+1}{k+3}y_k+\frac{2}{k+3}z_k,
\qquad x_0=b_0.
\end{aligned}
```

The output `y_k` and mirror point `z_k` are box projections. The next query is
a convex combination of those feasible points. Every partial derivative is
therefore evaluated inside `[0,1]^n`; the source does not extend or modify the
frozen parity projector.

The exact-arithmetic estimate-sequence guarantee is

```math
nF(y_k)-nF(b^*)\le
\frac{2\cdot288\lVert b^*-b_0\rVert_2^2}{(k+1)(k+2)}
```

for every global minimizer `b*`. Thus the objective-gap rate is `O(1/k^2)`.
The output objective need not be monotone, so objective increases are telemetry,
not stalls. External mutation of the output state fails closed because it would
invalidate the cumulative estimate sequence.

There is no restart, damping, randomization, training, learned coefficient,
BP quantity, line search, candidate-outcome selection, or visited-word
selection.

## Counterfactual prediction

On a later paired exposed-population audit, this arm is predicted to reach
`norm(G_288,Inf)<=1e-8` on more cases within 6000 partial-derivative evaluations
than both fixed-step projected gradient and the local-curvature backtracking
arm. Its median evaluation count to tolerance is predicted to be at most one
third of the fixed-step count among cases where both reach tolerance.

No recovery improvement is claimed. A changed first-valid or recovery count
would be a solver-path/readout effect; the convex landscape is identical.

## Locked future cases, stopping, and work

No case is authorized by this source card. If separately approved, the only
eligible development population is the same exposed 1.5-dB population as the
predecessor, frames `61969:62168`, all 200 cases with no selection. Predecessor
outcomes remain unavailable to the candidate process, and truth may open only
after candidate commit.

The first eligible readout remains after update one. Latch the first tie-free
parity-valid hard-decision estimate, then continue optimization. Freeze later
execution checkpoints before opening a case. Stop only at a checkpoint with
`norm(G_288(y_k),Inf)<=1e-8`, or at the frozen evaluation cap. A cap terminal is
`optimization_unresolved`.

Each update uses one full `O(E)` objective/partial-derivative evaluation, two
componentwise box projections, and one convex-combination pass. Core memory is
`O(E+n)` including the graph, initial point, query, output, mirror point, and
cumulative partial-derivative vector.

## Correctness and identity gates

- Import the predecessor module; do not reimplement its objective, projector,
  initialization, fixed mapping, or readout.
- Reproduce every synthetic accelerated trajectory with an independent
  allocating reference implementation.
- Verify every query, output, and mirror point remains in the box.
- Verify iteration zero exactly uses the predecessor's fixed projected-gradient
  step from the unchanged initialization.
- Verify checkpoint mapping and readout equality with the predecessor.
- Fail on external output-state mutation and verify deterministic replay.
- Benchmark only a deterministic synthetic regular degree-(3,6) graph before
  any execution approval.
- Any future runner must verify primary/replay equality and maintain the
  candidate/truth firewall through candidate commit.

## Synthetic source-gate outcome

The independent allocating-reference, box-feasibility, unchanged-checkpoint,
unchanged-readout, mutation, replay, and production-size synthetic tests pass
`44,031/44,031` assertions.

On the deterministic synthetic degree-(3,6) graph with `n=10,200` and
`m=5,100`, the frozen audit mapping after 6,000 updates was
`1.8247365563830442e-3`, compared with `2.5395255668438921e-2` for 6,000
fixed updates. One measured single-thread pass took `4.691248038` seconds for
the accelerated arm and `3.823325294` seconds for the fixed arm; an accelerated
replay took `4.773688879` seconds and reproduced the output, query, and mirror
hashes exactly.

The acceleration is material but remains more than five orders of magnitude
above the locked `1e-8` stationarity tolerance at the proposed 6,000-evaluation
cap. The practical-stationarity source gate therefore fails. The
counterfactual prediction above remains recorded, but it is not eligible for a
population test under this card. No decoding-performance inference follows
from this synthetic diagnostic.

## Metrics and decisions

Primary later metrics are cases reaching `norm(G_288,Inf)<=1e-8`, full
partial-derivative evaluations to tolerance, and one-thread wall time. Secondary
metrics are first-valid update, parity validity, post-commit transmitted-word
recovery, coded-bit errors, integrality, local parity distance, and objective.

Continue only if more cases reach tolerance than the fixed arm at the same
evaluation cap, the median paired evaluation ratio is at most `1/3`, and replay
and feasible-query gates all pass. Otherwise prune this accelerated schedule.
No result changes the interpretation of the objective itself.
