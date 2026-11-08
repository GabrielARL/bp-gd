# Registered `J_C` projected-stationarity continuation card

Experiment ID: `RQ2-JC-PROJECTED-STATIONARITY-001`

Registration date: 7 November 2026

Status: **registered card; execution unapproved and inert**

This file is the card-first registration requested by the user. It authorizes
no source implementation, input projection, case access, replay, continuation,
scoring, queue construction, result publication, or explainer change. The only
future decision ID is
`RQ2-JC-PROJECTED-STATIONARITY-001-EXECUTION-001`. That one decision may
authorize the exact source preparation, validation, freeze, candidate-only
execution, post-commit scoring, and evidence-synchronized reporting described
here, but only when the approval cites this card's handoff SHA-256. This is a
prospective card-level authorization, not byte-level approval of source that
does not yet exist; the `SOURCE_READY` gate below is therefore mandatory. Any
change to this card after approval requires a new card hash and a new approval.

## Research objective branch

This is a diagnostic reopening of the completed fixed-scalar-matrix native
compound projected-gradient branch. It is not a successor decoder, a new
metric family, or a route around the active two-hop screen. Its purpose is to
determine how the already exposed native control terminates when its old
90-update cap is removed and numerical projected stationarity is measured.

Under the required classification taxonomy, this is an
**exposed-population parameter study and deterministic continuation
diagnostic**. It is not a prospective performance experiment and cannot revise
the earlier causal ladder. Every outcome through update 90 is already known.

## One question

On all 200 exposed 6 dB cases and all 200 exposed 1.5 dB cases from
`RQ2-COMMON-COORDINATE-BUDGET-90-001`, what fraction of the native compound
control's trajectories first:

1. reach a parity-valid hard-decision estimate;
2. reach the primary `G_eta` tolerance and then the tighter second-pass
   tolerance with an unchanged hard decision;
3. exhaust the frozen strict-decrease line-search grid while still above the
   stationarity tolerance; or
4. reach the frozen per-case wall limit?

The post-commit scorer then asks whether each parity-valid hard-decision
estimate is the transmitted word and describes the error/check structure at
every other committed terminal state.

## Mechanism being measured

The measured mechanism is termination of monotone projected descent on the
unchanged native compound objective. The diagnostic distinguishes a
finite-tolerance projected-stationarity terminal from a line-search-grid stop,
a wall stop, and a late parity-valid readout. It does not test a new escape
operation and does not establish a positive objective rim.

Operationally, a case receives the registered
`replay_confirmed_approximate_stationarity` label only when the primary pass
reaches its `G_eta` tolerance, the second pass exactly reproduces the complete
primary prefix, the second pass then reaches the tighter tolerance, and the
two terminal hard decisions are identical. A finite tolerance is not a proof
that `G_eta` is mathematically zero.

## Closest retained evidence and anti-duplication boundary

### Source population

`RQ2-COMMON-COORDINATE-BUDGET-90-001` is the sole source population and the
exact method predecessor. It retained one scalar `x_i` per bit, the native
compound objective and its partial derivatives, the fixed scalar diagonal,
strict-decrease backtracking, and componentwise projection. It obtained:

- 193/200 transmitted-word recoveries at 6 dB by update 90; and
- 0/200 transmitted-word recoveries at 1.5 dB by update 90.

Every source case ran through update 90 because its registered stopping rule
had no syndrome-based early stop. The known outcomes make this continuation a
mechanism diagnostic, not fresh performance evidence. The old card's closure
of further cap increases remains valid for performance-seeking cap escalation;
this card reopens the exposed traces only to classify their terminal mechanism.

The pinned predecessor identities are:

| Retained object | SHA-256 |
|---|---|
| Budget-90 experiment card | `8a263377ca7d62061f7718a064e3c349eaa43ac7b69271dc3daa457169d3dbe0` |
| Budget-90 diagnostic configuration | `d0691daca937ecddf2863d552c4aae909f2fb8d244fed4f710aa74102310dcbc` |
| Budget-90 freeze `MANIFEST.sha256` | `2b7451931df7bf9d3c53ebf6d0f6351ef470211ed8c8255eb0e94e5f3e25f444` |
| Budget-90 `freeze_manifest.toml` | `178d614c8af3e28ac83ef74d9f3626ee9d5257a1419f5a3590ae4cb6dbab06e6` |
| Budget-90 frozen runner | `fdcb34fbacae24894c25dee1baca51a2aff1d99806454427aefe6efd306c1522` |
| nested predecessor source manifest | `a184145f6991b537d330122ba2941529cb0667566f34edc1a5a0dc26a6aa4dd7` |
| source input manifest | `ba4d1c833c5bfc586b5ea250858d4c56b0685d9a87e7cd76e1b134e9ca4ef709` |
| source input table | `22baeb48556df1eebd36f1b4ea33e0cd213b0bfa192eebcc9e361e4defca4c19` |
| 6 dB result manifest | `8792cf85e59b0f55125e0085847038a6b2f3dbe0abfaa798e95120dfc62629a3` |
| 6 dB completion record | `71f23cc3fdc8d433c5bb0b41a337880fbe6e322bbeb6b801bcbf6e3db39d51ef` |
| 1.5 dB result manifest | `6125385b0ab981b602f7849b827186aa119850ca8db19f30f08dd9541fdc5c68` |
| 1.5 dB completion record | `2186e41749a68d9aabf33c257f563098bb5fa1b1a1d46fc2e0784df86099b840` |

