# Active BP–GD goal and next registered gate

## Goal

Develop and validate a genuine gradient-based decoder that approaches the
exact sum-product BP reference on declared cases, stopping rules, and work
budgets. Preserve failed branches as closed evidence so a later experiment
does not repeat them under another name.

The current terminal target is a one-sided recovery-count margin on two
untouched 200-case levels. At each level, the frozen candidate and native
exact sum-product BP process the same registered cases; for each paired case,
the parity-check matrix, transmitted word, noise realization, and vector of
channel LLRs are held fixed. For each level `s`, let `C_s` be the candidate's
transmitted-word recoveries after at most 30 attempted updates and let `B_s`
be BP's transmitted-word recoveries at its first zero syndrome or 80
message-passing iterations. Both levels pass only if `C_s >= B_s - 30`;
candidate recovery above BP is not penalized. The candidate
may use `J_C`, locally calculated partial derivatives of an explicitly frozen
objective function, and the frozen simple state-dependent positive-definite
matrix when selected, but it may not call BP at inference. Wrong valid
codewords, exact-zero readout ties, nondeterministic replay, or work beyond the
registered bounded-degree `O(E)` envelope fail the candidate independently of
the recovery count. Development and solver selection must use exposed or
separately registered development cases; frames `72161:72360` at 6 dB and
`72361:72560` at 1.5 dB remain reserved for one frozen confirmation candidate.

