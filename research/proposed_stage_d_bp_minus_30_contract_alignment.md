# Proposed Stage-D BP-minus-30 contract alignment

Decision ID:

`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-D-BP-MINUS-30-CONTRACT-ALIGNMENT-001`

Status: proposed, unapproved, and inert.

## Why this decision is needed

The active terminal target passes a signal-to-noise level when the frozen
candidate's transmitted-word recovery count `C_s` satisfies
`C_s >= B_s - 30`, where `B_s` is the native exact sum-product BP count on the
same 200 registered cases. The checked-in two-hop Stage-D card and
configuration still carry the older proximity gates:

- candidate recovery at least 190/200;
- candidate deficit from exact sum-product at most 10/200; and
- candidate-minus-exact-sum-product paired 95% interval lower endpoint at
  least -0.05.

Those are not equivalent to the active BP-minus-30 target. No Stage-D case has
opened, so this can be reconciled prospectively without using a Stage-D
outcome.

The current predecessor files are:

- `experiments/rq2_two_hop_positive_metric_001/experiment_card.md`, SHA-256
  `098066f28cadb2486dc4d3d9bea0690e321fddfa81d49dbe2c4c161a81062ab3`;
- `experiments/rq2_two_hop_positive_metric_001/config.toml`, SHA-256
  `8d05373c5907c2e6a37171caaf666954a9bc8ecd2ae82ca4ff4c985d636969b3`.

## Proposed decision

Approval means that, before any Stage-D input can open, the current two-hop
Stage-D card and configuration may be changed only as follows:

1. Replace the absolute 190/200 minimum and the at-most-10 deficit with the
   single per-level count rule `C_s >= B_s - 30`. Candidate recovery above BP
   is allowed and is not penalized.
2. Retain the paired candidate-versus-BP four-count table and 95% Newcombe
   method-10 interval as a reported diagnostic, but remove its -0.05 lower-
   endpoint threshold from the pass/fail decision. Otherwise that threshold
   would silently restore a stronger proximity requirement than BP minus 30.
3. Retain the registered exact-zero lower endpoint as a causal control. The
   candidate must still recover more transmitted words than that lower
   endpoint, and the paired 95% candidate-minus-lower-endpoint interval must
   still have lower endpoint at least zero.
4. Retain unchanged the 200 cases per level, reserved frame ranges, 30 attempted
   updates, no-BP-at-inference rule, bounded-degree `O(E)` work requirement,
   deterministic replay, and every wrong-valid-word, exact-zero-readout,
   nonfinite, box, accepted-step decrease, input-identity, inference-isolation,
   checkpoint, and manifest gate.
5. Retain the rule that a Stage-D failure permits no retuning on the transfer
   cases.

The resulting change aligns the current two-hop transfer with the active
terminal goal while preserving the independent baseline, correctness,
isolation, replay, and work-budget safeguards.

## Permissions withheld

This decision does not approve Stage-B or Stage-C execution, open a Stage-D
case, alter the matrix, objective function, partial derivatives, coefficients,
update rule, step rule, frames, or work budget, authorize BP at inference, or
make a performance claim. Stage D remains conditional on complete-valid
Stage-B and Stage-C passes plus its own later exact execution authorization.
