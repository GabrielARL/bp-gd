---
name: bp-gd-mechanism-study
description: Design, run, and interpret controlled BP-versus-gradient-decoder experiments in this repository. Use for decoder changes, causal comparisons, parameter studies, performance claims, or deciding whether a branch is genuinely new. Preserve the verified compound-box baseline, the pruned-branch ledger, and the distinction between a direction fit and a decoder result. Do not use for presentation-only edits.
---

# BP–GD mechanism study

The research objective has two connected parts:

1. causally explain why native exact sum-product BP and native projected GD
   have different decoding performance; and
2. develop and causally validate a gradient-based decoder that approaches BP
   under declared cases, stopping rules, and work budgets.

The first part is not answered by a native scoreboard because the methods
differ in state, parity calculation, update operator, projection, schedule,
and stopping rule. The second part is not answered by fitting a direction on
retained states. It requires an executable decoder and independent recovery
and coded-bit-error measurements.

## Current evidence boundary

Treat the following as retained findings, not hypotheses to rerun under a new
name:

- Tanner-graph traversal and an `O(E)` edge count do not explain the gap.
- Retaining check-specific information and using it in the parity calculation
  changed recovery at 6 dB, but did not establish BP equivalence.
- With the recurrence held fixed, direct unit application of the recurrence
  recovered words where every tested true-gradient arm failed. Direct map
  application is not a gradient step.
- Fixed-objective, fixed-matrix, one-hop, and the sealed 25-parameter
  graph-factorized families were pruned within their registered scopes.
- `compound__box` is the best performance-verified GD construction: 177/200
  at 30 updates and 200/200 at 90 updates on the registered fresh 6-dB cases.
  This is not a cross-SNR near-BP result.
- The state-dependent recipient-excluded two-hop positive-matrix family has a
  retained teacher-labelled fit only. It has no fresh direction-screen,
  decoder, recovery, or BER result.

Read `explainers/the_path_so_far_tree.html` before designing new work. A new
experiment must descend from the active leaf or state exactly which pruned
assumption it changes. If its fingerprint matches a retained branch, it is a
reproduction or parameter study, not a new mechanism.

## Fingerprint every decoder

Record:

- state and dimension;
- vector of channel LLRs and sign convention;
- objective or fixed-point map;
- parity representation and check-local calculation;
- persistent quantities and discarded temporary quantities;
- global update operator, preconditioner or metric, projection, and line
  search;
- initialization, schedule, stopping rule, hard-decision rule, and validity
  test; and
- operation, runtime, and stored-state budgets.

For BP, separately name variable-to-check and check-to-variable messages and
recipient exclusion. For a gradient decoder, name the partial derivatives of
the declared objective function, the matrix or preconditioner applied to them,
the step rule, and the projection. Do not infer information loss merely from
summation or cancellation; require a controlled retained-state variant.

## Use one prospective question per experiment

Use this card before launching:

```text
experiment ID:
research objective branch:
question:
classification: reproduction, transfer, parameter study, or ablation
closest retained experiment and why this is not a duplicate:
state and coordinate system:
objective or fixed-point map:
only changed operation:
counterfactual prediction:
locked cases and stopping rule:
work budget:
correctness and identity gates:
primary recovery metric:
secondary validity and coded-bit-error metrics:
prune, continue, and failure rules:
```

Freeze the card and code before opening held-out outcomes. Retain failed
anchors. Do not retune a failed family under the same experiment identifier.

## Required gates

- Check analytic partial derivatives by finite differences.
- Verify projection, box, and positive-definiteness invariants independently.
- Bind every metric to the state from which it was calculated.
- Verify primary/replay equality for scientific output.
- Distinguish parity validity from transmitted-word recovery.
- Compare raw iteration counts only after declaring method-specific work.
- Report the denominator, signal-to-noise ratio, case set, and work limit with
  every performance count.

The selected `compound__box` implementation is the baseline for future GD
work in this repository. Any replacement must first reproduce its registered
checkpoint identities or state explicitly why it changes the mechanism.

Scope conclusions to the tested graph, observations, parameters, budgets, and
metric denominator. A direction fit, animation, or local mathematical
existence result is not decoder-performance evidence.