The checked-in Stage-D experiment card and configuration still retain the
older, stricter count gates of at least 190/200 recoveries and a deficit of at
most 10, together with paired-interval and lower-endpoint gates. No transfer
case has opened, and those registered fields have not been changed. On
7 November 2026, the user approved the prospective reconciliation
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-D-BP-MINUS-30-CONTRACT-ALIGNMENT-001`.
Its application is deliberately deferred until Stage B and Stage C are both
complete-valid, immediately before Stage-D freeze and execution authorization,
because the current card and configuration are hash-bound members of the
upstream Stage-B campaign. The later amendment will use at most 30 attempted
candidate updates and compare `C_s` with native exact sum-product `B_s` at its
first zero syndrome or 80 message-passing iterations. The paired candidate-
versus-BP interval will remain a reported diagnostic rather than a pass gate;
the registered exact-zero lower-endpoint comparison and every correctness,
isolation, replay, identity, and work-budget safeguard remain pass gates. This
approval authorizes no current source mutation, stage, scientific execution,
or input access.

The retained fresh-transfer baseline is the assigned/frozen compound-box
projected-gradient construction. It recovered 177/200 transmitted words after
30 updates and 200/200 after 90 updates on the registered fresh 6-dB cases.
That result is not evidence of comparable performance at 1.5 dB or across
signal-to-noise ratios.

## Exposed 1.5-dB convex parity-distance diagnostic

`RQ2-CONVEX-PARITY-DISTANCE-001` changed both the coordinate system and the
objective relative to `J_C`. It retained one scalar `b_i in [0,1]` per bit,
used the frozen finite penalty `lambda = 96`, calculated each parity
contribution through exact Euclidean projection onto the degree-six parity
polytope, applied the fixed step `1/288`, and projected componentwise onto the
box. Its frozen source defines no sigmoid, restart, momentum, multiplier, or
state-dependent matrix, and its candidate packet contains no BP quantity.

On all 200 already exposed 1.5-dB frames `61969:62168`, the method recovered
0/200 transmitted words at updates 30, 90, 300, 1000, 3000, and 6000. No
parity-valid hard-decision estimate occurred at any update. No stored candidate
state, including every checkpoint and terminal, had a readout tie. Every case
reached the 6000-update cap with projected-gradient
mapping norm above `1e-8`, so all 200 terminals are
`optimization_unresolved`. At the cap, the mapping-norm median was
`2.2772885202382298e-4` (range `2.4881e-5` to `0.0115097`); the hard-decision
estimate had a median 382 coded-bit errors (range 148 to 595) and median
syndrome weight 387 (range 224 to 508). The soft state had a median 3274
fractional coordinates and median maximum local check distance `0.102299`.

Primary and replay scientific traces agree at SHA-256
`2020306bb9d09d20e025528c2b9eba8a398f67e8c896b7329c8b3411c1c1dd20`.
The nearly flat objective values do not change the stopping classification:
because no case reached the frozen mapping tolerance, this result identifies
neither a numerical global minimizer nor the finite penalty's eventual
recovery ceiling. The source-only follow-up below tested faster same-objective
convergence without clearing its population-launch gate. This diagnostic
leaves the two-hop Stage-B chain and reserved untouched ranges `72161:72560`
unchanged.

### Source-only convergence follow-up

Production-size synthetic gates for solver successors on the same frozen
objective did not reach `norm(G_288, Inf) <= 1e-8`, so no second 1.5-dB
population run was launched. The feasible accelerated arm ended after 6000
updates at `norm(G_288, Inf) = 1.8247366e-3`; its synthetic suite passed
44,031/44,031 assertions. A hybrid of those 6000 accelerated updates and
30,000 monotone local-curvature updates ended at
`norm(G_288, Inf) = 2.3504324e-4` after 73,511 evaluations and 43,510
backtracks. Optim.jl 2.3.2 `LBFGSB`, capped at 5000 iterations, ended at
`norm(G_288, Inf) = 5.4017116e-5` for `m = 10` and `6.3955257e-5` for `m =
50`. The local-curvature suite passed 15,233/15,233 assertions.

These are synthetic source-feasibility diagnostics, not 1.5-dB population
evidence and not evidence that the objective fails. A decisive global-minimum
audit now requires a materially stronger certified optimizer, or a relaxed
tolerance paired with an explicit error bound. The active two-hop branch is
untouched.

## Exposed SNR threshold for the differentiable convex-parity path

`RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001` answered the distinct fixed-work
question left open by the unresolved 1.5-dB convergence diagnostic: at what
SNR does the frozen convex parity-distance objective with the feasible
accelerated projected-gradient schedule produce a parity-valid transmitted-
word readout within exactly 30 updates?

The coarse development sweep used all 24 frames `20001:20024` at each 0.5-dB
level from 1.5 through 12.0 dB. The candidate recovered 0/24 at every level
from 1.5 through 3.5 dB, 11/24 at 4.0 dB, and 24/24 at every level from 4.5
through 12.0 dB. Native exact sum-product BP recovered 24/24 at every coarse
level. The first provisional coarse crossing was 4.5 dB.

The prospectively activated fine sweep then used all 200 frames
`30001:30200` at each 0.1-dB level from 4.0 through 5.0 dB. Native exact
sum-product BP recovered 200/200 throughout. Candidate recoveries were:

| Es/N0 (dB) | 4.0 | 4.1 | 4.2 | 4.3 | 4.4 | 4.5 | 4.6 | 4.7 | 4.8 | 4.9 | 5.0 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Candidate / 200 | 87 | 122 | 150 | 161 | **177** | **190** | 195 | 199 | **200** | 200 | 200 |

The stable exposed-development threshold under the active
`C_s >= B_s - 30` rule is therefore **4.4 dB**. The first level meeting the
stricter 190/200 reference is **4.5 dB**, and the first level matching BP's
200/200 recovery count is **4.8 dB**. Every fine-grid level had zero wrong
parity-valid words and zero readout ties across the complete 30-update traces.
The candidate scientific replay was bit-for-bit deterministic, and the scorer
opened truth and BP only after candidate commit.

The terminal projected-gradient mapping norms remained above the earlier
continuous-stationarity tolerance, including at recovered levels. These are
hard-decision recovery events during a fixed differentiable optimization path,
not evidence that the continuous optimizer reached a global minimum. The hard
decision, syndrome, and first-valid latch remain evaluation operations outside
the differentiable path.

This result uses exposed development cases. It does not alter the two-hop
Stage-B chain, consume the reserved confirmation frames `72161:72560`, or
establish an untouched threshold. Its durable result is
[`RESULT.md`](../results/rq2_convex_parity_distance_snr_threshold_001/2026-11-08_v2/RESULT.md).

## Closed assumptions that must not be reopened without a new operation

- Tanner-graph traversal or an `O(E)` edge count alone explains the BP–GD gap.
- Removing the within-bit equality constraint to create generic independently
  persistent edge copies, without changing how recipient-specific values are
  calculated or consumed, is sufficient to reproduce BP's advantage.
- More updates rescue the tested 1.5-dB native compound or
  recurrence-residual projected-gradient constructions.
- Direct application of the exact sum-product recurrence is a gradient step.
- The registered `H`, plug-in Bethe, or `J_C` objective with the fixed
  diagonal matrix supplies the successful direction.
- The exact recurrence is the gradient of one smooth scalar objective in the
  retained coordinates under the fixed matrix.
- The registered fixed one-hop positive-definite matrix is sufficient.
- The sealed 25-parameter graph-factorized scalar-energy family passes its
  independent low-SNR direction gates.
- Offset-induced projection bounds, rather than use of the retained offsets in
  the parity calculation, explain the registered 6-dB offset-state gain.
- Permuting the constructed offsets among a bit's incident checks preserves the
  recovery benefit of their registered check assignment.
- Replacing correctly assigned offsets after every accepted update improves
  the registered fresh 6-dB recovery count relative to freezing the first
  adopted offsets.

The bounded, state-dependent, recipient-excluded two-hop symmetric
positive-definite matrix remains active because it places the already tested
two-hop graph support in the matrix applied to the partial derivatives of the
unchanged objective function `J_C`, rather than in a scalar-energy correction
under the fixed matrix. The 25-parameter scalar-energy family failed its
independent 1.5-dB direction gates; the retained matrix fit is not a decoder
result.

## Escape-mechanism anti-duplication boundary

Do not repeat noisy hard-bit gradient-descent bit flipping under a new label:
`R5-NGDBF-AWGN-001` produced 0/24 transmitted-word recoveries and 0/24
parity-valid readouts at 1.5 dB. Do not repeat generic random multistart
projected gradient: `R5-TRAINED-RESTARTED-PG-AWGN-001` used ten starts with up
to 100 attempted updates per start, exhausted all 1,000 attempted updates per
word, and likewise produced 0/24 transmitted-word recoveries and 0/24
parity-valid readouts at 1.5 dB. Those exact mechanism fingerprints are closed;
a materially different proposal must identify the mechanism it changes.

Inference Adam, momentum, heavy-ball, Nesterov, and the dormant strict-descent
L-BFGS source have no retained current-question performance result. They alter
the local trajectory, but do not by themselves supply a nonlocal displacement
when the registered projected-gradient mapping is exactly zero and auxiliary
velocity or moment state is initialized at zero. A radius-constrained local
model likewise does not by itself certify passage across a barrier. These
methods are not eligible merely because they are unrun.

The conditional nonduplicate escape experiment is narrower. First certify on
development evidence in the quotient represented by the mean coordinates
`u = Cz`. Because `J_C(z) = J(Cz)`, the objective is constant along the
within-bit zero-mean directions in `ker C`; a positive boundary cannot enclose
one full edge-coordinate representative. Define a feasible wrong-readout
region `W` in `u`-space containing the stalled point `u_*`, establish
`min_{u in boundary(W)} J(u) > J(u_*)`, and separately prove that every
registered finite projected trial remains in the lifted region or fails its
acceptance rule. The last check is necessary because a discrete endpoint can
jump over an internal barrier. Only if these claims pass may one deterministic
perturbation of the continuous state be applied at a preregistered stall,
followed by the unchanged frozen two-hop descent rule. Without that
certificate, do not spend cases on uphill acceptance: in the retained
exact-recurrence proxy, all 196 successful cases reached their first
zero-syndrome readout before any positive `J_C` endpoint change, and 96/196
had no positive endpoint change in all 30 updates.

The detailed design is preserved in
[`proposed_jc_mean_coordinate_barrier_card.md`](proposed_jc_mean_coordinate_barrier_card.md).
It is explicitly proposed, unapproved, and inert. It registers no ID or range,
opens no input, and contains no escape update; any one-shot perturbation would
require a separate approved successor and new untouched cases.

## Prospective experiment card

experiment ID: `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B`

research objective branch: active two-hop matrix leaf after the fixed one-hop
matrix and graph-factorized scalar-energy families were pruned

question: does the registered V5 matrix rotate the negative partial derivatives
of `J_C` sufficiently toward the exact sum-product displacement on untouched
states at both registered signal-to-noise ratios?

classification: independent direction screen; not a decoder or performance
experiment

closest retained experiments and why this is not a duplicate:
`RQ2-ACTIVE-METRIC-FEASIBILITY-001` established only teacher-dependent
pointwise existence of some positive-definite transformation;
`RQ2-GRAPH-LOCAL-METRIC-001` selected identity scaling; and
`RQ2-GRAPH-FACTORIZED-ENERGY-001-STAGE-B` placed recipient-excluded two-hop
support in a scalar objective but failed its 1.5-dB gates.
`RQ2-BP-MAP-INTEGRABILITY-001` and
`RQ2-COMMON-COORDINATE-STATE-UPDATE-001` remain closed because this card
neither represents the exact recurrence as one scalar gradient nor calls it
at inference. This card instead screens one registered concrete matrix applied to
the partial derivatives of unchanged `J_C`; exact sum-product is restricted
to the offline direction evaluator.

Recipient-specific directed-edge state is not the new operation.
`BPGD-RQ2-QBAR-AWGN-001` tested recipient-specific variable-to-check messages
under exact sum-product; `RQ1-GD-STATE-USE-001` and
`RQ2-GD-STATE-USE-001` tested constructed check-specific values or offsets,
including their joint use in a shifted parity objective and induced
projection interval; and `RQ2-BOUNDED-EDGE-FREEDOM-001` rejected equality
release by itself. This card changes only the matrix that consumes the partial
derivatives of unchanged `J_C`; it does not call exact sum-product at
inference, add those offsets, shift the objective, or change projection
bounds.

The historical offset-use question is closed. The authorized implementation
successor `RQ2-OPTIMIZE-001` completed
`RQ2-GD-OFFSET-SPLIT-001` validly on held-out 6-dB frames 30001--30200. Using
the retained offsets in the parity calculation with the native projection
interval recovered 163/200 transmitted words, versus 107/200 when the parity
calculation did not use them: paired risk difference 0.28, simultaneous
99.375% Newcombe interval [0.189917, 0.364620]. Changing only the projection
interval recovered 106/200 versus 107/200, and adding that interval when the
parity calculation already used the offsets left the count at 163/200. Thus,
on this registered sample, the recovery change came through the parity
calculation; the offset-induced projection interval added no observed
recovery. The result uses the preregistered polynomial extension when shifted
readings leave the box. It does not establish that the offsets are BP
messages, reproduce BP, or explain the full native BP--GD gap. The complete
result's science SHA-256 is
`a42793a4e94485e3f91873c1bb1cdce943879447a982555275ccf13483445125`.

The registered successor `RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001` also completed
validly. On prospective 6-dB frames 40001--40200, the as-constructed check
assignment recovered 174/200 transmitted words when the first adopted offsets
were frozen and 165/200 when they were replaced after every accepted update;
the corresponding fixed within-bit derangement recovered 61/200 and 70/200.
The assignment effects were therefore +0.565 under freezing and +0.475 under
replacement. Replacement under the as-constructed assignment changed the
count by -0.045, with simultaneous 99.375% interval
[-0.096658, 0.000092]; the preregistered equivalence-within-0.05 criterion did
not pass. Correct check assignment is the transferred mechanism in this
factorial; repeated replacement did not improve that arm on this sample and
must not be called equivalent to freezing. The descriptive assignment-by-
replacement interaction was -0.09, so later statements must retain their
path and order. The transfer science SHA-256 is
`2556c01f170d0e3f42bdcca831df47278270ec13628e84a1541a7976668c5595`.
Later registered bridge experiments completed the remaining historical
operation splits; no unrun bridge remains attached to this factorial.

Those terminal results prevent these exact offset-use and assignment-by-
replacement factorials from being rerun unchanged under a new label. They do
not rule out a prospectively registered new operation or condition. They also
do not duplicate the active matrix screen: this card adds no constructed
offsets, does not shift the parity calculation or projection interval, and
changes only the matrix applied to the partial derivatives of unchanged `J_C`.

state and coordinate system: one bounded optimization variable for each
directed variable-to-check edge slot in `[-1,1]^E`; these variables are not
variable-to-check messages in the sum-product algorithm. They are initialized
from the clipped vector of channel LLRs and read out by the centered
incident-edge mean

objective or fixed-point map: unchanged compound objective `J_C`; the exact
sum-product recurrence is restricted to the offline direction evaluator and
is forbidden from candidate inference

only changed operation: replace the fixed diagonal matrix applied to the
partial derivatives of `J_C` with the registered bounded, state-dependent,
recipient-excluded two-hop symmetric positive-definite matrix

counterfactual prediction: the registered matrix passes every registered
direction, descent, coverage, and condition gate at both 6 dB and 1.5 dB; if
either level fails, prune this exact matrix family without retuning it

locked cases and stopping rule: the registered 24-case 6-dB block followed by
the registered 24-case 1.5-dB block; the exact frame identities remain bound
in the upstream experiment card and activation contract. Use active origins
from update 0 through the update before the first zero syndrome, capped at
origin 29; do not advance a candidate decoder state

work budget: 24 frames per level, primary plus deterministic replay, direction
diagnostics only

correctness and identity gates: exact source and coefficient identities;
bit-exact zero-coefficient lower endpoint; independent partial-derivative and
matrix-action tests; raw, unprojected strict descent for every nonzero
candidate direction;
positive-definite condition bound at every state; exact state/teacher pairing;
primary/replay equality; and no candidate state update, projection, line
search, recovery scoring, or coded-bit BER scoring

primary metric: median angle in the registered fixed-diagonal inner product,
reported separately at 6 dB and 1.5 dB

secondary metrics: 90th-percentile angle, evaluable coverage, one-sided-zero
fraction, paired median improvement over the fixed-matrix lower endpoint,
relative direction error, strict-descent count, and condition bound

prune, continue, and failure rules: continue to a separately registered
decoder anchor only if every gate passes at both levels; a complete-valid gate
miss prunes this exact family; an identity, source, replay, nonfinite, or
runtime failure is operational and supplies no scientific conclusion

## Approval boundary

The following are separate decisions. None is implied by source preparation:

- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-001`
  — approve only the exact 13-member support-source registration used by the
  first collision audit. It does not authorize a retry or open an input.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION` — permit
  the repository/worktree collision scan and publication of its audit record;
  this opens no scientific case. This approval was consumed by the failed
  6 November 2026 scan and does not authorize a retry.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-001` —
  permit only source-level repair of the reviewed lexical/parser false
  positives, exact provenance classification of the historical artifacts,
  regression tests that retain true-overlap detection, component RSS
  telemetry, and bounded streaming parsing for `.json` files under the existing
  2-GiB cap. Large structural `.txt` and suffixless documents remain isolated
  in helpers and component-gated. It does not authorize another scan, fresh
  input, or scientific execution. This source-only remediation was approved
  and completed on 6 November 2026.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-002`
  — approved materialization of the exact remediated 13-member support-source
  closure. Its registration identity is
  `7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66`
  and its registration record raw SHA-256 is
  `d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2`.
  It authorizes no scan, fresh input, scientific execution, or performance
  claim.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002` — only
  after closure-002 is frozen, permission for one second audit at unused
  output and progress paths. The user approved this scope on 7 November 2026.
  The exact artifact was materialized at SHA-256
  `64f5ce0aa896cff5570e88ad1f89204bdb22dd9c54112c4d2bc35a8dad7caa20`
  and the one-use scan began. It was intentionally interrupted with exit code
  130 before result publication after review found that its bound filenames
  could not satisfy the registered three-file capsule bundle. The progress
  artifact SHA-256 is
  `25f5cc5f8c696ca478f7aaf70d65a87656e3f2a6a424da2ca0e77da080defd08`.
  No scientific input opened, but the approval is consumed and cannot be
  reused.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002-PATH-CORRECTION-RETRY-001`
  — approved permission for exactly one corrected v11 scan with unchanged
  scanner, operational source, support closure, and frame interval, but with
  its external activation and output bound from the start to the registered
  three-file capsule names `activation.toml` and `range_audit.toml`. It was
  materialized and consumed exactly once. Activation SHA-256 is
  `5a43ca345bd0e1083e9f35faf822377a4207b5b2f4e033b1bf5f480d1abcdc31`,
  progress SHA-256 is
  `415bfd91bfe4e812b3fe467eff8cc34375327552b8642fb0b7c0418cef756a94`,
  and terminal result SHA-256 is
  `10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`.
  The result failed on exactly one documentary self-collision and a recorded
  coordinator field of 6,140,592 KiB versus the 2,097,152-KiB cap. Every
  source, support, inventory, snapshot, and dormant-Stage-C gate passed with
  zero scan failures. Fresh-child reproduction later proved that the
  coordinator field inherited a pre-existing process-lifetime peak across
  `execve`; it is not evidence that the scanner allocated 5.86 GiB. The
  registered failure remains failed. No scientific input opened, no manifest
  was created, and the one-use retry cannot be reused.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-002`
  — approved and source-only complete on 7 November 2026. The repair moves
  formal traversal behind an explicit true `fork()` and pinned `execve()`,
  stabilizes the worker peak after result serialization, and requires the final
  `wait4()`-checked process-tree peak to equal
  `max(worker self, worker waited child)` before publication. Version-3 helpers
  apply the same self-versus-waited-child maximum. Ordinary
  subprocess/`vfork` and exec-only paths do not qualify. The exact
  review card is
  [`proposed_stage_b_range_audit_remediation_002.md`](proposed_stage_b_range_audit_remediation_002.md).
  The generator is pinned at
  `a3e40cc9d31f5853894a5cfff218bf70ab8f20fbccceb0f6565614ff477fa9e0`;
  its 79/79 synthetic tests and 13/13 source checks pass. The canonical
  no-result rehearsal receipt is pinned at
  `e2f33286897e7d56c07401274f2c19b865670e8c59c27dd235faa017dc0f494c`.
  With the launcher's inherited 6,140,592-KiB peak retained only as a
  diagnostic, worker self and `wait4()` both measured 210,828 KiB against the
  unchanged 2,097,152-KiB cap; waited-child and helper peaks were zero, and
  elapsed time was 6,923 ms against 1,800,000 ms. All four embedded inventory
  identities were reproduced. Formal activation, live-provider traversal, and
  formal-result publication all remained false. All checks and `fsync`
  operations precede the prospective publisher's exclusive-link commit; no
  post-link crash-durability acknowledgement is claimed. This is not a formal
  scan or scientific result. Activation-002 and closure-002 are consumed and
  cannot be reused.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SOURCE-REBIND-001`
  — approved by the user on 7 November 2026 against proposal SHA-256
  `d7ed4fca70dc07fb86882abbc4b76e448bb371755de78cc797848813f58347ff`
  and preapproval-audit SHA-256
  `d2ed8d63af9e85cf8c9708e79c98b3756b570207ca079f55710cdf9cfec7c4e0`.
  It authorizes only the declared source rebind, its 14-file touch set, and
  synthetic or temporary-directory validation. That source implementation is
  now validated: range preparation passes 13/13 checks and 87/87 tests;
  capsule infrastructure passes 78/78 tests. Scanner SHA-256 is
  `085a1052e396de1992291b6272c6ff89ec3f6e7cc40ec70eb26372aa28bb9611`;
  the prospective 13-member support-source identity is
  `1e9febb4faeabea8eeedad969cb12a00ae5fd44c2ae6285c6e8d8afd1112931b`;
  and the 26-member operational-source identity is
  `fc67b0cea40010c46b0211ebc9a963f81c445fc410ef79c225d521f27362813e`.
  It authorizes no formal scan, governed inventory, input access, or science.
  Its source-only packet replaces the
  consumed activation and support-closure bindings, makes the v12 producer
  and capsule consumers agree, and closes the reviewed launch-safety gaps.
  After descriptor-safe activation validation, one read-only worktree-root
  discovery identifies every forbidden root. The scanner then creates and
  fsyncs the exact activated progress entry before reading the live support
  closure, source, refs, repository/archive documents, or Git blobs. Scanner
  code never removes that entry. While it remains, the same exact approved
  activation cannot be reused; this is not a claim that deleting the marker
  globally consumes the activation ID. The activation is read through a
  retained parent descriptor, and the closed progress bytes are preserved as
  separate immutable capsule evidence without changing the three-file range
  bundle. The packet also reserves a canonical closure-003 path and retains
  helper self, waited-child, and parent-`wait4` values for independent memory
  checks. It separately proposed reserving closure-003 and activation-003 as
  future names. Those reservations did not approve either artifact, open an
  input, invoke a scanner, or publish a result. The separately approved
  external-candidate semantics and rendered candidate are recorded below.
  The later exact closure-003 finalization is recorded below. Activation-003
  remains absent and `launch_ready = false`.
  The inert packet SHA-256 is
  `d7ed4fca70dc07fb86882abbc4b76e448bb371755de78cc797848813f58347ff` at
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-range-audit-v12-source-rebind-20261107-v1/PROPOSAL.md`.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-003-ID-RESERVATION-001`
  — approved by the user on 7 November 2026. It reserves the future
  closure-003 ID for source binding only. It does not approve closure bytes,
  an approved status or date, or canonical materialization.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-003-ID-RESERVATION-001`
  — approved by the user on 7 November 2026. It reserves the future
  activation-003 ID for source binding only. It does not approve an activation
  artifact, invoke the scanner, or make the route launch-ready.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-003-CANDIDATE-SEMANTICS-001`
  — approved by the user on 7 November 2026. It permits the external inert
  candidate to contain the future canonical `status = "approved"` and
  `approved_date = "2026-11-07"` fields while remaining non-authoritative by
  location and governance. The rendered 13-member candidate is
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-range-audit-v12-source-rebind-20261107-v1/SUPPORT_SOURCE_CLOSURE_003.candidate.toml`,
  with raw SHA-256
  `d498512bfc9b69b71446a5927b65598e864621760349ccb636d5d8f30e9f786b`
  and registration identity
  `1e9febb4faeabea8eeedad969cb12a00ae5fd44c2ae6285c6e8d8afd1112931b`.
  That decision alone did not authorize canonical materialization. The later
  exact closure-003 approval below materialized a byte-identical canonical
  copy. The external candidate remains non-authoritative at its external
  location.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-003`
  — approved by the user and finalized on 7 November 2026 against the exact
  byte-bound request at
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-range-audit-v12-source-rebind-20261107-v1/CLOSURE_003_APPROVAL_REQUEST.md`,
  with SHA-256
  `53fdac843309b8bc28de8479757a7306e6ed74801ac93f7bef336061c538609d`.
  The reviewed candidate's 4194 bytes were placed byte for byte at
  `experiments/rq2_two_hop_positive_metric_001/followup/stage_b_support_source_registration_2026-11-07_v3.toml`.
  Canonical raw SHA-256 is
  `d498512bfc9b69b71446a5927b65598e864621760349ccb636d5d8f30e9f786b`,
  and registration identity is
  `1e9febb4faeabea8eeedad969cb12a00ae5fd44c2ae6285c6e8d8afd1112931b`.
  The builder, independent auditor, and static validator now bind that exact
  raw hash and identity; their postfinalization SHA-256 values are
  `cf5df83550370718872239d53a118315c2aff4ce1e32a0358f6877feba992be6`,
  `6eb9ce7c219fbb0a8e334bcbc7f01b4fc7c6d7b3a6af36e53a07be620145c5ab`,
  and `30f9bb4d23ec956246509270a30d213f99b27187565b97c53a46aea5c04c162b`.
  Range validation passes 13/13 checks and 87/87 tests. Capsule validation
  passes 78/78 tests, and the builder and independent auditor both reproduce
  the closure identity. The durable finalization receipt is
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-closure-003-finalization-20261107-v1/FINALIZATION_RECEIPT.md`,
  with SHA-256
  `f51f6dfc6210546126c71cdce0370a948541cbdbe43cb9f164ff82851c68e2db`;
  its verified `MANIFEST.sha256` has SHA-256
  `45515895519365c4c3359bf221dfd6616de16e91ef48d24012064f51bf610b0a`.
  The 13 registered members remain unchanged.
  An isolated finalization rehearsal is retained at
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-closure-003-finalization-dry-run-20261107-v1/`.
  Its receipt SHA-256 is
  `85118cf96850ecac62bd3e197259308737f4641291a9b68689c290761f2c477a`,
  manifest SHA-256 is
  `ecd55fa2bf325a091c16eba1fa6fcd35db67e8069ec4378bb63cf08904f4b809`,
  and exact proposed-patch SHA-256 is
  `25398057a92711a3c44140973f05eb48f4233fc1575feb5fce574019fdbb191e`.
  In a private namespace, the simulated canonical state passed the static
  validator, both real independent closure rehashes, five fail-closed
  mutation cases, and the unchanged 78-test capsule suite. That rehearsal was
  non-authoritative and changed no host state; the later approved finalization
  produced the verified authoritative state. `closure_003_present = true`,
  activation-003 remains absent, and `launch_ready = false`. No formal scan,
  governed inventory, retained or fresh input, decoder, scientific execution,
  range-result publication, or performance claim occurred. The next separate
  approval decision is one exact byte-and-hash-bound activation-003.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-D-BP-MINUS-30-CONTRACT-ALIGNMENT-001`
  — approved by the user on 7 November 2026 against the unchanged proposal at
  SHA-256
  `5cf13f8c5aea8836b6c6888da5c6a615f05c67109d27f5187276d9135642b016`.
  Application is deliberately deferred until Stage B and Stage C are both
  complete-valid, immediately before Stage-D freeze and execution
  authorization, so the current upstream hash bindings remain intact. The
  future candidate cap is 30 attempted updates; `B_s` is native exact
  sum-product BP at its first zero syndrome or 80 message-passing iterations;
  and each level uses `C_s >= B_s - 30`. The paired BP interval is diagnostic
  only. The registered exact-zero lower-endpoint comparison and all safety,
  isolation, replay, identity, and work-budget gates remain operative. This
  approval opens no stage, scientific execution, or input.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-COEFFICIENT-SEAL-002` — permit
  materialization of the replacement coefficient seal from the already
  verified V5 retained fit. The user approved it on 7 November 2026, and the
  complete-valid replacement is materialized with authorization SHA-256
  `06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b`,
  manifest SHA-256
  `a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5`,
  and sealed-member SHA-256
  `173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078`.
  It opened no frame and produced no scientific result.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-WALL-CONTRACT-AMENDMENT-001` —
  the user approved on 7 November 2026 the prospective, fail-closed definition
  of what the retained-only
  timing process measures and which later no-data gates remain outside that
  timing envelope; this opens no retained or fresh case. The corrected static
  amendment has exact SHA-256
  `c76ba22c29bea8d0e25e31cf74057b1649347e44fc56d9f890368e9dcc372a63`
  and requires the actual complete-valid v12 range artifact to be pinned only
  after a later complete-valid audit succeeds.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RETAINED-WALL-BENCHMARK-001` —
  the user prospectively approved on 7 November 2026 one retained-only timing
  run on frames 70917--70920 and 71117--71120. The approval remains
  inoperative until the amendment and its source, range, and seal prerequisites
  pass and the exact one-use authorization can be materialized. It does not
  permit fresh input access or a scientific result.
