# BP–GD mechanism study

This directory is the compact continuation of the BP-versus-projected-GD
research program. It keeps the research history, the mathematical deck, the
best **performance-verified** GD decoder found so far, and a source-and-test
extraction of the active two-hop metric action, its unchanged objective
function, its per-origin diagnostic kernel, a frozen authoritative arithmetic
corpus, and a durable synthetic path through the pure population-reduction
seam that would gate a future direction screen.

## What is included

- [`explainers/the_path_so_far_tree.html`](explainers/the_path_so_far_tree.html)
  is the concise decision tree. Pruned branches retain provenance locations,
  but their source code is not copied here.
- [`explainers/the_path_so_far.html`](explainers/the_path_so_far.html) is the
  detailed research history.
- [`explainers/map_then_state/map_then_state.pdf`](explainers/map_then_state/map_then_state.pdf)
  explains the mathematical boundary between a gradient step and direct
  application of the exact sum-product recurrence.
- [`implementation/compound_box_gd/`](implementation/compound_box_gd/) contains
  the selected `compound__box` projected-GD implementation and compact retained
  evidence.
- [`implementation/two_hop_metric_action/`](implementation/two_hop_metric_action/)
  contains the registered two-hop metric action, a pure calculation of the
  unchanged `J_C` objective function and its partial derivatives, a pure
  state-and-LLR-to-direction composition, a source-identical per-origin
  direction-diagnostic kernel, a frozen arithmetic fixture, pure population
  adapters and reducers, their source-level tests, and retained Stage-A
  provenance. The objective/direction and population-reduction components
  calculate candidate quantities without calculating exact sum-product or
  accepting a comparison direction, and they do not advance or project a
  state. A separate dormant Stage-C source performs the registered projected
  update on synthetic literals only. The separate per-origin kernel still
  accepts a caller-supplied comparison direction for offline diagnostics
  only. The pure reducers combine generic and target-specific gates only
  after unique pairing, common thresholds, and equal denominators are proved; they have
  been exercised on synthetic, already-materialized diagnostics only. A
  durable full-chain test now starts at a synthetic graph, state, and LLR
  vector, calculates the unchanged `J_C` direction, passes an
  already-materialized comparison vector only to the separate offline
  diagnostic, and reaches the population gate. The comparison vector is
  frozen from the synthetic candidate itself, and the three population rows
  share one input identity, carry repeat labels, and repeat that one
  diagnostic. They therefore provide neither population diversity nor an
  independent BP comparison. The package as a whole is neither activated nor
  scientifically evaluated as a decoder and contains no fresh scientific
  validation.
- [`research/active_goal.md`](research/active_goal.md) records the active goal,
  closed assumptions, prospective direction-screen card, and separate approval
  decisions. It is a plan, not a completed experiment or performance result.
- [`research/proposed_jc_mean_coordinate_barrier_card.md`](research/proposed_jc_mean_coordinate_barrier_card.md)
  is the inert, unapproved design for distinguishing a 13-trial line-search
  stop from a certified continuous barrier and a finite-step no-jump closure
  in the mean coordinates on which `J_C` depends. It authorizes no input or run.
- [`.agents/skills/`](.agents/skills/) contains the repository-specific
  experiment, terminology, and writing rules.

## Current terminal target

At each of the untouched 6-dB and 1.5-dB levels, the candidate and native
exact sum-product BP must process the same registered 200 cases. For each
paired case, the parity-check matrix, transmitted word, noise realization,
and vector of channel LLRs are held fixed. Let `C_s` be the candidate's
transmitted-word recovery count within 30 attempted updates and `B_s` be BP's
transmitted-word recovery count at its first zero syndrome or 80
message-passing iterations. The one-sided recovery-count requirement is
`C_s >= B_s - 30` at both levels; candidate recovery above BP is allowed. The
candidate may not call BP at inference. A wrong valid codeword, exact-zero
readout tie, nondeterministic replay, or work outside the registered
bounded-degree `O(E)` envelope fails independently of the recovery count.

