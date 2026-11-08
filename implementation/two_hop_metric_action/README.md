# Two-hop positive-matrix action

This directory is a local source-and-test extraction of the active
`RQ2-TWO-HOP-POSITIVE-METRIC-001` matrix action. It now also contains a
dormant, synthetic-only implementation of the already registered Stage-C
projected-gradient update. It does not generate or open experiment frames, and
the decoder source has not been activated or run on scientific inputs.

`compound_objective_jc.jl` evaluates the unchanged `J_C` objective function,
its partial derivatives, and its registered fixed positive diagonal from a
Tanner graph, bounded directed-edge state, and channel LLRs.
`jc_metric_direction.jl` passes those calculated quantities to the registered
sparse, state-dependent, recipient-excluded two-hop symmetric
positive-definite matrix and returns a candidate direction plus descent and
condition diagnostics. This production composition does not need a supplied
comparison direction and does not calculate exact sum-product.

The lower-level production action in `two_hop_positive_metric.jl` remains
available for source-level testing. It accepts supplied partial derivatives
and a positive diagonal together with the graph, state, channel LLRs, and
coefficients, then applies the same registered matrix.

`stage_b_direction_kernel.jl` is a byte-identical copy of the registered
source-only per-origin diagnostic (SHA-256
`599ff92f70e955e501f280c80d7919bc4d8838bbccdd9922f0338a3ef63b2383`).
It accepts already-materialized quantities plus a caller-supplied reference
direction, applies the candidate and exact-zero matrix actions, and reports
angle, relative-error, descent, and condition diagnostics for that origin. It
does not calculate `J_C`, calculate the exact sum-product recurrence, load or
generate a case, advance the state, project, run a line search, stop on a
syndrome, form a hard decision, read out a word, write a result, or score
recovery or BER. The code parameter named `sealed_coefficients` checks only the
registered coefficient type and a nonzero two-hop field; it does not create or
validate a governance seal.

The population-reduction seam remains offline and pure. The source-identical
`origin_row_adapter.jl` validates already-materialized per-origin diagnostics
and projects them into separate generic-summary and target-specific views.
The extracted retained arithmetic in
`retained_direction_population_summary.jl` and the source-identical
`target_specific_gates.jl` reduce those views independently. Their decisions
are combined only after the adapter proves unique upstream pairing, common
thresholds, and equal denominators. The retained summarizer is arithmetic, not
an input validator; untrusted rows must pass through the adapter. None of these
three files opens a case, calculates a reference direction, accesses a teacher
inside candidate inference, advances a state, or writes a result.

`two_hop_positive_metric.jl` and `test_two_hop_positive_metric.jl` are
byte-for-byte copies of the historical source and synthetic test suite.
`test/local_finite_difference.jl` adds a central-difference check of the
complete action with respect to its supplied partial-derivative vector and
retains the original synthetic composition fixture. The fixture now calls the
production `J_C` evaluator instead of duplicating it in test code.

`test/local_jc_metric_direction.jl` checks the complete pure path from graph,
state, and LLRs through the `J_C` partial derivatives and fixed positive
diagonal to the candidate and exact-zero lower-endpoint directions. It checks
the production objective function by finite differences, direct-action and
bit-level identities, the zero-gradient case, input nonmutation, fail-closed
inputs, and the absence of state-update, projection, line-search, readout,
exact-sum-product, file-I/O, and randomness capabilities.

`test/authoritative_jc_fixture.toml` is a new frozen 40-case synthetic corpus,
not a copy of the earlier transient comparison inputs. Its optional generator
pins the registered historical `J_C` and fixed-diagonal source hashes. The
ordinary test suite reads only the fixture and reproduces every recorded
objective field and fixed-diagonal entry bit for bit. The corpus uses `n=8`,
24 edges, check degrees 2--6, nonuniform variable degrees, tied and untied
incident-edge inputs, edge-state `+0`, `-0`, `+1`, and `-1`, and LLR inputs at
and beyond `+20` and `-20`. This is deliberate arithmetic coverage, not
exhaustive or scientific validation; the absolute source paths and Julia
version recorded by the optional generator are provenance, while the fixture
consumer is portable.