- `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-EXECUTION-001` — after all source,
  range, wall-budget, seal, and capsule gates pass, the user prospectively
  approved on 7 November 2026 only the untouched 48-case direction screen.
  This approval remains inoperative until the exact prerequisites pass and
  its one-use authorization artifact can be materialized. It does not
  authorize a decoder anchor, transfer, coded-bit BER comparison, retuning, or
  a performance claim.

The goal is active. No retained-wall run, fresh input, or Stage-B science has
begun. Until the exact prerequisites and artifacts are
complete, the registered fresh Stage-B cases remain unopened.

## Current preparation status

Source-only validation on 6 November 2026 did not open a retained or fresh
scientific case:

- the portable compound-box baseline passed 10,258 checks, including explicit
  binding of every checkpoint objective to its stored state;
- the local two-hop matrix-action extraction and per-origin diagnostic kernel
  remain byte-identical to their registered V5/Stage-B sources; the package now
  also contains a pure production calculation from graph, state, and channel
  LLRs through unchanged `J_C`, its partial derivatives, the fixed positive
  diagonal, and the two-hop matrix to a candidate direction, without accepting
  a comparison direction or calculating exact sum-product;
- the complete local suite passed 5,636 synthetic assertions: 1,202 for the
  retained source-and-action path, 692 for a portable frozen arithmetic
  fixture, 262 for the pure population-reduction seam, 84 for the durable
  full-chain synthetic test, and 3,396 for the dormant Stage-C decoder source
  [`local_stage_c_decoder_source.jl`](../implementation/two_hop_metric_action/test/local_stage_c_decoder_source.jl);