The retained freeze records source Git commit
`2bb8bcdac68d3c0c0988e2861ade387c5b41ddcc` and predecessor result commit
`3578db5a9046cdf837c0d29bdefcfededfc67107`. The freeze manifest, not the
current mutable worktree, is the arithmetic authority for the continuation.

### Closest diagnostic

`RQ2-GD-TRAJECTORY-DIAGNOSIS-001` is the closest retained diagnostic. It
measured the recurrence-residual objective `H` at the registered update-30
endpoint on different case ranges and multiple state/step cells. It did not
continue the native compound control, measure terminal states of `J_C`, or
apply the truth firewall and error/check classification in this card.

### Work explicitly left alone

The complete `RQ2-TWO-HOP-POSITIVE-METRIC-001` Stage-B-through-D chain, all
of its registered frame reservations, approval artifacts, source, and results
are excluded from this experiment and must remain byte-unchanged. Their
numeric interval is deliberately not duplicated here because the active range
auditor treats documentary frame-range text as a reservation candidate. This
card neither consumes nor releases any two-hop case.

The inert proposed `J_C` mean-coordinate barrier diagnostic also remains
unchanged. This card can supply candidate terminal states for a later barrier
certificate, but it cannot itself certify a positive-height rim or authorize
an uphill or nonlocal displacement.

## State, objective, and coordinates

The graph is the retained regular `(3,6)` LDPC Tanner graph with:

```text
n = 10200 bits
m = 5100 checks
variable degree d_i = 3
check degree = 6
graph seed = 169616412
```

The retained source protocol used the all-zero transmitted word. That fact is
part of the post-commit protocol fingerprint, but it is not a candidate input:
the candidate source may not contain an all-zero shortcut or branch on a known
truth pattern. Before scientific launch, synthetic substitution tests must
show that changing an unavailable truth fixture cannot change any candidate
calculation or trace.

The candidate retains one scalar `x_i` per bit, so
`x in [-1,1]^n`. A positive channel LLR favors bit zero. Initialization is

```math
x_i^{(0)}=\tanh(L_i/2),
```

using the sealed clipped vector of channel LLRs. The hard-decision estimate is
bit one exactly when `x_i < 0`; exact zero reads as bit zero and is separately
counted as a tie. The validity test independently recomputes the binary parity
syndrome from the hard-decision estimate.

Write the scalar-coordinate form of the unchanged objective as

```math
\widetilde J_C(x)
=-\frac{L^{\mathsf T}x}{2n}
+\frac{w_p}{n}\sum_c\left(1-\prod_{i\in c}x_i\right)^2
+\frac{w_b}{n}\sum_i(1-x_i^2)^2,
```

with `w_p = 2` and `w_b = 0.2`. This is the retained native compound
objective; equivalently, in the registered tied edge notation,
`widetilde J_C(x)=J_C(Bx)`. All calculations, arithmetic order, clipping, and
partial derivatives must come from the hash-bound predecessor source unless
this card names a diagnostic-only addition.

## Why there is one arm, not a separate Euclidean arm

In the retained scalar coordinate, define

```math
\kappa_i=\frac{2w_p d_i+8w_b}{n},\qquad
D=\operatorname{diag}(\kappa_i).
```

Because `d_i=3` for every bit,

```math
D=\frac{13.6}{n}I_n,
\qquad
-D^{-1}\nabla\widetilde J_C(x)
=-\frac{n}{13.6}\nabla\widetilde J_C(x).
```

The preconditioned direction and the Euclidean negative-gradient direction
are therefore collinear; a separate Euclidean arm would change only the step
grid's scalar units. This card keeps only the retained native compound
control.

There is a coordinate-notation conflict in the request that this card records
rather than hides. The registered edge-coordinate diagonal is

```math
M_{i\to c}=\frac{\kappa_i}{d_i}=\frac{13.6}{3n},
```