`test/local_stage_b_direction_kernel.jl` path-adapts the registered 102-test
kernel suite and adds 36 boundary assertions. Those added assertions prove
that changing the caller-supplied reference direction from aligned to opposed
changes only the comparison diagnostics: both calculated directions,
conditions, and family records remain bit-identical. They also reject returned
state/update/readout fields and source dependencies on case generation,
recurrence calculation, decoding, projection, line search, file I/O, or
randomness. The original source-and-action path remains 1,202 assertions: 928
historical matrix-action assertions, 11 action finite-difference assertions,
21 `J_C` composition assertions, 102 path-adapted diagnostic-kernel assertions,
36 reference-direction boundary assertions, and 104 production objective and
direction-composition assertions. The portable fixture adds 692 assertions:
25 provenance, 661 arithmetic, and 6 generator-boundary checks. The pure
population seam adds 262 assertions: 98 for retained summary arithmetic and
boundaries, 112 for the target-specific gates, and 52 for adapter/integration
behavior.

`test/local_full_synthetic_population_chain.jl` adds 84 assertions. Seven
preserve the earlier supplied-partial-derivative and supplied-diagonal
diagnostic, including its `0.9935439809818444`-degree paired angle
improvement. The other 77 validate one durable synthetic chain from a Tanner
graph, bounded edge state, and LLR vector through unchanged `J_C`, the two-hop
candidate and exact-zero lower endpoint, the separate offline diagnostic, the
origin-row adapter, and both population reducers. The already-materialized
comparison vector is frozen from the synthetic candidate itself; it is not an
independent BP direction. The three repeat-labelled rows share one input
identity and the same diagnostic, so they do not represent population
diversity. The target-specific gate passes. Every
generic gate except the unchanged 15-degree paired-improvement requirement
also passes, but the full-chain improvement is only
`0.6852959854888271` degrees. The generic and combined gates therefore fail
closed. The test changes no threshold, opens no registered frame, and performs
no state update, projection, line search, word readout, or recovery, BER, or
FER scoring.

`stage_c_decoder_source.jl` closes the mechanical seam from a pure direction
to an in-memory projected-gradient update. At every attempted update it
recalculates unchanged `J_C`, its partial derivatives, and the current-state
two-hop positive-definite matrix action; tries the registered 13 projected
Armijo points; and retains the registered initialization, 30-attempt cap,
line-search stall, centered incident-edge readout, and strict-negative
decision. A first parity-valid syndrome is telemetry only and does not stop
the path. The candidate entry point requires a nonzero two-hop coefficient.
The exact-zero control traverses the same generic sparse action, including all
four zero-weighted families, rather than branching to a baseline routine.

Its exported state-advancing entry points construct the direction internally;
there is no exported arbitrary-direction step. They have no case loader,
coefficient-seal loader, exact sum-product or teacher hook,
frame/SNR/truth/population input, scoring function, writer, launcher,
randomness, or retuning interface. Its 3,396 synthetic assertions include a
separate pure checker that recalculates every stored
objective, partial-derivative vector, state-dependent direction, raw and
projected trial, Armijo decision, accepted state, readout, syndrome, and
cross-record link. Thirty-five deliberately altered traces, including extra
fields and coercive scalar types, fail closed. The
suite also checks an accepted second trial, bit-exact deterministic reruns
with the synthetic graph, channel-LLR vector, coefficients, and decoder
settings held fixed for both an update-cap path and a stalled path, a parity-valid transition that still
continues through update 30, the exact 13-trial stall, complete-path bit
identity against a test-only direct fixed-diagonal reference, valid-codeword
sign covariance, decoder-level enforcement of the complete condition bound,
and explicit coefficient-admissibility rechecks that close the exported
structure's raw-constructor bypass. This is a real decoder source seam, but not an activated decoder anchor
or a recovery or BER result.

