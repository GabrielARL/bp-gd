# Proposed `J_C` mean-coordinate barrier diagnostic

> **Status: proposed, unapproved, and inert.** The provisional experiment ID is
> `RQ2-JC-MEAN-COORDINATE-BARRIER-DIAGNOSTIC-001`. This file is a design record,
> not a registration, activation, source implementation, case reservation, or
> result. It authorizes no access to retained or fresh scientific inputs, no
> decoder execution, no truth or BP scoring, and no perturbation experiment.

## Activation firewall

This diagnostic is a conditional successor, not an amendment to
`RQ2-TWO-HOP-POSITIVE-METRIC-001`. It may be registered, approved, or
activated only after all of the following have happened in order:

1. `RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B` has completed validly and passed
   every registered scientific gate at both 6 dB and 1.5 dB.
2. The unchanged registered Stage-C projected-Armijo construction has then
   completed validly and failed a scientific recovery gate. An operational,
   provenance, trace-integrity, nonfinite-value, box, or inference-isolation
   failure is not a qualifying scientific failure.
3. This diagnostic has received its own user approval under a new experiment
   ID, with its exact source, arithmetic, case counts, case ranges, manifests,
   and primary/replay protocol frozen before any diagnostic input is opened.
4. New untouched diagnostic ranges have been reserved at both signal-to-noise
   levels. They may not overlap any development, screen, anchor, transfer, or
   confirmation range whose generated input, trace, statistic, score, or
   outcome has already been opened. They also may not reuse the Stage-C ranges
   `72113:72160` or silently repurpose the Stage-D/terminal reserve
   `72161:72560`.

The proposed diagnostic denominator is 24 newly reserved cases at 6 dB and 24
newly reserved cases at 1.5 dB, all processed without case selection. The
actual frame identities are deliberately unassigned in this inert card. A
later registration must supply them and prove that they are untouched.

If Stage B fails scientifically, Stage C is never admitted and this card
remains inapplicable. If Stage C passes, this failure diagnostic is also
inapplicable. Nothing in this file moves either existing stage forward.

## One prospective question

On newly exposed development cases where the unchanged Stage-C update stops
with an incorrect hard-decision estimate, is its terminal objective level in a
wrong-sign path component of a `J_C` sublevel set that has a rigorously
positive rim in incident-edge-mean coordinates, and can none of the 13
registered terminal trial endpoints jump outside that rim at an objective
value no greater than the terminal value?

A complete pass would establish a narrow obstruction:

- a continuous path beginning at that terminal state cannot both keep `J_C`
  non-increasing and reach the transmitted sign pattern; and
- the registered finite terminal proposals do not evade that obstruction by
  landing beyond the rim at a lower or equal endpoint.

It would **not** prove that every gradient-based method fails, that every
finite-step descent rule is trapped, that native BP climbs this particular
rim, or that allowing one uphill update restores recovery. The last statement
requires a separate paired intervention after this diagnostic passes.

## Closest evidence and nonduplication

- `RQ2-GD-TRAJECTORY-DIAGNOSIS-001` classified trajectories for the
  recurrence-residual objective `H`; it did not certify a well or rim of
  unchanged `J_C`.
- The dormant Stage-C synthetic late-stall fixture proves only an update-rule
  incompatibility. Its raw direction has
  `g' d = -2.8535225922657196e-4`, yet all 13 projected displacements have
  positive `g' delta`. The registered fixed-diagonal projected-gradient
  mapping norm is `0.01801510782386342`, and a feasible point lowers `J_C` by
  `4.615221447788059e-5`. That fixture is therefore not evidence that its
  terminal state is box-stationary or is a local minimum. It opened no
  scientific case.
- `R5-NGDBF-AWGN-001` already closed noisy hard-bit gradient-descent bit
  flipping at 1.5 dB on its registered scope, and
  `R5-TRAINED-RESTARTED-PG-AWGN-001` already closed the tested ten-start,
  100-update projected-gradient recovery route there. This card introduces
  neither bit noise nor a random or trained restart.