whereas the effective one-scalar diagonal is
`D=B^T M B=(13.6/n)I_n`. Thus the conclusion that the retained scalar
direction equals a rescaled negative gradient is correct, but
`kappa_i/d_i = 13.6/n` is not correct if the symbol denotes the edge
diagonal. All solver and stationarity calculations in this card use the
one-scalar `D`, not `M`.

## Method fingerprint

Only one candidate method is present:

- **persistent state:** one scalar `x_i` per bit; no directed BP messages,
  velocity, momentum, check-specific offsets, or state-dependent matrix;
- **channel evidence:** the sealed clipped vector of channel LLRs, with
  positive values favoring bit zero;
- **objective:** unchanged `widetilde J_C` above;
- **check-local calculation:** temporary compound-parity products and partial-
  derivative contributions, recomputed from the current state and discarded;
- **global direction:** `-D^{-1} grad widetilde J_C(x)` with fixed scalar
  `D=(13.6/n)I`;
- **trial grid:** `alpha_b=0.2*2^(-b)` for `b=0,...,16`, in that order;
- **projection:** componentwise projection of every trial onto `[-1,1]`;
- **acceptance:** the first finite trial with strict objective decrease;
- **schedule:** one complete objective/partial-derivative calculation followed
  by the ordered projected trial grid per attempted update;
- **readout:** bit one iff `x_i<0`;
- **validity:** independently recomputed zero binary parity syndrome; and
- **inference isolation:** no transmitted word, truth-derived statistic, BP
  state, BP output, exact-recurrence direction, teacher direction, or retained
  outcome label is available to the candidate process.

The objective, state, fixed diagonal, direction, step grid, strict-decrease
rule, projection, initialization, and arithmetic order are inherited. The
changed operations are continuation beyond update 90, the prospective terminal
rule, and read-only instrumentation.

## Only changed operation relative to the method

The descent calculation itself does not change. Relative to the retained
method, this diagnostic removes the update-90 cap, adds the registered terminal
checks and mechanism instrumentation, and changes parity validity from shadow
telemetry to an early stop. Because more than one diagnostic protocol field
changes, this is not a one-operation causal ablation; it is the exposed-
population parameter study classified above. Every conclusion must remain
about this newly frozen terminal protocol.

## Locked exposed populations

No case selection, filtering, replacement, or fresh generation is allowed.
Both complete source populations must run:

| Level | Frames | Cases |
|---|---:|---:|
| 6 dB | `61745:61944` | 200 |
| 1.5 dB | `61969:62168` | 200 |

For each case, the parity-check matrix, adjacency order, vector of channel
LLRs, initialization, and noise realization remain fixed. The candidate sees
an opaque case key rather than the source frame number. The source SNR label
may be attached only outside the solver for population routing; it may not
alter any candidate calculation.

## Prefix reproduction and the changed stopping rule

Both scientific passes restart from update 1. Before a continuation value is
accepted, the new implementation must reproduce every available predecessor
control row, state hash, hard-decision hash, syndrome, objective, retained
partial-derivative norm, accepted step, trial count, and trial outcome exactly
through the new pass's stop or through update 90, whichever comes first. The
predecessor table does not contain a complete partial-derivative-vector hash;
any such digest in the new trace is newly generated diagnostic evidence and
must not be presented as a predecessor equality field.

The source run did **not** stop on parity validity. This card deliberately does.
Consequently, a 6 dB case whose source trace first becomes parity-valid before
update 90 stops at that first valid state and cannot also reproduce the later
source rows. This is a retained-rule conflict, not implementation drift. The
gate is exact equality on the common prefix. A case still invalid at update 90
must reproduce all 90 source updates before any continuation update is
attempted.

Existing source tables include truth-dependent columns. The candidate process
must never open those tables. After execution approval but before any case
runs, an independent preparation step must construct and freeze a
truth-stripped allowed-field prefix projection and its per-case hashes. That
preparation step may read the retained result solely to produce the declared
projection; it must not expose transmitted bits, coded-bit errors, recovery
labels, or BP quantities to the candidate bundle. Any inability to construct
this separation fails closed before launch.

The resulting candidate packet must have a closed schema and manifest that
allow only the graph identity and adjacency, vector of channel LLRs,
initialization, opaque case key, solver constants, and allowed predecessor
prefix hashes. The candidate process must run inside an operating-system-level
allow-list boundary containing only that read-only packet, the hash-bound
candidate executable/runtime, and an unused write-only result directory. It
must have no network, parent-directory traversal, environment-variable, file-
descriptor, or filesystem route to the truth-bearing source/result tree. An
independent launch-boundary test must demonstrate denial of a known forbidden
truth path before the first case opens; inability to enforce that boundary
fails closed.

## Registered vector `G_eta`

Freeze `eta=0.2` and define, in the one-scalar coordinate,