## Claim boundary

The selected construction retains one scalar per bit, constructs
check-specific offsets after its first accepted update, freezes those offsets,
then applies diagonal-preconditioned projected gradient descent to an objective
with channel, compound-parity, and binary terms, using strict-decrease
backtracking. On the registered fresh
6-dB frames 50025–50224, it recovered 177/200 transmitted words after 30
updates and 200/200 after 90. The primary and replay results agreed.

Two later complete-valid factorials determine which parts of that historical
offset construction must not be rerun unchanged. In
`RQ2-GD-OFFSET-SPLIT-001`, on held-out 6-dB frames 30001–30200, using retained
offsets in the parity calculation recovered
163/200 transmitted words versus 107/200 without that use; changing only the
projection interval recovered 106/200, and the changed interval added nothing
when parity use was active (163/200 versus 163/200). In
`RQ2-GD-PARITY-ASSIGNMENT-REFRESH-001`, on prospective frames 40001–40200,
the as-constructed check assignment recovered 174/200 with the first adopted
offsets frozen and 165/200 with later replacement, whereas a fixed within-bit
derangement recovered 61/200 and 70/200. The registered
replacement-versus-freezing equivalence gate did not pass. These are scoped
causal results for constructed projected-gradient variants at 6 dB: they show
that parity-calculation use and correct check assignment carry the observed
benefit, not that the offsets are BP messages or that the construction
approaches BP across signal-to-noise ratios.

This is the best verified GD recovery result in the retained campaign. It is
not evidence that its performance approaches BP across signal-to-noise ratios. A related
native compound projected-GD budget diagnostic recovered 0/200 at 1.5 dB, and
the later state-dependent two-hop positive-matrix branch has not yet run as a
decoder.
That branch therefore appears in the research tree as active but unvalidated;
its source/test-level metric action and per-origin diagnostic kernel are copied
here, together with the pure calculation from graph, state, and channel LLRs to
the candidate direction and a separate dormant Stage-C state-advance source.
The objective/direction and population-reduction components do not advance a
state and are not a decoder. The dormant Stage-C source advances synthetic
states, but it is neither activated nor scientifically evaluated as a decoder,
and none of these components is a governance seal or fresh scientific result.
The original 1,202 passing synthetic
assertions include the prior 1,098 checks and 104 checks of the production
`J_C` and direction path, including a zero-gradient case and fail-closed
capability boundaries. The portable gate now adds 692 checks of a new frozen
40-case synthetic corpus generated from the registered historical `J_C` and
fixed-diagonal sources, plus 262 checks of the pure population-reduction seam.
The corpus records exact binary64 inputs and outputs across check degrees
2--6, nonuniform variable degrees, tied and untied incident-edge inputs, box
endpoints and signed zero, and LLR inputs at and beyond the clipping boundary.
The durable full-chain synthetic test
[`local_full_synthetic_population_chain.jl`](implementation/two_hop_metric_action/test/local_full_synthetic_population_chain.jl)
adds 84 assertions: seven preserve the earlier supplied-partial-derivative and
supplied-diagonal diagnostic, whose
paired angle improvement is `0.9935439809818444` degrees, and 77 validate the
path from a graph, state, and LLR vector through unchanged `J_C`, the two-hop
candidate and lower endpoint, the separate offline diagnostic, the adapter,
and both population reducers. On the latter path, the target-specific gate
passes and every generic gate passes except the unchanged 15-degree paired
improvement requirement: the measured improvement is only
`0.6852959854888271` degrees, so the generic and combined gates fail. No
threshold was changed, and no registered frame was opened. The non-iterative
source-and-interface portion passes 2,240 assertions: 1,202 source-and-action assertions,
692 portable-fixture assertions, 262 population-seam assertions, and 84
full-chain assertions. Because the comparison vector is frozen from the
synthetic candidate and all three repeat-labelled rows share one input
identity and one diagnostic, this arithmetic evidence is not
population-diversity evidence, direction agreement with BP, a Stage-B
population result, decoder evidence, or decoding-performance evidence.