- The registered exact-recurrence proxy often reached a zero-syndrome readout
  without a positive `J_C` endpoint change. That retrospective result prevents
  treating occasional `J_C` increases as the explanation by itself. This card
  instead asks whether a specified wrong terminal component has a certified
  topological barrier.

The only changed operation is measurement: the unchanged Stage-C trajectory
is followed by an independently checked, candidate-only certificate. The
diagnostic does not advance a replacement state, alter a coefficient, accept
an update, or score decoder performance.

## State, quotient, and objective

Let `z in [-1,1]^E` be the Stage-C directed-edge state. For bit `i`, let

```text
x_i = (1 / degree(i)) * sum(z_e for e incident on i).
```

The calculation must use the objective source's centered summation procedure
for this arithmetic incident-edge mean. Write `x = C z` and
`Q = [-1,1]^n`. With the registered clipped channel-LLR vector `L`, parity
weight `w_p = 2`, and binary weight `w_b = 0.2`, unchanged `J_C` factors as

```text
J_C(z) = F(C z),

F(x) = -(L' x)/(2n)
       + (w_p/n) * sum_c (1 - product(x_i for i in c))^2
       + (w_b/n) * sum_i (1 - x_i^2)^2.
```

Consequently, every within-bit zero-mean edge displacement in `ker(C)` is
exactly flat for `J_C`. An isolated strict well in the full `E`-dimensional
edge state is impossible. This card therefore identifies edge states with the
same incident-edge means and makes every well, rim, distance, sign, Hessian,
and sublevel statement in the quotient coordinate `x`. A full-edge path maps
continuously to a mean-coordinate path; movement only along a flat equivalence
class changes neither `F` nor the hard-decision estimate.

## Three distinct claims

### 1. Registered line-search barrier

At a terminal stalled update, independently recalculate unchanged `J_C`, its
partial derivatives, the Stage-C direction, componentwise projection, and all
13 trial states for `alpha_b = 2^(-b)`, `b = 0,...,12`. First require equality
or rigorous containment against every corresponding stored trace value; then
use the independently recalculated values, not trace-supplied partial
derivatives, to recalculate the registered Armijo test with constant `1e-4`.
This claim passes only when all 13 trials are finite, all source and state
links match, no trial is accepted, and the decoder stops because the
registered trial set was exhausted rather than because the 30-attempt cap was
reached.

This is an operator-stop fact only. It must be reported as
`registered_line_search_barrier`, never as a landscape well. The diagnostic
must also calculate and report the registered fixed-diagonal projected-gradient
mapping without applying it. A nonzero mapping is reported as
`projection_action_mismatch` and vetoes any claim that the stored terminal
state itself is box-stationary. A lower feasible point must be reported, but
by itself does not refute stationarity because a distant point can be lower
than a local minimum. Neither measurement replaces the continuous sublevel
test below.

### 2. Certified continuous sublevel barrier

Let `z_0` be the committed terminal edge state and `x_0 = C z_0`. Use the
fixed, prospective radius list

```text
R = (2^0, 2^-1, ..., 2^-16)
```

in that order. For each `r in R`, define

```text
B_r = {x in Q : ||x - x_0||_2 <= r}.
```

All bounds must use a frozen directed-rounding interval implementation and a
frozen precision. Treat each stored binary64 input as its exact represented
number; do not use an unbounded floating-point estimate as a proof.

For each radius, the independent certificate must:

1. enclose `F(x_0)` by `[L_0,U_0]`;
2. enclose the minimum-norm box-KKT residual. With
   `0 in grad(F)(x_0) + N_Q(x_0)` as the sign convention, choose
   `nu in N_Q(x_0)` to minimize the residual and certify
   `||grad(F)(x_0) + nu||_2 <= epsilon`;
3. enclose every nonzero Hessian entry over the axis-aligned coordinate box
   containing `B_r`; and
4. certify the Gershgorin lower bound