```math
G_\eta(x)=\frac{x-\Pi_{[-1,1]^n}
\left(x-\eta D^{-1}\nabla\widetilde J_C(x)\right)}{\eta}.
```

The primary scalar is `norm(G_eta(x), Inf)`. The mapping is recomputed in an
independent buffer from the state to which it is attached. The production
partial derivatives must first pass finite-difference tests on frozen
synthetic fixtures, and the independent mapping must pass box/projection and
bound-complementarity fixtures before any scientific case opens.

`G_eta(x)=0` is the exact box first-order stationarity condition for this
declared objective and fixed diagonal. The thresholds below certify only that
the registered binary64 norm satisfies the stated finite tolerances.

## Primary stop rule

The initialization is recorded but is not eligible to stop the method; every
case must replay update 1. After each completed accepted update, apply these
checks in this exact order:

1. Validate the state, then independently calculate the objective, partial
   derivatives, `G_eta`, hard-decision estimate, and syndrome. If the state or
   any required real-valued result is nonfinite, stop immediately with
   `invalid_nonfinite`. No readout, wall, line-search, or stationarity label may
   override a nonfinite value.
2. If the independently computed syndrome is zero, stop with
   `first_parity_valid`.
3. If `norm(G_eta, Inf)` is at most `1e-8`, stop the primary pass with
   `primary_tolerance_reached` and require the tighter confirmation below.
4. If the monotonic per-case solver clock has reached 120.000 seconds, stop at
   the last completed state with `unresolved_wall_limit`.
5. Otherwise attempt the frozen 17-trial strict-decrease line search. Validate
   each raw trial, projection, and trial objective immediately; any nonfinite
   value is `invalid_nonfinite`. If no finite trial is accepted and
   `norm(G_eta, Inf)>1e-8`, stop with `unresolved_line_search_stall`.

At initialization, the same quantities are calculated and validated before
the mandatory update-1 attempt, but parity and tolerance are telemetry only.
If all update-1 trials are rejected, classify the unchanged initialization as
`primary_tolerance_reached` when its already computed mapping norm is at most
`1e-8`; otherwise classify it as `unresolved_line_search_stall`. Treating an
initial parity-valid readout as telemetry rather than an update-0 stop is an
explicit reconciliation of “replay from update 1” with “first parity-valid”;
approval accepts this update-1 boundary. The initial parity flag must still be
reported.

There is no update-count cap after the update-90 prefix. The 120-second wall is
the only continuation cap. A completed update is atomic: if the clock crosses
the wall during its calculation, finish and record that update, apply the
parity and mapping checks, and then apply the wall classification before
starting another update.

The 120-second wall applies separately to each case and each scientific pass.
It starts immediately before the initialization-state candidate calculations
and includes objective, partial-derivative, mapping, syndrome, line-search,
and projection work. It excludes process startup, package compilation, a
synthetic-only warm-up, input deserialization, diagnostic hashing, terminal-
bundle construction, output serialization, and all post-commit scoring; those
excluded quantities are timed separately and cannot alter a solver stop. Use
one Julia thread, one BLAS thread, and one OpenMP thread. Primary and
confirmation must run on the same recorded host and software environment. A
wall terminal is unresolved and cannot enter a stationarity or ceiling count.

For scale only, the retained 90-update native-control primary pass had mean
per-case times of about 0.89 seconds and observed maxima of about 7.14 seconds
at 6 dB and 5.15 seconds at 1.5 dB on its recorded host. Those exposed timings
motivate but do not scientifically validate the frozen 120-second continuation
wall.

## Deterministic second pass and tighter confirmation

The phrase “replay pass at `1e-10`” cannot mean that two runs stop at different
tolerances and nevertheless have identical terminal states. This card freezes
the following unambiguous protocol:

1. Restart the second pass from the sealed initialization and repeat the exact
   candidate calculation.
2. Require bit-exact equality of every allowed state, trial, scalar, decision,
   syndrome, and hash through the primary terminal. This is the deterministic
   replay gate for the primary scientific output.
3. If the primary stopped at `first_parity_valid`, the second pass must stop at
   the same update with the same hard decision and identical terminal bundle.
4. If the primary reached `norm(G_eta,Inf)<=1e-8`, record the identical state
   and mapping at that same update, then continue the unchanged descent while
   suppressing only the `1e-8` stop until one of these occurs: the mapping norm
   is at most `1e-10`, a parity-valid readout appears, the line-search grid is
   exhausted above `1e-10`, the wall is reached, or an invalid value appears.
5. The case receives
   `replay_confirmed_approximate_stationarity` only if the second pass reaches
   `norm(G_eta,Inf)<=1e-10` and its hard decision is exactly the same as at the
   primary `1e-8` terminal. The primary terminal remains the method outcome;
   the tighter endpoint is a separate confirmation terminal. Record and score
   both states, update counts, norms, and hashes.