A separate dormant Stage-C source implements the registered in-memory
projected-gradient update on deterministic synthetic graphs. Its 3,396
assertions include a pure checker that recalculates every stored objective,
partial-derivative vector, state-dependent direction, raw and projected trial,
Armijo decision, accepted state, readout, syndrome, and cross-record link.
They also cover an accepted second trial, bit-exact deterministic reruns with
the synthetic graph, channel-LLR vector, coefficients, and decoder settings
held fixed for an update-cap and a stalled path, 35 altered traces (including extra fields and
coercive scalar types) that fail closed, and a path
that first becomes parity-valid at update 16 but continues through update 30.
The decoder and checker also revalidate coefficient admissibility, closing the
exported structure's raw-constructor bypass. Together, the package passes
5,636 synthetic assertions. A test-only dense implementation that bypasses
the production path pattern and sparse action reproduces the complete 30-
update and late-stall candidate paths within `3e-13`; a nondegenerate fixture
also proves that the recipient-excluded operation creates edge-specific state
that changes the next matrix direction. The retained synthetic candidate stall
is not box-stationary: its raw matrix direction is descent, projection turns
all 13 attempted displacements into ascent, and the registered fixed-diagonal
projected-gradient diagnostic still finds a feasible lower-objective point.
The exact-zero control's stall has a zero mapping. No decoder rule changed.
This establishes
source mechanics only; it is not an activated decoder anchor, recovery result,
coded-bit BER/FER measurement, or comparison with native BP.

That diagnosis also separates the current direction screen from a later update
rule. A source-only design audit found one nonduplicate linear-cost possibility:
test the projected two-hop displacement first, use the already registered
fixed-diagonal projected-gradient trial only when that displacement is not
strict descent, and declare stationarity only when the fixed-diagonal projected
mapping is zero. A future experiment would have to record how often the
fallback is used and reject the construction if it merely reproduces the
already tested fixed-diagonal decoder. This has not been implemented,
registered, or run. It differs from the dormant raw-direction check in
`RQ2-GRADIENT-GEOMETRY-001`, which occurs before projection. The registered
Stage-B direction screen remains first, and even a pass would not resolve the
projection/action incompatibility or validate the unchanged projected update
for a decoder anchor. Under the frozen branch policy, a pass admits the
unchanged Stage-C update; the safeguard becomes eligible only after a Stage-C
failure, unless a prospective amendment is approved before any Stage-C case
opens.