- the new frozen 40-case fixture is generated from pinned registered
  historical `J_C` and fixed-diagonal sources, then consumed without an
  external worktree dependency. It reproduces every recorded objective field
  and fixed-diagonal entry bit for bit over one deliberately varied `n=8`,
  24-edge synthetic graph. Its coverage includes check degrees 2--6,
  nonuniform variable degrees, tied and untied incident-edge inputs, edge-state
  signed zero and box endpoints, and LLR inputs at and beyond the clipping
  boundary. This is arithmetic regression evidence, not a scientific result;
- the pure population seam validates already-materialized offline diagnostics,
  gives the retained generic summary and target-specific reducer separate
  views, and combines their decisions only after unique pairing, common
  thresholds, and equal denominators are proved. Its combined gate was
  exercised only on fabricated rows; no registered Stage-B population was
  consumed and no teacher access entered candidate inference;
- seven of the 84 full-chain assertions preserve the earlier diagnostic with
  supplied partial derivatives and a supplied diagonal. Its paired angle
  improvement remains `0.9935439809818444` degrees. The other 77 assertions
  start from a synthetic Tanner graph, bounded edge state, and LLR vector;
  calculate unchanged `J_C`, its two-hop candidate direction, and its
  exact-zero lower endpoint; then pass an already-materialized comparison
  vector only to the separate offline diagnostic before adapting and reducing
  the rows. The comparison vector is frozen from the synthetic candidate, and
  all three repeat-labelled rows share one input identity and the same
  diagnostic, so this test provides neither population diversity nor
  independent direction agreement with BP;
