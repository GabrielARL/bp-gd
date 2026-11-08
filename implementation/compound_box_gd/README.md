# Compound-box projected GD

This package is a portable one-arm extraction of the retained
`compound__box` projected-gradient construction. It is a reproduction of the
verified baseline, not a newly named decoder.

The public `decode(check_vars, llr)` entry point needs only Tanner-check
indices and channel LLRs. The production code therefore has no JadeJcade
runtime dependency. It retains one scalar per bit and constructs one
check-specific offset per Tanner-graph edge after accepted update 1. Those
offsets remain frozen through updates 2--90.

Run the self-contained validation with:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. \
  -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The fixture was generated from retained fresh 6 dB frame 50025. Tests require
exact scalar-state, offset-state, hard-decision, accepted-objective, step, and
trial identities at updates 1, 30, and 90. For backward compatibility,
`snapshot.objective` remains an alias for that historical accepted-objective
value. Each snapshot also records `stored_state_objective`, recomputed from its
stored scalar and offset states. The two objective fields intentionally differ
at update 1 because the offsets are constructed after the scalar step is
accepted; they agree at updates 30 and 90, where the offsets are already
frozen. Tests recompute the stored-state objective and also
check finite differences, strict objective decrease, the scalar box, offset
mean constraints, and frozen-offset identity. The harness sets BLAS to one
thread and requires one Julia thread because the frozen objective hashes bind
the floating-point reduction order.

Maintainers can repeat the live oracle comparison with
`test/generate_frozen_oracle_fixture.jl`. That script requires the historical
frozen source capsule and its pinned JadeJcade project; the normal package and
tests do not.

The retained performance evidence in `evidence/` reports 177/200 transmitted
words recovered at update 30 and 200/200 at update 90 on the registered fresh
6 dB cases. This is not a cross-SNR near-BP result.
