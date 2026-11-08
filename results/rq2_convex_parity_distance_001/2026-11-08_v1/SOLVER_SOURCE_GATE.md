# Convex parity-distance successor source gate

Parent experiment: `RQ2-CONVEX-PARITY-DISTANCE-001`

Date: 8 November 2026

Status: **source and deterministic synthetic diagnostics only; no second
population execution was opened**

## Purpose

The registered fixed-step population run ended above its projected-
stationarity tolerance on all 200 cases.  Before spending another population
run, two deterministic successors and a standard bound-constrained optimizer
were screened on a production-size synthetic degree-(3,6) graph.  Every arm
kept the parent objective, initialization, box, exact local parity-polytope
projection, and fixed audit mapping

```math
G_{288}(b)=288\left[b-\Pi_{[0,1]^n}
\left(b-\nabla(nF)(b)/288\right)\right].
```

The synthetic graph had `n=10,200` variables and `m=5,100` checks.  It is not
one of the 1.5-dB frames and contains no transmitted word, BP output, parent
candidate outcome, or scorer outcome.  These measurements therefore test
solver feasibility only; they are not decoder-performance evidence.

## Implemented successors

- `RQ2-CONVEX-PARITY-DISTANCE-LOCAL-CURVATURE-001`: projected gradient with a
  clipped Barzilai--Borwein curvature seed and monotone majorization
  backtracking.  Its independent source tests passed `15,233/15,233`
  assertions.
- `RQ2-CONVEX-PARITY-DISTANCE-ACCELERATED-001`: a feasible-point Nesterov
  estimate-sequence schedule whose query, output, and mirror points remain in
  the box.  Its independent source tests passed `44,031/44,031` assertions,
  including exact deterministic replay.

Both implementations import the parent's objective and projector rather than
reimplementing either scientific operation.

## Production-size synthetic outcome

| Solver diagnostic | Work | Final `norm(G_288, Inf)` | Interpretation |
|---|---:|---:|---|
| Fixed projected gradient | 6,000 updates | `2.5395256e-2` | parent reference |
| Local-curvature projected gradient | 6,000 accepted updates | `2.390e-3` | faster, still unresolved |
| Accelerated feasible-point schedule | 6,000 updates | `1.8247366e-3` | faster, still unresolved |
| Accelerated then local-curvature | 6,000 + 30,000 accepted updates; 73,511 local-curvature evaluations | `2.3504324e-4` | still unresolved |
| Optim.jl 2.3.2 direct `LBFGSB`, memory 10 | 5,000 iterations; 5,013 combined evaluations | `5.4017116e-5` | strongest initial library screen, still unresolved |
| Optim.jl 2.3.2 direct `LBFGSB`, memory 10 | 6,000 iterations; 6,017 combined evaluations | `4.2139088e-5` | independent extension and exact replay, still unresolved |

The direct `LBFGSB` extension used the same objective, partial derivatives,
initialization, and componentwise bounds.  It stopped at its iteration cap,
not a convergence condition.  The replay reproduced the final mapping and
state checksum.  A secondary `Fminbox(LBFGS)` control consumed 22,220 combined
evaluations and ended at `8.75898e-4`; its objective-based convergence flag
did not satisfy the fixed gradient-mapping gate.

Wall times are machine- and implementation-dependent.  Representative
single-thread measurements were about 4.7 seconds for the 6,000-update
accelerated source test, 12.0 seconds for 6,000 local-curvature updates,
58.7 seconds for the 30,000-update local-curvature continuation, and 21--23
seconds for the replayed 6,000-iteration direct `LBFGSB` control.  They are
engineering telemetry, not part of deterministic scientific equality.

## Decision and claim boundary

Every tested successor improved the synthetic residual, but none reached the
locked `1e-8` mapping tolerance.  The proposed second 200-frame population run
was therefore pruned at its source gate.  Opening it would repeat the parent's
central ambiguity: a zero-recovery count at a cap while continuous
optimization remains unresolved.

This gate does **not** establish that the convex objective has an unsuitable
global minimizer, that exact parity-polytope constraints fail, or that no
convergent optimizer can reach stationarity.  The only registered 1.5-dB
decoder statement remains the parent result: the frozen fixed-step method
recovered `0/200` through 6,000 updates and left all `200/200` cases
optimization-unresolved.

## Source identities

- Local-curvature card SHA-256:
  `07ea8f11ea25ce418f8e819445bdc961c3053b8c1b1b4ce94c33b8af859330ca`
- Local-curvature source SHA-256:
  `f88f58da2890ff6f2bb07d0d0a3b97413cbcffb17421dcfdc0276ba4ecdd5a79`
- Local-curvature test SHA-256:
  `b5adab2b076d2bf073bc2bb782c3f87c7ad1b469f27eefe2e9204f3fcb462b41`
- Accelerated card SHA-256:
  `f5273ff0b2ac2a522b0cadc3141c44eac03fd4e06c232bafbcd5f82e138b8869`
- Accelerated source SHA-256:
  `3eb0f8b85ba12a418fda9484cd658c43748a5bfc1db1dc92f9cc58b6f1edb5fc`
- Accelerated test SHA-256:
  `96c710cc9d0021ee438c8d9e3baa516896b0be1854abf90c16399072fbfa4bbc`
- Accelerated environment manifest SHA-256:
  `5c953ebbc9e7db043bdca7218035092a4920268676e93700c8b35c370da1d200`

The reserved untouched ranges `72065:72560` and the two-hop Stage-B chain were
not opened or modified by these diagnostics.