- on that full synthetic path, the target-specific gate passes, as does every
  generic gate except the unchanged 15-degree paired-improvement requirement.
  The measured improvement is `0.6852959854888271` degrees, so the generic and
  combined gates fail closed. No threshold changed, no registered frame was
  opened, and the test performs no state update, projection, line search, word
  readout, or recovery, BER, or FER scoring. This is source-and-interface
  evidence, not Stage-B science, decoder evidence, or decoding-performance
  evidence;
- 102 path-adapted assertions reproduce the original registered per-origin
  kernel cases, while 36 additional assertions prove that an aligned or opposed
  caller-supplied reference direction leaves both calculated directions and
  the candidate condition values and local gate unchanged. That additional coverage includes the
  same check now made explicit in the upstream 110-assertion kernel suite; the
  kernel neither calculates the exact sum-product recurrence nor advances a
  state, and its `sealed_coefficients` argument does not validate a governance
  seal;
- the compact bundle verifier passed 166 structural, identity, evidence,
  provenance, and claim-boundary checks. It covers the frozen fixture, all
  three pure population components, and their no-science boundaries in
  addition to the production objective and direction path;
- the operational-source inventory validator passed 26 files. The added member
  is the byte-identical, hash-pinned pure evaluator for unchanged `J_C` and its
  registered fixed positive diagonal;