```text
mu_r = min_i(lower(H_ii)
             - sum_{j != i} max(abs(lower(H_ij)),abs(upper(H_ij)))) > 0.
```

For a check `c`, with `p_c = product_{i in c} x_i`,
`q_i = product_{k in c, k != i} x_k`, and
`r_ij = product_{k in c, k != i,j} x_k`, the independently implemented
check-local Hessian contributions are

```text
H_ii += (2 w_p/n) q_i^2,
H_ij += (2 w_p/n) (q_i q_j - (1-p_c) r_ij),
H_ii += (4 w_b/n) (3 x_i^2 - 1)  [binary term].
```

No dense Hessian may be formed. The interval program must enumerate graph
incidence independently of the production objective path and must be checked
against analytic partial derivatives by finite differences on synthetic
fixtures before registration.

Strong convexity on `B_r` and the box normal-cone inequality then give, for
every feasible `y` on the spherical boundary,

```text
F(y) >= L_0 - epsilon*r + (mu_r/2)*r^2.
```

Define the certified rim gap

```text
Delta_r = L_0 - epsilon*r + (mu_r/2)*r^2 - U_0.
```

The continuous barrier passes only if `Delta_r > 0`. It must also satisfy the
candidate-only sign-margin gate

```text
r < min_i abs(x_0[i]),
```

so every hard-decision sign is constant throughout `B_r`. The selected radius
is the first radius in the frozen list that satisfies all candidate-only
interval, curvature, positive-gap, and sign-margin gates. There is no
post-truth fallback to another radius.

These inequalities prove that the path component of
`{x in Q : F(x) <= U_0}` containing `x_0` lies inside `B_r`. They also prove
that `B_r` contains a unique constrained local minimizer, although `x_0`
itself may only be an approximate point in that well. Do not call `x_0`
stationary unless its interval KKT residual separately proves that statement.

After the candidate-only bundle has been committed, the scorer must verify
that the terminal hard-decision estimate differs from the transmitted word,
that the transmitted sign vertex is outside `B_r`, and that its rigorously
enclosed objective satisfies

```text
upper(F(x_truth)) < L_0.
```

The last gate separates a local barrier from an objective that simply ranks
the transmitted vertex above the terminal point. If any interval overlaps a
decision boundary, report `uncertified`; do not round it into a pass or treat
failure to certify as evidence that no barrier exists.

### 3. Discrete no-lower-jump closure

The positive rim blocks continuous non-increasing paths. A finite-step method
could still cross a higher interior segment and land outside the rim at a
lower endpoint. Therefore, independently map each of the 13 committed
terminal projected trials to its mean coordinate and rigorously enclose its
distance and objective.

For every trial endpoint certified to lie outside `B_r`, require

```text
lower(F(x_trial)) > U_0.
```

An outside endpoint whose objective interval is no greater than or overlaps
the terminal interval fails closure. Report a rigorously lower or equal
outside endpoint as `lower_endpoint_jump_exists`; that result routes the next
experiment toward step or projection geometry, not permission to climb. An
ambiguous inside/outside or objective comparison is `uncertified`.

This closure covers exactly the frozen 13 Stage-C terminal proposals. It says
nothing about every imaginable nonlocal descent step. If a later card wants
to include the proposed fixed-diagonal safeguard or another proposal family,
that exact family must be declared and closed separately before an uphill
necessity claim is made.

## Candidate-only commit before truth or BP scoring

The registered implementation must split execution into two processes with a
one-way artifact boundary.

### Phase A: candidate and certificate

The candidate process may receive only the parity-check graph, vector of
channel LLRs, frozen coefficients, frozen decoder constants, and an opaque
case key. It must have no interface for transmitted bits, BP outputs, teacher
directions, recovery labels, signal-to-noise labels, frame numbers, or
population membership. BP must not be called by initialization, dynamics,
stall detection, radius selection, certification, or proposal evaluation.

Before any truth or BP record is made available, seal and hash an immutable
bundle containing at least:

- source, environment, graph, coefficient, candidate-input/LLR-artifact, and
  constant identities, explicitly excluding transmitted payload bits;
- the initial edge state and complete unchanged Stage-C state, objective,
  partial-derivative, matrix-direction, projection, and 13-trial records;
- terminal readout, parity syndrome, zero-tie count, and stop reason;
- `x_0`, the fixed radius list, KKT-residual bounds, sparse Hessian intervals,
  Gershgorin bounds, rim-gap bounds, sign margins, selected-radius decision,
  and the 13 endpoint distance/objective comparisons; and
- primary and independent-replay hashes with bit-exact equality for every
  discrete trace field and deterministic equality of every directed interval
  endpoint.

The phase-A manifest must assert that truth and BP inputs were absent and must
be committed before phase B can open.

### Phase B: scorer only

The scorer may open the transmitted word and an independently calculated
native exact sum-product BP output only after it verifies the phase-A hash.
It may label transmitted-word recovery, wrong valid words, the transmitted
vertex objective, and paired BP recovery. It may not alter a radius,
certificate, trace, terminal state, or classification produced in phase A.
The continuous barrier proof itself does not require BP; BP is a post-commit
baseline only.

## Measurements and exact gates

Report every count separately at 6 dB and 1.5 dB with denominator 24. For all
48 cases report terminal reason, recovery, parity validity, zero ties, all
three hierarchy levels, selected radius, `epsilon`, `mu_r`, `Delta_r`, truth
objective difference, number of outside registered endpoints, and every
classification below.

A case is `full_barrier_case` only when all of these pass:

1. source, input, isolation, trace, interval-arithmetic, primary/replay, and
   manifest gates;
2. a wrong, non-tied terminal hard-decision estimate produced by an exact
   13-trial registered line-search stall;
3. a selected quotient-coordinate radius with `mu_r > 0`, `Delta_r > 0`, and
   constant hard-decision signs throughout `B_r`;
4. the transmitted sign vertex lies outside `B_r` and has rigorously lower
   `J_C` than the terminal point; and
5. every registered outside trial endpoint is rigorously higher than the
   terminal point.

Use these nonexclusive diagnostic labels rather than collapsing failures:

- `no_registered_terminal_stall`;
- `registered_line_search_barrier`;
- `projection_action_mismatch`;
- `continuous_barrier_certified`;
- `continuous_barrier_uncertified`;
- `lower_endpoint_jump_exists`;
- `truth_not_lower`;
- `full_barrier_case`; and
- `invalid_no_science`.

The diagnostic admits only the drafting of a separate perturbation card if
there is at least one `full_barrier_case` at 1.5 dB, every case-level result is
accounted for, and no integrity failure occurred. Zero full cases closes the
uphill-escape rationale on this diagnostic sample; it does not prove that no
such `J_C` component exists elsewhere. A lower outside endpoint routes to a
non-uphill jump/step study. An operational or integrity failure produces no
scientific conclusion and permits only an unchanged operational repair under
the diagnostic ID.

## Work accounting

The diagnostic is not decoder runtime and its cost must be reported
separately. For check degree bounded by the registered graph family:

- each objective, partial-derivative, mean-coordinate, and 13-trial audit is
  `O(E)`;
- sparse interval Hessian construction costs
  `O(sum_c degree(c)^2) = O(E)` under the fixed degree bound;
- 17 fixed radii and 13 fixed terminal proposals are constants, so the full
  certificate is `O(E)` time and `O(E)` working storage per streamed case; and
- a dense `n x n` or `E x E` Hessian, unbounded radius refinement, random
  search, restart sweep, or case-dependent precision increase is forbidden.

Record wall time, allocations, peak resident memory, serialized trace bytes,
and independent-check time for candidate dynamics and certification
separately. Use one thread and deterministic replay. Post-commit BP scoring is
accounted separately and may not be included in the candidate's inference
budget.

## Separate successor required for one uphill perturbation