The preserved upstream v10 range-audit producer validator passed 10/10 checks
and its core suite passed 61/61 synthetic tests. Its ledger stores
four exact canonical JSONL streams, closes the result to exactly 175 fields and
activation v2 to exactly 23 fields, and proves inventory completeness and
internal cross-consistency. Those producer checks alone cannot establish live
truth for a fully coherent rewrite. It binds twelve Stage-B support sources
plus the hard-pinned, TOML-parsed dormant Stage-C boundary. The exact 13-member
closure is approved at identity
`c2ef2d0f77d1fc441e532c78dbf7d4917c4ef8defb948f0315b1c659a71d4403`;
the registration record raw SHA-256 is
`fb8bab4d00b08e88b34713c9eb77414d9cc0ef874e59b8d9712832a9db459c4e`.
The related 21-member capsule-infrastructure validator passes, and its pinned
Python 3.11 suite passes 76/76 tests. The exact downstream range bundle remains
three files. Builder and independent auditor each walk root components without
following symlinks, retain physical identities, reject physical aliases,
recompute containment, rerun the live worktree, ref, filesystem, and Git-blob
inventories, recompute hashes, object IDs, and fingerprints, compare all four
regenerated canonical payloads byte for byte, and repeat repository-identity
and post-Git-metadata checks. The first range-audit activation was approved and
consumed on 6 November 2026. Its exact 175-field result is preserved at
SHA-256
`46d38209d89a6bd0a51f1008fa68cbde26033ecf8954f3b2750c5e5e980c510f`
with status `collision_or_audit_failure`: 31 lexical/parser collision records
in six groups. Its frozen `scan_max_rss_kib` field is 6,437,576 KiB against
the 2,097,152-KiB cap. The scanner calculated that field by adding the
coordinator's lifetime peak RSS to the largest lifetime peak RSS reported for
any waited child. Those peaks need not be simultaneous, so the field is not a
measured simultaneous process-tree peak; neither component nor per-helper RSS
was retained. The registered cap comparison remains failed. All source,
support, inventory, and snapshot gates
passed with zero scan failures; fresh inputs and Stage C remained closed.
Review found no competing
frame reservation or scientific frame consumption, but that diagnosis cannot
turn the failed contract into a pass. The separately approved source-only
remediation
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-001`
is implemented. The prospective v11 preparation passes 11/11
source/provenance checks and 70/70 synthetic tests, closes its result to 183
fields, binds exact provenance for the 27 reviewed historical/test
non-registration records, and uses bounded streaming parsing for `.json`
files. It records coordinator and waited-child lifetime peaks separately from
per-helper peaks; each helper peak is stabilized after parsing and
response serialization, while the post-wait child observation is conservative
through process exit. This does not claim
simultaneous process-tree RSS, remeasure the preserved v10 failure, or
authorize a retry. Large structural `.txt` and suffixless documents remain
isolated in helpers and component-gated; they are not claimed to use the
streaming parser. The exact remediated support-source closure
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-SUPPORT-SOURCE-CLOSURE-002`
is now approved and materialized. Its 13-member registration identity is
`7a796e142cd263e36c994854ea377841c6cddb262a1534690902d7c4b0681d66`,
and the registration record raw SHA-256 is
`d3e8acb2b91aeb79788fb55d1134a4e653ee091cf2ec67a580fe4d69545d77c2`.
Every scan, fresh-input, scientific-execution, and performance permission in
that record is false. The separate
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002`
was approved, materialized, and consumed on 7 November 2026. Its v11 scan
passed the pre-scan source, support-closure, and inventory gates and reached
filesystem root 5 of 17. It was then interrupted before result publication
because its bound filenames could not satisfy the registered three-file
capsule bundle. No range result was published and no scientific input opened.
The path-correction retry
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-ACTIVATION-002-PATH-CORRECTION-RETRY-001`
was approved, materialized, and consumed exactly once. Activation SHA-256 is
`5a43ca345bd0e1083e9f35faf822377a4207b5b2f4e033b1bf5f480d1abcdc31`,
progress SHA-256 is
`415bfd91bfe4e812b3fe467eff8cc34375327552b8642fb0b7c0418cef756a94`,
and terminal result SHA-256 is
`10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`.
The result failed closed on two independent gates: one mutable-ledger
self-reference to the already registered campaign interval, and a recorded
coordinator field of 6,140,592 KiB against the unchanged 2,097,152-KiB cap.
Waited-child and helper peaks were 269,780 and 252,660 KiB, helper telemetry
was complete at 32/32, and all source, support, inventory, snapshot, and
dormant-Stage-C gates passed with zero scan failures. Targeted reproduction
then showed that the coordinator field inherited a pre-existing process-lifetime
peak across `execve`: a no-work direct process reported the same 6,140,592 KiB,
whereas the same route-ledger parser in a fresh child reported 54,668 KiB. This
does not convert the registered failure into a pass, but it does rule out using
that field as evidence that the scanner allocated 5.86 GiB. No manifest was
created, no scientific input opened, and no downstream step ran. There is no
complete-valid v12 audit or Stage-B science. The source-only
[`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-002`](research/proposed_stage_b_range_audit_remediation_002.md)
is approved and complete as source/process-accounting work. It places formal
traversal behind a true `fork()` followed by pinned `execve()`, stabilizes the
worker peak after result serialization, and requires the final
`wait4()`-checked process-tree peak to equal
`max(worker self, worker waited child)`. Version-3 document helpers use the
same self-versus-waited-child maximum.
Ordinary subprocess/`vfork` and exec-only paths do not qualify. The generator
is pinned at SHA-256
`a3e40cc9d31f5853894a5cfff218bf70ab8f20fbccceb0f6565614ff477fa9e0`;
79/79 synthetic tests and 13/13 source checks pass. The canonical no-result
rehearsal receipt is pinned at SHA-256
`e2f33286897e7d56c07401274f2c19b865670e8c59c27dd235faa017dc0f494c`.
It records worker self and `wait4()` peaks of 210,828 KiB, zero waited-child
and helper peaks, and 6,923 ms elapsed against unchanged caps of 2,097,152 KiB
and 1,800,000 ms. The parent's inherited 6,140,592-KiB peak is diagnostic
only. All four embedded inventories were reproduced; formal activation,
live-provider traversal, and formal-result publication remained false. The
prospective publisher completes all checks and `fsync` operations before its
exclusive-link commit and claims no post-link crash-durability acknowledgement.
The failed v11 result remains byte-unchanged at SHA-256
`10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`,
with no manifest. This completion is not a formal scan or scientific result.
Activation-002 and closure-002 are consumed and cannot be reused. A later
formal scan first requires a separately reviewed, approved, and materialized
new source rebind and exact support-source closure, followed by a new one-use
version-12 activation; no new approval ID has been introduced. The separately
approved replacement coefficient seal is complete-valid: authorization
SHA-256 is
`06944b797b96c93ec136c41949d708eb1613caba0387871b256003155950803b`,
manifest SHA-256 is
`a71ebef92cd1a998be9fda33ba2fadbda0680aa9da140b9941166a75c2db38c5`,
and sealed-member SHA-256 is
`173a68f41e53d4e7b16a40d27271245ae9c83b0b5f4858c7f15d439f25fb3078`.
It opened no frame and produced no scientific result. The wall-contract
amendment is approved at exact SHA-256
`c76ba22c29bea8d0e25e31cf74057b1649347e44fc56d9f890368e9dcc372a63`.
The retained-wall benchmark and Stage-B execution scopes are prospectively
approved, but remain inoperative until their exact prerequisites pass and
their one-use authorization artifacts can be materialized. The goal is active;
no retained-wall run, fresh input, or Stage-B science has begun.