6. A changed hard decision, parity-valid readout before `1e-10`, line-search
   exhaustion, wall exit, or invalid value during tighter confirmation is
   reported under its actual category and does not enter the approximate-
   stationarity count. A parity-valid readout reached only in this confirmation
   suffix is a diagnostic outcome: it does not count as a recovery by the
   primary method and does not enter that method's recovery numerator.
7. If the primary stopped at `unresolved_line_search_stall`, the second pass
   must reproduce the same accepted prefix, mapping value, 17 rejected trials,
   hard decision, and stall at the same attempted update. Any difference is a
   replay failure, not a second unresolved outcome.
8. If the primary stopped at `unresolved_wall_limit`, the second pass uses its
   own 120-second clock and must at least reproduce the complete primary
   accepted-update prefix and primary terminal checkpoint before its own wall.
   It then stops at that replay checkpoint; the scientific classification
   remains `unresolved_wall_limit`. Reaching its wall before that checkpoint is
   `invalid_wall_replay_prefix`. Wall cases never enter `q` even when the
   common prefix is bit-exact.
9. A primary `invalid_nonfinite` or other infrastructure-invalid case
   invalidates the population job before the scorer opens; it is not rerun as
   a numerical rescue.

During the tighter-confirmation suffix, apply the same precedence as the
primary pass: nonfinite failure, first parity-valid readout, `1e-10` mapping
tolerance, wall, then line-search exhaustion. Name the corresponding outcomes
`confirmation_first_parity_valid`,
`replay_confirmed_approximate_stationarity`,
`confirmation_unresolved_wall_limit`, and
`confirmation_unresolved_line_search_stall`; use
`confirmation_changed_hard_decision` when the tighter tolerance is reached but
the hard decision differs from the primary-tolerance hard decision.

Thus primary/replay equality is exact on the complete primary prefix, while
the additional second-pass suffix is explicitly a stricter confirmation, not
an allegedly identical replay terminal.

## Candidate-only Phase A and immutable commit

Phase A receives only:

- the graph and frozen adjacency order;
- the clipped vector of channel LLRs and initialization;
- the frozen objective, diagonal, line-search, projection, mapping, stop, and
  wall constants;
- an opaque case key; and
- the truth-stripped predecessor-prefix identities needed for reproduction.

The candidate executable must have throwing stubs for transmitted bits,
transmitted symbols, truth comparison, coded-bit errors, recovery labels, BP,
the exact recurrence, teacher directions, and source-result columns outside
the allowed projection. A capability audit must prove those paths are absent
before a case opens.

Before launch, the prepared source, executable, packet schema, packet manifest,
independent verifier, operating-system launch boundary, queue, and unused
output roots must be sealed in one `SOURCE_READY` manifest. The execution
approval is prospective because these artifacts do not exist at card-
registration time. Scientific launch is permitted only if an independent
source-only audit proves that every artifact implements this card, reproduces
the retained synthetic and source-prefix fixtures, and matches `SOURCE_READY`
after sealing. A failed source audit ends this experiment ID; it does not
authorize an unreviewed repair.

After both passes complete for all 400 cases, Phase A writes an immutable
`PHASE_A_COMMIT` that binds the source/config hashes, executable/source freeze,
software and host identity, case keys, complete primary and second-pass
manifests, trace hashes, terminal hashes, terminal classifications, work
tables, and candidate-only summary. The post-commit scorer may open only after
an independent verifier validates this commit. The scorer cannot replace a
state, stop reason, update count, hard decision, syndrome, or candidate-only
classification.

The transmitted word and BP are absent from Phase A. Phase B is the only phase
permitted to open truth or any retained BP artifact. This card requires no
BP-derived score and does not authorize running BP; the scorer records the
retained BP artifact identity and whether it was accessed, but leaves its
contents unread. Adding a BP performance field or BP execution later requires
a separate amendment.

## Candidate-only terminal fields

For every case, before the scorer opens, retain the following separately for
the primary terminal and the second-pass terminal, keyed by pass, update, and
state hash. If the second pass ends at the reproduced primary checkpoint, keep
both terminal labels even when their state hashes are equal:

- opaque case key and population label held outside the solver;
- pass-specific stop reason for the primary terminal and for the second-pass
  terminal, plus the final committed case classification;
- attempted updates, accepted updates, and line-search trials, separately for
  primary and second pass;
- primary-terminal and confirmation-terminal
  `norm(G_eta,Inf)`, with the declared `1e-8` and `1e-10` tolerances;
- primary-terminal and confirmation-terminal state, hard-decision, syndrome,
  mapping, and trace hashes;
