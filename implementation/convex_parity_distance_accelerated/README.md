# Constrained accelerated successor source

This prospective package imports the frozen `ConvexParityDistance` objective,
projector, initialization, stationarity mapping, and readout. It implements
the standard constrained estimate-sequence accelerated projected-gradient
method with global curvature `288`.

For zero-based iteration `k`, it evaluates the partial derivatives at a
feasible query `x_k`, forms the ordinary projected-gradient point `y_k`, and
updates a feasible mirror point `z_k`:

```math
\begin{aligned}
y_k &= \Pi_{[0,1]^n}(x_k-\nabla(nF)(x_k)/288),\\
p_k &= \sum_{i=0}^k \frac{i+1}{2}\nabla(nF)(x_i),\\
z_k &= \Pi_{[0,1]^n}(b_0-p_k/288),\\
x_{k+1} &= \frac{k+1}{k+3}y_k+\frac{2}{k+3}z_k.
\end{aligned}
```

Both `y_k` and `z_k` are box projections, and `x_{k+1}` is their convex
combination. Every objective and partial-derivative evaluation is therefore at
a point in the frozen box; no out-of-box extension of the parity projector is
needed. The caller-visible state and decoder readout use `y_k`.

For any global minimizer `b*`, the exact-arithmetic estimate-sequence bound is

```math
nF(y_k)-nF(b^*) \le
\frac{2\cdot288\lVert b^*-b_0\rVert_2^2}{(k+1)(k+2)}.
```

This is an `O(1/k^2)` objective-gap guarantee on the unchanged convex
problem. It does not imply a correct binary hard-decision estimate; it only
accelerates optimization of the same landscape.

The package contains no population loader, frame selector, transmitted word,
BP quantity, result reader, scorer, or launcher. Run its synthetic suite with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Run the production-size synthetic timing harness with:

```sh
julia --project=. benchmark_synthetic.jl 6000
```

The registered prospective card records the source-gate outcome. On the
deterministic production-size synthetic graph, 6,000 accelerated updates gave
`G_288 = 1.8247365563830442e-3`; this is faster progress than the fixed schedule
but does not meet the locked `1e-8` stationarity tolerance. The successor is
therefore not authorized for a population run by that card.