The mirrored
[`benchmark_complete_trace_resources.jl`](implementation/two_hop_metric_action/benchmark_complete_trace_resources.jl)
and canonical scalar
[`resource receipt`](implementation/two_hop_metric_action/complete_trace_resource_measurement_2026-11-06_v1.toml)
also exercise candidate and exact-zero arms on a deterministic synthetic
production-size regular graph, three one-thread repetitions per cell. The
update-cap traces occupy 69,861,148 bytes and take 5.7778--6.4499 seconds to
calculate plus 5.5252--5.7620 seconds for complete-trace checking; measured
child-process peak RSS is 894,263,296--899,579,904 bytes. Immediate-stall
traces occupy 11,763,554 bytes. This is source/resource feasibility only: no
registered frame, comparison receiver, truth, or performance scorer was
opened, and the receipt is neither a Stage-B wall result nor evidence of
approaching BP.

## Scope of this export

This export has no runtime dependency on the original worktrees. Closed-branch
implementations, queue machinery, large traces, and nonportable verification
scripts were not copied. The active package contains pure objective and
direction calculations, the source-identical metric action and per-origin
diagnostic kernel, a frozen arithmetic fixture, pure population adapters and
reducers, the dormant synthetic-only Stage-C decoder source and its pure trace
checker, the portable production-size synthetic resource harness and its
scalar-only canonical receipt, local synthetic tests, and provenance. The ordinary test gate does
not depend on the original worktrees. It contains no scientific-case runner.
The full-chain synthetic test performs no state
update, projection, line search, word readout, or recovery, BER, or FER
scoring. Paths shown at pruned leaves are provenance, not local dependencies.