- parity syndrome weight at that terminal state;
- `widetilde J_C` at that terminal state;
- count of interior coordinates using the exact predicate `abs(x_i)<1` at
  that terminal state;
- counts at `-1`, at `+1`, and exactly zero at that terminal state;
- accepted-step history, objective change, and trial count;
- complete source-prefix verification outcome and common-prefix length;
- solver seconds, objective evaluations, partial-derivative evaluations,
  mapping evaluations, projections, syndrome evaluations, and allocation/
  peak-memory diagnostics; and
- a monotonicity assertion over every accepted endpoint.

No truth-dependent name or value may occur in the Phase-A schema.

## Post-commit scorer Phase B

Only after the immutable Phase-A commit passes independent verification may a
separate scorer load the transmitted word. Let
`b_i^star` be the transmitted bit and
`s_i^star=1-2*b_i^star` its sign representation. For every retained terminal,
the scorer independently recomputes the hard decision and syndrome from that
state, verifies that both match Phase A, and adds the requested fields
separately.

Before scoring any mechanism field, Phase B must verify that the transmitted
word itself has zero syndrome under the sealed parity-check matrix. Failure is
an invalid truth/input identity, not a scientific decoder outcome.

For each retained terminal, the scorer adds:

1. coded-bit errors against the transmitted word;
2. transmitted-word recovery and wrong-valid-codeword indicators;
3. wrong bits split by the number `nu_i` of violated incident checks:
   `nu_i=0,1,2,3`;
4. checks split by the number `r_c` of wrong incident bits:
   `r_c=0,1,2,3+`;
5. the exact total `sum_c r_c`, retained in addition to the rolled `3+` bin;
6. wrong bits whose channel LLR strictly favors the transmitted bit, defined
   by `s_i^star*L_i>0`; an exact-zero LLR is in neither sign-favoring class;
7. `widetilde J_C(s^star)` at the transmitted-word vertex; and
8. `widetilde J_C(x_terminal)-widetilde J_C(s^star)`.

The scorer must enforce these invariants:

```text
sum(wrong-bit violated-check bins 0:3) = coded-bit errors
sum(check wrong-bit bins 0,1,2,3+) = 5100
sum_c r_c = 3 * coded-bit errors
syndrome weight = count of checks with odd r_c
wrong bits whose LLR favors truth <= coded-bit errors
```

It must also retain the unrolled check occupancies `r_c=0,...,6` internally so
the rolled `3+` bin and incidence identities can be independently reproduced.
The scorer cannot alter the committed candidate classification.

## Frozen predictions

These predictions are fixed before any candidate case opens. For a replay-
confirmed tolerance case, they apply to both the primary `1e-8` method terminal
and the separate `1e-10` confirmation terminal, not to the already observed
update-90 state. The hard-decision-dependent fields must agree because an
unchanged hard decision is part of the confirmation gate. The objective
inequality must pass independently at both terminal states.

### 1.5 dB population

The frozen prediction is:

- all 200/200 cases receive
  `replay_confirmed_approximate_stationarity`;
- all 200 primary and confirmation hard-decision estimates differ from the
  transmitted word;
- every case has between 600 and 850 coded-bit errors, inclusive;
- for every case and both tolerance terminals,
  `widetilde J_C(x_terminal)>widetilde J_C(s^star)`;
- for every case, at least half of its wrong bits have `nu_i=0` violated
  incident checks;
- for every case, more checks have exactly two wrong incident bits than have
  exactly one wrong incident bit; and
- no case first reaches the transmitted word after update 90.

The retained update-90 error range was 534 to 874, so the 600-to-850 statement
is a new terminal-state prediction, not a description of the retained result.
Any denominator shortfall, unresolved case, or value outside a universal
per-case prediction falsifies that prediction; it is not averaged away.

### 6 dB population

The retained source has 193 cases with a first transmitted-word recovery by
update 90 and seven cases without one. The frozen prediction is that all seven
fall into exactly one of the following two categories and that both categories
are nonempty:

- a late primary-pass transmitted-word recovery after update 90; and
- a replay-confirmed wrong approximate-stationarity terminal with few coded-
  bit errors.

“Few” is descriptive and therefore cannot serve as a numerical pass gate.
Report the complete per-case error counts. Any wrong valid readout, unresolved
line-search stall, unresolved wall stop, changed-hard-decision confirmation,
invalid case, empty predicted category, or total other than seven across the
two bins falsifies the frozen split prediction and must still be reported.

## Counterfactual interpretation

- If 1.5 dB produces 200 replay-qualified terminals satisfying both `G_eta`
  tolerances with zero transmitted-word recoveries, then the observed 0/200 is
  no longer attributable merely to the old 90-update cap for this frozen
  decoder protocol.