- its five Python tests and 240 Julia assertions passed. The Julia suites are
  independently pinned at 12 coefficient-seal-loader, 34 provider, 165
  operational-runtime, and 29 retained-callback assertions, so a loss in one
  suite cannot be hidden by adding assertions to another. Eight of the provider
  assertions change only the supplied offline comparison direction and prove
  that both calculated directions, the candidate condition values, and the
  local gate remain unchanged while the comparison diagnostics change. Three
  bit-exact golden-vector assertions independently pin the retained `J_C`
  arithmetic. Seven further assertions prove that the provider calculates unchanged-`J_C`
  partial derivatives and the fixed diagonal locally, uses those local values,
  and rejects a self-consistently hashed but incorrect supplied gradient, an
  incorrect supplied diagonal, or a mismatched gradient hash before candidate
  evaluation;
- the preserved v10 range-audit producer validator passed 10/10 validation checks and its
  core suite passed 61/61 synthetic tests. Its four ordered command rows
  preserve exact canonical JSONL under closed 175-field result and 23-field v2
  activation keysets, inventory-completeness gates, and internal
  cross-consistency. Those producer checks alone cannot establish live truth
  for a fully coherent rewrite. It binds an exact 13-member support closure:
  twelve Stage-B support sources plus the hard-pinned, TOML-parsed dormant
  Stage-C boundary. The closure is approved at identity
  `c2ef2d0f77d1fc441e532c78dbf7d4917c4ef8defb948f0315b1c659a71d4403`;
  its registration record raw SHA-256 is
  `fb8bab4d00b08e88b34713c9eb77414d9cc0ef874e59b8d9712832a9db459c4e`.
  The approved first repository-wide scan produced an exact 175-field failure
  record at SHA-256
  `46d38209d89a6bd0a51f1008fa68cbde26033ecf8954f3b2750c5e5e980c510f`,
  with status `collision_or_audit_failure` and 31 collision records in six
  groups. Its frozen `scan_max_rss_kib` field is 6,437,576 KiB against the
  2,097,152-KiB cap. The scanner calculated that field by adding the
  coordinator's lifetime peak RSS to the largest lifetime peak RSS reported
  for any waited child. Those peaks need not be simultaneous, so the field is
  not a measured simultaneous process-tree peak; neither component nor
  per-helper RSS was retained. The registered cap comparison remains failed.
  The diagnosis does not authorize a retry.
  All source, support, inventory, and snapshot-stability gates passed with
  `scan_failures = []`, `fresh_inputs_opened = false`, and
  `stage_c_fresh_inputs_opened = false`. Independent review found no competing
  frame reservation or scientific frame consumption: the rows were quoted
  prior-audit evidence, synthetic parser fixtures, and current-campaign
  explainer text. That diagnosis does not waive the registered failure. The
  separately approved source-only remediation is implemented in prospective
  v11 source. Its validator passes 11/11 checks and its unit suite passes 70/70
  tests. The v11 contract closes its result to 183 fields, binds exact
  provenance for the 27 reviewed historical/test non-registration records, and
  uses bounded streaming parsing for `.json` files. It records
  coordinator and waited-child lifetime peaks separately from per-helper
  peaks; each helper peak is stabilized after parsing and response
  serialization, while the post-wait child observation is conservative through
  process exit. This does not claim simultaneous
  process-tree RSS or remeasure the preserved v10 failure. Large structural
  `.txt` and suffixless documents remain isolated in helpers and
  component-gated; they are not claimed to use the streaming parser;