This diagnostic contains no escape update. Even after a pass, a deterministic
one-shot continuous-state perturbation requires a new experiment ID, a new
prospective card, explicit user approval, frozen source, and new untouched
development, anchor, and confirmation ranges. No range from this diagnostic
or the existing Stage-C/Stage-D cards may be reused or silently reassigned.

That future card must, before opening its cases:

- freeze one deterministic continuous-state proposal and its amplitude using
  only the graph, channel LLRs, current state, `J_C`, locally calculated
  partial derivatives or prospectively declared local curvature, and the
  already sealed simple matrix if selected;
- prohibit BP, teacher, transmitted bits, frame identity, signal-to-noise
  label, recovery outcome, randomness, hard-bit noise, and restart selection
  from the proposal and trigger;
- trigger at most once at the first prospectively declared candidate-visible
  stall/certificate condition and count the perturbation as one of the 30
  attempted updates;
- calculate the identical proposal in paired control and intervention arms;
  the control retains the unchanged non-increase rule, while the intervention
  alone may apply the proposal once and then resumes the unchanged frozen
  two-hop descent rule;
- require, for the narrow causal claim, a rigorously higher proposal endpoint
  outside the case's certified rim, a wrong control terminal, and recovery by
  the intervention. A lower endpoint is a jump mechanism, not evidence that
  permission to increase `J_C` was necessary; and
- retain deterministic replay, no wrong valid codeword, no zero-readout tie,
  and bounded-degree `O(E)` work.

The perturbation proposal must itself remain `O(E)` and may not add a restart,
parameter sweep, repeated kick, population search, or BP-guided choice. A
development success would still not be a terminal performance result.

## Relationship to the terminal recovery goal

This proposed diagnostic changes no live performance gate. The checked-in
Stage-D card and configuration for `RQ2-TWO-HOP-POSITIVE-METRIC-001` still
contain the older 190/200 minimum, at-most-10 deficit, and paired-interval
threshold because they remain hash-bound upstream campaign members. On
7 November 2026, the user approved
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-D-BP-MINUS-30-CONTRACT-ALIGNMENT-001`,
but its application is deliberately deferred until Stage B and Stage C are
both complete-valid, immediately before Stage-D freeze and execution
authorization. This unapproved, inert barrier proposal neither applies that
amendment nor changes any current source, stage, input, or scientific gate.

The approved future Stage-D alignment uses untouched 200-case sets at both
6 dB and 1.5 dB, with `C_s` the candidate count after at most 30 attempted
updates and `B_s` native exact sum-product BP at its first zero syndrome or 80
message-passing iterations. Each level must satisfy

```text
C_s >= B_s - 30.
```

The paired candidate-versus-BP interval remains a reported diagnostic rather
than a pass threshold. The registered exact-zero lower-endpoint comparison,
no-wrong-valid-codeword rule, no exact-zero readout tie, deterministic replay,
inference isolation, and bounded-degree `O(E)` work remain pass gates. BP is
forbidden at inference. This proposed barrier diagnostic remains unapproved
and inert: it tests and changes none of those gates and would only decide
whether spending new cases on one specifically uphill intervention is
mechanistically justified.

## Claim boundary if eventually run

The strongest permitted diagnostic conclusion would be:

> On `k/24` newly registered 1.5-dB development cases, the unchanged Stage-C
> update ended at a wrong, non-tied 13-trial stall whose incident-edge-mean
> `J_C` sublevel path component had a directed-rounding positive-rim
> certificate, while none of the registered terminal trial endpoints provided
> a lower or equal jump outside that rim. The transmitted vertex had lower
> `J_C`. Therefore a continuous non-increasing `J_C` path and the registered
> finite terminal proposals could not reach the transmitted sign pattern from
> those terminal states.

The denominator, signal-to-noise ratio, graph and case identities, 30-attempt
budget, interval implementation, radius grid, and exact proposal family must
appear with that sentence. Do not shorten it to “gradient descent can never
correct the error” and do not claim that an uphill perturbation works until a
separate approved paired experiment demonstrates it.