- If a primary pass reaches the transmitted word during the continuation, this
  exact method has a recovery count of at least 1/200 at that level and the
  universal 1.5 dB wrong-stationarity prediction is false. A transmitted-word
  readout reached only in the tighter-confirmation suffix is reported as a
  separate diagnostic and does not count toward the method's recovery total.
- If a case exhausts the line-search grid above tolerance, it is evidence
  about the registered finite step grid, not evidence of stationarity.
- If a case reaches the wall, the case is unresolved; no ceiling or
  stationarity statement may use it.
- A terminal satisfying both finite `G_eta` tolerances supplies a point on
  which a later barrier certificate could act. It does not show that every
  continuous or finite-step non-increasing path is trapped.

## Work, runtime, and memory budget

The candidate's persistent optimization state remains one scalar per bit.
Graph adjacency and temporary check-local quantities are `O(E)`. One partial-
derivative calculation, one syndrome calculation, one mapping calculation,
and each of the at most 17 projected line-search trials are `O(E)` on the
bounded-degree graph. Therefore each attempted update is `O(E)` with a fixed
17-trial constant. The total number of attempts is wall-limited rather than
fixed.

Algorithm-core storage is limited to the `O(E)` graph/adjacency data, `O(n)`
current and trial vectors, `O(n)` partial derivatives/direction/mapping
workspace, and scalar/check-local work arrays. Retaining a full state vector
for every update is forbidden. The trace keeps per-update scalars and hashes;
only the initialization, primary terminal, second-pass terminal, and the
primary checkpoint reproduced inside the second pass may retain full vectors.
Diagnostic table size may grow with the number of attempted updates, but it is
reported separately and is not persistent decoder state.

Report, separately for each pass and case:

- attempted and accepted updates;
- objective and partial-derivative evaluations;
- mapping and syndrome evaluations;
- projected trials, projections, and strict-decrease acceptances;
- scalar accumulations, check products, and edge reads under the inherited
  work-counting convention;
- elapsed candidate time, allocation, and peak resident memory; and
- serialized diagnostic bytes, excluded from the algorithm-core work count.

Post-commit scoring and report generation are not decoder inference work and
must be timed separately. Raw update counts are not compared with BP
message-passing iterations under this card.

## Correctness and identity gates

Before any case opens, execution must fail closed unless all of these pass:

1. Every pinned predecessor object and input identity matches this card.
2. The exact source card and execution approval are present and hash-bound.
3. The truth-stripped candidate packet contains no transmitted-word, BP,
   recurrence, teacher, error, or recovery capability.
4. The new scalar objective and partial derivatives match the retained native
   control source; finite differences pass on frozen synthetic fixtures.
5. Independently verify that every diagonal entry equals `13.6/n`, is finite,
   and is strictly positive; then verify the projected direction, trial grid,
   projection, strict-decrease rule, readout, and syndrome on frozen fixtures.
6. The allowed-field source-prefix projection and hashes are built and sealed
   before launch without case selection.
7. One Julia, BLAS, and OpenMP thread are enforced, and the primary and second
   pass share one recorded host/software environment.
8. Output paths are unused and immutable; overwrite and resume are forbidden.

During and after execution:

9. Every available source-prefix field matches exactly on the common prefix.
10. Every second-pass value through the primary terminal matches the primary
    pass bit for bit.
11. Every reported scalar is attached to the state from which it was computed.
12. Accepted endpoint objectives are strictly decreasing; no automatic rescue,
    tolerance change, larger trial grid, retuning, or case retry is allowed.
13. The Phase-A commit is sealed and independently verified before truth opens.
14. The scorer reproduces every retained terminal readout and syndrome and
    passes every histogram invariant.
15. All 200 cases at each level appear exactly once in both passes and in the
    scorer; no denominator substitution is permitted.
16. Primary and post-commit reports reproduce from their immutable tables.

An identity, isolation, nonfinite, overwrite, replay-prefix, or denominator
failure invalidates the affected job and yields no scientific claim. A wall or
line-search terminal is instead a validly measured unresolved outcome if all
identity and replay gates pass.

## Primary and secondary metrics

The primary recovery metric is the number of **primary method terminals** whose
hard-decision estimates equal the transmitted word out of all 200 cases at each
level. A transmitted-word equality reached only at a second-pass confirmation
terminal is a separate diagnostic and is excluded from this numerator. The
primary mechanism diagnostic is the complete per-level count in each mutually
exclusive Phase-A terminal category:

```text
first_parity_valid
replay_confirmed_approximate_stationarity
unresolved_line_search_stall
unresolved_wall_limit
confirmation_first_parity_valid
confirmation_unresolved_line_search_stall
confirmation_unresolved_wall_limit
confirmation_changed_hard_decision
invalid_infrastructure_or_numerics
```

