# Local-curvature successor source

This directory is a prospective, synthetic-only solver successor for
`RQ2-CONVEX-PARITY-DISTANCE-001`. It imports the frozen
`ConvexParityDistance` module and therefore does not reimplement or alter the
objective, parity-polytope projector, initialization, box, stationarity
mapping, or readout.

The only changed operation is the scalar step rule. A deterministic local
secant curvature seeds projected-gradient backtracking. A trial with
`d = clamp(b - grad/L, 0, 1) - b` is accepted only when

```math
nF(b+d) \le nF(b)+\nabla(nF)(b)^\mathsf T d+
\frac{L}{2}\lVert d\rVert_2^2.
```

The search begins at `L=1` on the first update. Later updates use the clipped
secant estimate

```math
L_{BB}=\frac{(b_t-b_{t-1})^\mathsf T(g_t-g_{t-1})}
{\lVert b_t-b_{t-1}\rVert_2^2},
```

when it is positive and finite. Otherwise it starts at half the last accepted
curvature. Seeds are clipped to `[1,288]`; rejected trials double `L` and the
last possible trial uses the proven global curvature `288`. There are at most
ten trial objective/partial-derivative evaluations per accepted update. The
first call adds one current-state evaluation; later calls reuse the cached
accepted endpoint.

In exact arithmetic the projection optimality condition and the accepted
majorization inequality give

```math
nF(b_{t+1}) \le nF(b_t)-\frac{L_t}{2}
\lVert b_{t+1}-b_t\rVert_2^2.
```

The accepted step sizes stay in `[1/288,1]`. Standard projected-gradient
convergence therefore drives the projected-gradient mapping to zero, and every
limit point is a global minimizer because the objective and box are convex.
The implementation reports its small Float64 majorization allowance.

There is no population loader, frame selector, transmitted word, BP quantity,
scorer, or result reader in this package. The test and benchmark sources build
only deterministic synthetic regular degree-(3,6) graphs.

Run the synthetic tests from this directory with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Run the production-size synthetic timing harness with:

```sh
julia --project=. benchmark_synthetic.jl
```