- the capsule-infrastructure validator passed its 21-member inert-source
  inventory, and its suite passed 76/76 tests under its pinned Python 3.11
  interpreter. The exact downstream range bundle remains three files. Builder
  and independent auditor now perform no-follow component walks, retain
  physical root identities, reject aliases, recompute physical containment,
  rerun the live worktree, ref, filesystem, and Git-blob inventories, recompute
  hashes, object IDs, and fingerprints, compare all four regenerated canonical
  payloads byte for byte, and repeat repository-identity and post-Git-metadata
  checks. The final-source generator and independent validator share
  the current five-Python-test and per-suite 240-Julia-assertion contract. This
  both replaces the earlier stale aggregate and rejects a correctly hashed
  redistribution that leaves the aggregate unchanged. An end-to-end temporary
  run generated and independently validated the actual 26-member source closure
  with all 245 checks passing, source identity
  `401aafec73839021d3f3c9dd3708f0f88b5ca614ea045b9bc736e84f3358abb9`,
  `fresh_inputs_opened = false`, and
  `scientific_runner_started = false`; no persistent final source-validation
  bundle was published before the audit because the protocol placed that audit
  first; and
- a complete route-attempt-ledger audit confirmed that this is a
  cross-repository BP--GD mechanism study, not a new Jade/Jcade receiver
  route or a duplicate retained implementation; and
- an exhaustive decoder-fingerprint search found no previously run copy of
  the full Stage-C mechanism. The nearest update shell put two-hop support in
  a fitted scalar energy and failed its 1.5-dB direction screen before any
  decoder ran; the nearest geometry used only one-hop support and selected
  identity scaling. The new dormant source instead keeps unchanged `J_C` and
  applies the registered two-hop positive-definite matrix to its partial
  derivatives at every accepted current state. It implements initialization,
  projection, the 13-point Armijo search, the 30-attempt/stall rule, centered
  incident-edge readout, and strict-negative decisions. Its exported
  state-advancing entry points construct the direction internally and expose
  neither an arbitrary-direction step nor a BP, teacher, truth, frame, SNR,
  population, scoring, writer, or launcher interface. Its
  3,396 synthetic assertions use a separate pure checker to recalculate every
  stored objective, partial-derivative vector, current-state direction, raw
  and projected trial, Armijo decision, accepted state, readout, syndrome, and
  cross-record link. Thirty-five deliberately altered traces fail closed. The
  suite also checks an accepted second trial, bit-exact deterministic reruns
  with the synthetic graph, channel-LLR vector, coefficients, and decoder
  settings held fixed for update-cap and stalled paths, the exact 13-trial stall, complete-path bit
  identity for the zero-coefficient control, valid-codeword sign covariance,
  decoder-level enforcement of the complete condition bound, and explicit
  coefficient-admissibility rechecks that close the exported structure's raw
  constructor bypass. A synthetic
  path first becomes parity-valid at update 16 and still continues through
  update 30. The first parity-valid syndrome remains telemetry and never stops
  the decoder.
  A test-only dense path now enumerates graph incidence directly and
  reimplements the full matrix and projected Armijo loop without the production
  path pattern or sparse action; it reproduces the complete 30-update and
  late-stall candidate paths within `3e-13`. A nondegenerate six-variable
  fixture proves that the recipient-excluded action creates zero-mean
  differences among the edge values incident on a bit: unchanged `J_C` and its
  partial derivatives are unchanged when those differences are collapsed, but
  the next matrix direction changes. The zero-coefficient control stays tied.
  The same audit exposes a projection/action compatibility gap. At the retained
  synthetic candidate stall, the raw positive-definite matrix direction has
  `g' d < 0`, but componentwise projection removes the descent-producing
  boundary components and all 13 projected displacements have `g' delta > 0`.
  The registered fixed-diagonal projected-gradient mapping remains nonzero and
  produces a feasible lower-`J_C` point, so this candidate stall is not box-
  stationary. The zero-coefficient control has a zero mapping at its stall.
  No decoder rule, coefficient, or gate changed.
  This is executable source readiness, not a Stage-B pass, registered
  decoder-anchor run, recovery result, or coded-bit BER/FER evidence.
- a direct post-outcome cross-tabulation of the complete-valid objective-path
  and common-coordinate iteration tables limits the proposed ascent
  explanation. All 196 terminal-success 1.5-dB exact-recurrence-proxy frames
  reached their first centered-readout zero-syndrome state before any positive
  J_C endpoint change; 96/196 had no positive endpoint change anywhere in
  all 30 updates. The recorded 120/6000 increases therefore cannot explain
  why the proxy first reaches a valid word while strict descent fails. The
  iteration table does not retain per-update transmitted-word equality, so
  this derived diagnostic does not establish that the first valid word was
  already the transmitted word. It is not a prospectively registered decision
  and it is not native-BP evidence. Because `J_C(z) = J(Cz)` is constant on
  `ker C`, a causal claim that ascent is binding would require a feasible
  wrong-readout region `W` in the quotient represented by `u = Cz`, a certified
  gap `min_{u in boundary(W)} J(u) > J(u_*)`, an explicit check that the finite
  projected trial rule cannot jump across that barrier to an accepted lower
  endpoint, and a prospective paired intervention that changes only permission
  to accept the predetermined perturbation;
- a source-only design audit identified a nonduplicate linear-cost successor
  but did not implement, register, or run it. The proposed calculation would
  first test the projected two-hop displacement; when that displacement is not
  strict descent, it would use the already registered fixed-diagonal
  projected-gradient trial at the same step and declare stationarity only when
  the fixed-diagonal projected mapping is zero. A future experiment would have
  to record how often this fallback is used and reject a construction that
  merely degenerates into the already tested fixed-diagonal decoder. This is
  distinct from dormant `RQ2-GRADIENT-GEOMETRY-001`, which checks a raw L-BFGS
  direction before projection. The current Stage-B direction screen remains
  first; even a pass would not resolve the projection/action incompatibility
  or validate the unchanged projected update for a decoder anchor. Under the
  frozen branch policy, a pass admits the unchanged Stage-C update; the
  safeguard becomes eligible only after a Stage-C failure, unless a
  prospective amendment is approved before any Stage-C case opens;