Phase B separately partitions every `first_parity_valid` or
`confirmation_first_parity_valid` terminal into `transmitted_word_equal` and
`wrong_valid_codeword`. Those are scorer overlays, not additional Phase-A
terminal categories. Post-commit primary-pass transmitted-word recoveries are
reported separately from parity validity, and confirmation-only transmitted-
word equalities are reported in their own field. The main 1.5 dB result is the
pair

```text
primary-pass transmitted-word recoveries / 200
replay-confirmed wrong approximate-stationarity terminals / 200.
```

Secondary metrics are the requested error/check histograms, terminal and truth
objective values and their difference, syndrome weight, interior-coordinate
count, update counts, line-search work, runtime, and memory. Report the full
per-case table and population distributions; do not reduce the mechanism
fields to a zero-recovery count.

There is no confirmatory p-value or confidence interval. The populations and
their update-90 outcomes were already exposed.

## Prune, continue, and failure rules

- **Close this exact protocol at 1.5 dB:** zero primary-pass transmitted-word
  recoveries, all 200 cases replay-qualified at the tighter tolerance with
  wrong hard decisions, and no invalid or unresolved cases.
- **Measured recovery:** one or more primary-pass transmitted-word recoveries
  establishes at least that observed count out of 200 for this protocol and
  falsifies the frozen 0/200 prediction. Confirmation-only equality is retained
  as a diagnostic but does not satisfy this rule.
- **Unresolved:** any line-search stall above tolerance, wall stop, or failed
  tighter confirmation is reported as unresolved and cannot be converted into
  stationarity by interpretation.
- **Invalid:** any correctness, isolation, identity, replay, nonfinite, or
  denominator failure invalidates the affected job. No tuning or repair may be
  run under this experiment ID.
- **Later work:** a complete-valid set of wrong numerical stationary terminals
  may be proposed as input to a separately approved barrier certificate. This
  card authorizes neither that certificate nor an escape step.

After a complete-valid result, the compact research tree and detailed path
explainer must be updated with the exact category counts, mechanism fields,
case scope, and claim boundary. A failed or unresolved result must also be
recorded; reporting cannot omit it because the prediction failed.

## Claim boundary and explicit conflicts

A valid 0/200 at 1.5 dB together with 200/200 replay-qualified terminals that
satisfy both finite `G_eta` tolerances closes **this frozen decoder protocol on
this exposed population**: this objective, initialization, scalar diagonal,
17-point strict-decrease step grid, projection, primary/tighter tolerances,
first-valid stop, and wall rule. Define

```text
q = number of 1.5 dB cases, out of 200, that are post-commit wrong
    primary method terminals at norm(G_eta,Inf) <= 1e-8 and whose separate
    second pass reaches norm(G_eta,Inf) <= 1e-10 with the same hard decision.
```

The result fixes this sample value of `q` for the registered protocol. It does
not establish an asymptotic ceiling, exact mathematical stationarity, a
positive objective rim, or impossibility of continued recovery under another
rule.

The requested phrase “fixes `q` for the fixed-matrix monotone class” conflicts
with the simultaneous instruction that the result closes this method and step
rule only. A finite population and one scalar matrix/step grid cannot close all
fixed positive-definite matrices or all monotone step sequences. This card
therefore does **not** authorize that class-wide claim. Approval accepts the
narrow protocol-specific definition of `q`; a broader class claim would need
its own mathematical argument or registered family-wide experiment.

Likewise, `norm(G_eta,Inf)<=1e-10` is a registered finite-tolerance result, not
an irrebuttable proof that `G_eta=0`. The finite-tolerance wording in the
requested prediction is preserved operationally but narrowed scientifically
here.

No result under this card closes:

- another fixed matrix;
- another step grid, line search, or stopping sequence;
- a state-dependent matrix;
- momentum, heavy-ball, Nesterov, restart, perturbation, or nonmonotone update;
- a different objective or coordinate system;
- the two-hop family; or
- native exact sum-product BP.

One post-commit-confirmed **primary-pass** transmitted-word recovery establishes
at least 1/200 for this method on that level. A recovery first seen only in the
tighter-confirmation suffix does not. Neither establishes cross-SNR
performance.

## Approval boundary

The present instruction registers this card only. Nothing executes now.

After reviewing the complete file and the SHA-256 supplied in the handoff, the
single exact authorization text is:

```text
approve RQ2-JC-PROJECTED-STATIONARITY-001-EXECUTION-001 card_sha256=<handoff SHA-256>
```

That approval is valid only for the byte-identical card and the fail-closed
sequence defined here. It does not authorize amendments, case substitution,
two-hop work, new populations, retuning, an uphill update, or a barrier
experiment.
