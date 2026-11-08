# Compound-box projected-gradient reproduction card

- Experiment ID: `COMPOUND-BOX-GD-EXTRACT-001`
- Research-objective branch: preserve the best performance-verified gradient
  construction as a portable baseline.
- Question: does the extracted one-arm implementation reproduce the frozen
  `compound__box` arm on a pinned retained 6 dB case?
- Classification: implementation reproduction, not a new decoder or a new
  performance experiment.
- Closest retained experiment: `RQ2-GD-RESIDUAL-PROJECTION-BUDGET-001`, arm
  `compound__box`.
- State: one scalar `x_i` for every coded bit plus one check-specific offset
  for every Tanner-graph edge. The offsets are constructed after accepted
  update 1 and frozen thereafter.
- Objective: channel term plus the compound squared parity residual and binary
  term, with parity weight 2.0 and binary weight 0.2.
- Update: diagonal-preconditioned negative partial derivative, initial step
  0.2, at most 16 halvings, first strict decrease, then projection to
  `[-1,1]`.
- Locked case: retained fresh 6 dB frame 50025, graph seed 169616412, noise
  seed `20261012 + 50025`.
- Work budget: 90 update attempts; no syndrome early stop.
- Correctness gates: exact state, offset, hard-word, accepted-step, historical
  accepted-objective, and checkpoint-hash agreement at updates 1, 30, and 90;
  objective recomputation from each stored scalar/offset state, including the
  intentional update-1 distinction after offset construction; independent
  finite differences; strict decrease; box feasibility; and frozen-offset
  identity.
- Performance claim: none is generated here. The retained evidence remains
  177/200 recoveries at update 30 and 200/200 at update 90 on the registered
  fresh 6 dB cases. This is not a cross-SNR near-BP result.