A test-only dense path now enumerates graph incidence directly, constructs the
full two-hop matrices and fixed diagonal without the production path pattern or
sparse action, and reimplements the complete projected Armijo loop. It matches
both the 30-update candidate path and the late-stall path within `3e-13`. A
nondegenerate six-variable fixture also proves that the recipient-excluded
operation creates differences among edge values incident on one bit. Those
zero-mean differences leave unchanged `J_C` and its partial derivatives
unchanged, but they change the next state-dependent matrix direction; the
exact-zero control stays edge-tied.

The late-stall fixture exposes a limitation rather than hiding it. The raw
positive-definite matrix direction has a negative partial-derivative inner
product, yet componentwise projection removes the descent-producing boundary
components and makes all 13 projected displacements ascent. The already
registered fixed-diagonal projected-gradient diagnostic remains nonzero and
produces a feasible lower-`J_C` point, whereas the exact-zero control has a
zero mapping at its stall. Thus this candidate stall is not evidence of box
stationarity. No decoder rule changed; the finding is a source-level
projection/action compatibility diagnosis, not performance evidence.

`benchmark_complete_trace_resources.jl` adds a production-size synthetic
engineering check without importing a case provider or comparison receiver.
It reconstructs the deterministic regular degree-(3,6) graph with 10,200
variables, 5,100 checks, and 30,600 directed edge slots, then runs the
candidate and exact-zero lower endpoint on a cosine LLR vector and an all-zero
LLR vector. Each of the four cells has three one-thread repetitions with
complete-vector trace checking and an in-memory Julia serialization proxy.

The canonical scalar-only receipt is
`complete_trace_resource_measurement_2026-11-06_v1.toml` (SHA-256
`4620016b8eb4544a39b966185589dbbbaf27a0d89c72fab9d013f59afc20bee1`).
Both cosine-input arms reach the 30-update cap. Their traces occupy
69,861,148 bytes, decoder time spans 5.7778--6.4499 seconds, complete-trace
checking spans 5.5252--5.7620 seconds, and measured child-process peak RSS is
894,263,296--899,579,904 bytes. Both zero-input arms stall on the first
attempt after 13 rejected trials; their traces occupy 11,763,554 bytes and
measured peak RSS is 716,857,344--719,220,736 bytes. Per-repetition wall,
allocation, garbage-collection, serialization, and semantic-identity fields
remain in the receipt.

The 96 MiB update-cap, 16 MiB immediate-stall, and 384 MiB calculated
current-schema limits apply only to retained trace vectors and the
serialization proxy. They are not peak-RSS or cumulative-allocation limits;
the 16 MiB value is not a late-stall limit; and Julia serialization is not a
stable production format. This resource check is not the separately gated
Stage-B wall benchmark or scientific decoder evidence.

The complete local suite passes 5,636 assertions: 1,202 source-and-action,
692 portable-fixture, 262 population-seam, 84 full-chain, and 3,396 dormant
Stage-C source assertions. The retained V5 coefficients in
`evidence/retained_stage_a.toml` are provenance only: they are not a governance
seal and are not loaded automatically.

Run the source-only tests with:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  julia --startup-file=no --project=. test/runtests.jl
```

Reproduce the production-size synthetic resource receipt into a new path with:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  timeout 600s julia --startup-file=no --project=@stdlib \
  benchmark_complete_trace_resources.jl OUTPUT.toml
```

The harness refuses to overwrite an existing output.

Passing these tests establishes only local source identity, synthetic
arithmetic properties, and executable update mechanics. The field
`local_candidate_gate_passed` is only a
per-origin conjunction of raw, unprojected strict descent and condition bounds; it is not a
Stage-B population result. An earlier seam-only fixture passes the combined
gate on fabricated rows, while the durable full-chain fixture described above
fails it on three repetitions of one synthetic diagnostic. No registered
Stage-B population was consumed. Neither fixture establishes population
diversity or direction agreement with BP. The synthetic Stage-C tests advance
only literal test states; they are not fresh direction validation, a registered
decoder evaluation, or evidence that the construction approaches BP
performance. Stage B must first pass, and Stage C must then be separately
authorized, before any reserved decoder-anchor case may be opened.
