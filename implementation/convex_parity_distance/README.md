# Convex parity-distance candidate source

This directory contains candidate-only source for the differentiable convex
objective

\[
\widetilde F(b)
=L^{\mathsf T}b
+\frac{96}{2}\sum_c
\operatorname{dist}^2(S_cb,\mathcal P_c),
\qquad b\in[0,1]^n,
\]

where \(\mathcal P_c\) is the convex hull of the even-parity binary patterns
at degree-six check \(c\). The normalized value used in the accompanying
paper is \(F=\widetilde F/n\); scaling the objective does not change its
minimizers.

The source retains one scalar \(b_i\) per bit. It calculates the partial
derivatives of the objective, applies the fixed step \(1/288\), and projects
componentwise onto \([0,1]^n\). Positive channel LLR favours bit zero. The
initial state is

\[
b_i^{(0)}=\frac{1-\tanh(L_i/2)}{2}.
\]

Every local input to the parity-polytope projector is therefore already in
\([0,1]^6\). The projector uses a stable sort and an exact piecewise-linear
cut search over at most six breakpoints. Each complete objective and partial-
derivative calculation takes \(O(E)\) work on the frozen degree-(3,6) graph.

`SolverWorkspace`, `evaluate!`, and `step!` provide the iteration path. The
default `step!` call evaluates the current state once, constructs the trial in
preallocated storage, and updates the caller's state in place. Calculating the
next-state objective, copying the partial derivatives, and hashing states are
available separately through `audited_step!`. The allocating `objective_gradient` and
`projected_gradient_step` wrappers are retained for inspection and tests.
`checkpoint_evaluate!` recomputes the objective, parity-distance statistics,
partial derivatives, and projected-gradient mapping norm from one unchanged
checkpoint state. It does not apply an update. Stationarity, distance, and
integrality decisions remain with a prospective runner, while the source also
reports the frozen telemetry count of checks whose Euclidean distance exceeds
\(10^{-10}\).
`readout!` reuses hard-decision and syndrome buffers owned by the solver
workspace. It returns only syndrome weight, tie count, and tie-free parity
validity; a caller copies the buffered hard-decision estimate only when it
needs to retain a latch or checkpoint.

The constant 96 is frozen rather than tuned. At an odd hard pattern of a
degree-six check, Euclidean projection moves all six entries by magnitude
\(1/6\). The resulting parity contribution has value \(96/12=8\), and each
partial derivative has magnitude \(96/6=16\). These match the value and
bit-coordinate force of the retained product penalty at \(w_p=2\), before the
common division by block length.

This module has no frame loader, population selector, transmitted word,
comparison receiver, scorer, or result writer. Its tests are synthetic. A
convex objective has no nonglobal local minimum, but its global minimizer can
still be fractional or slightly outside the local parity polytopes at finite
penalty weight. Consequently this source is not a decoder-performance result.

The registered exposed-population workflow is under `execution/` and uses
three separate Julia processes:

1. `prepare_candidate_packet.jl` runs on the trusted side. It verifies all
   eight sealed Budget-90 identities with `regenerate_case!`, independently
   verifies the cache and graph identities, and writes a packet containing
   only the graph, 200 clipped-LLR vectors, frame keys, and allowed hashes. Its
   complete eight-field receipt is written to a separate, non-nested root.
2. `candidate_runner.jl` accepts only that truth-stripped packet. It runs the
   primary and deterministic replay passes, retains checkpoint states and
   hard decisions, keeps telemetry outside the scientific replay digest, and
   writes `CANDIDATE_COMMITTED.txt` last.
3. `score_candidate.jl` first verifies the candidate commit and manifests,
   then opens the separate trusted receipt and registered all-zero word. It
   writes scored artifacts to another new root and never runs BP.

The production commands require fresh output directories:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. execution/prepare_candidate_packet.jl \
  --packet-root /absolute/path/candidate_packet \
  --receipt-root /absolute/path/trusted_receipt

JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. execution/candidate_runner.jl \
  --packet-root /absolute/path/candidate_packet \
  --output-root /absolute/path/candidate_result

JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. execution/score_candidate.jl \
  --packet-root /absolute/path/candidate_packet \
  --receipt-root /absolute/path/trusted_receipt \
  --candidate-root /absolute/path/candidate_result \
  --score-root /absolute/path/scored_result
```

Run the synthetic suite with:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. \
  -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```