- the dormant source now has a production-size synthetic resource measurement
  on the deterministic regular degree-(3,6) graph with 10,200 variables,
  5,100 checks, and 30,600 edge slots. Candidate and exact-zero arms each pass
  three one-thread update-cap and immediate-stall repetitions with the complete
  trace checker. Update-cap traces occupy 69,861,148 bytes, take
  5.7778--6.4499 seconds to calculate and 5.5252--5.7620 seconds to check, and
  reach measured child-process peak RSS of 894,263,296--899,579,904 bytes.
  Immediate-stall traces occupy 11,763,554 bytes. The scalar receipt opens no
  registered frame, case provider, comparison receiver, truth, or scorer and
  is not the separately gated Stage-B wall benchmark, a sealed RSS cap, a
  stable production trace format, or decoder-performance evidence.

The two former capsule-infrastructure failures were test-fixture defects. A
selective subprocess mock now preserves the real pinned-Python audit, and the
isolated launcher-copy test now copies its required local contract module.
Neither correction changes a production program, authorization, capsule,
coefficient, input, or scientific rule. Stage-B execution remains blocked on
a complete-valid later audit, the retained-wall measurement, capsule, and
independent-audit prerequisites. The replacement seal is complete-valid and
the wall-contract amendment is approved, but neither opens a scientific case.

The exact closure-001 support-source registration and first range-audit
activation are approved and recorded. The activation was consumed by the
failed scan; it cannot be reused. The source-only remediation is approved,
implemented, and validated, but it did not rerun or alter that failed scan.
Closure-002 is separately approved and materialized at registration identity
`7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66`;
the registration record raw SHA-256 is
`d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2`.
Its live permissions are all false. Consequently the registered Stage-B and
Stage-C cases remain unopened. On 7 November 2026 the user approved all five
then-registered decisions. Activation-002 was materialized and consumed by an
interrupted non-scientific scan; no result was published. Its activation and
progress SHA-256 values are
`64f5ce0aa896cff5570e88ad1f89204bdb22dd9c54112c4d2bc35a8dad7caa20` and
`25f5cc5f8c696ca478f7aaf70d65a87656e3f2a6a424da2ca0e77da080defd08`.
The path-correction retry was subsequently approved, materialized, and consumed
exactly once. Its activation, progress, and terminal-result SHA-256 values are
`5a43ca345bd0e1083e9f35faf822377a4207b5b2f4e033b1bf5f480d1abcdc31`,
`415bfd91bfe4e812b3fe467eff8cc34375327552b8642fb0b7c0418cef756a94`, and
`10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`.
The terminal result failed on one mutable-ledger self-reference and a recorded
coordinator field of 6,140,592 KiB versus the 2,097,152-KiB cap. Waited-child
and maximum helper peaks were 269,780 and 252,660 KiB; helper telemetry was
complete at 32/32. Every source, support, inventory, snapshot, and
dormant-Stage-C gate passed with zero scan failures. A direct no-work process
in the same launch path reproduced exactly 6,140,592 KiB, while the same
route-ledger parser in a fresh child reported 54,668 KiB; a controlled
256-MiB-allocation-then-`execve` check preserved the pre-exec 269,952-KiB peak.
The field was therefore launch-contaminated, not a scanner-allocation
measurement, while the formal result remains failed under its registered
contract. No manifest was created, no scientific input opened, and no
downstream step ran.
The process-boundary audit then showed why an ordinary subprocess is not a
sufficient repair: Python uses `vfork` on this host, and that path can repeat a
parent process-image peak. An explicit `fork()` followed by pinned `execve()`
started at 8--10 MiB in the controlled checks. Remediation-002 is now approved
and source-only complete. Its 79/79 synthetic tests and 13/13 independent
source checks pass. In the pinned no-result rehearsal, worker self and
independent `wait4()` both measured 210,828 KiB, the waited-child and helper
peaks were zero, and elapsed time was 6,923 ms; both registered caps passed.
The parent peak of 6,140,592 KiB remained diagnostic only. The four embedded
inventory identities were reproduced without formal activation, live-provider
traversal, or formal-result publication. The failed v11 result remains
byte-unchanged at SHA-256
`10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`,
and its bundle still has no manifest. Activation-002 and closure-002 are
  consumed and cannot be reused. The source rebind was approved on 7 November
  2026, and its exact 14-file source-only implementation is validated at 13/13
  range checks, 87/87 range tests, and 78/78 capsule tests. The computed
  finalized 13-member support-source identity is
  `1e9febb4faeabea8eeedad969cb12a00ae5fd44c2ae6285c6e8d8afd1112931b`.
  The closure-003 and activation-003 IDs were first reserved for source binding
  only. The external candidate-semantics decision is approved, and the
  non-authoritative 13-member candidate is retained at
  `/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-range-audit-v12-source-rebind-20261107-v1/SUPPORT_SOURCE_CLOSURE_003.candidate.toml`,
  with raw SHA-256
  `d498512bfc9b69b71446a5927b65598e864621760349ccb636d5d8f30e9f786b`
  and registration identity
  `1e9febb4faeabea8eeedad969cb12a00ae5fd44c2ae6285c6e8d8afd1112931b`.
  Closure-003 was subsequently approved and its 4194 bytes were materialized
  byte for byte at the canonical path with the same raw SHA-256 and identity.
  Range validation passes 13/13 checks and 87/87 tests; capsule validation
  passes 78/78 tests; and both independent closure rehashes pass.
  `closure_003_present = true`, while activation-003 remains absent and
  `launch_ready = false`. A later formal scan still requires separate approval
  of an exact one-use version-12 activation. No formal scan, governed
  inventory, retained or fresh input, decoder, or Stage-B science has begun.
Coefficient-seal-002 is approved and materialized with authorization
SHA-256
`06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b`,
manifest SHA-256
`a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5`,
and sealed-member SHA-256
`173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078`.
The wall-contract amendment is approved at exact SHA-256
`c76ba22c29bea8d0e25e31cf74057b1649347e44fc56d9f890368e9dcc372a63`.
The retained-wall benchmark and Stage-B execution scopes are prospectively
approved but remain inoperative until their exact prerequisites pass and their
one-use authorization artifacts can be materialized. The goal is active. No
retained-wall run, fresh input, or Stage-B science has begun.
