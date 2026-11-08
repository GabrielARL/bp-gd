# Prospective SNR threshold audit for the differentiable convex parity cost

Experiment ID: `RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001`

Registration date: 8 November 2026

Status: **registered and authorized by the user's 8 November 2026 instruction
to proceed with the strongest differentiable cost function and find the SNR at
which it works; no outcome had been opened when this card was written**

## Research objective branch and question

This card asks for the lowest tested physical `Es/N0` at which the strongest
currently implemented end-to-end differentiable optimization path meets the
active BP-minus-30 recovery target under exactly 30 candidate updates. The
candidate is the frozen convex squared-distance-to-parity-polytope objective
with the frozen feasible accelerated projected-gradient schedule.

This is an exposed-development SNR threshold audit. It is not a confirmation
result, does not alter the active two-hop Stage-B chain, and must not open the
reserved confirmation frames `72161:72560` or any other Stage-B input.

“Works” has one primary meaning in this card. At a tested SNR `s`, let `C_s`
be candidate transmitted-word recoveries and let `B_s` be exact sum-product BP
recoveries on the same cases. A 200-case fine-grid level passes when

```math
C_s \ge B_s-30.
```

The absolute count `C_s >= 190` is reported as a stricter secondary reference,
not substituted for the active goal. A 24-case coarse level uses the
provisional scaled screen `C_s >= B_s-4`; it locates a refinement interval and
is not a performance claim.

## Closest retained experiments and nonduplication

`RQ2-CONVEX-PARITY-DISTANCE-001` used the same objective with fixed-step
projected gradient and recovered `0/200` at 1.5 dB through update 6000, while
remaining optimization-unresolved. It did not establish a global optimum or
an SNR threshold.

`RQ2-CONVEX-PARITY-DISTANCE-ACCELERATED-001` froze the solver used here but
pruned it at a synthetic `1e-8` projected-stationarity source gate. This card
does not reopen that failed stationarity claim. It asks the distinct fixed-work
decoding question: can a parity-valid transmitted-word readout occur within 30
accelerated updates at a higher SNR? The synthetic source gate and its
44,031/44,031 correctness assertions remain evidence for source identity, not
for population recovery.

The native compound `J_C` control, ADMM, BP recurrence, two-hop metric, local
curvature schedule, random restart, and momentum families are not candidate
arms. There is no solver selection after an outcome opens.

## Frozen candidate fingerprint

For positive channel LLR `L_i` favoring bit zero, the caller-visible state is
one scalar `b_i in [0,1]` per bit and

```math
b_i^{(0)}=\frac{1-\tanh(L_i/2)}{2}.
```

With `S_c` selecting check `c` and `P_c` its exact even-parity polytope, the
unchanged normalized objective is

```math
F(b)=\frac{1}{n}\left[L^\mathsf{T}b
 +48\sum_c \operatorname{dist}^2(S_cb,P_c)\right].
```

The implementation calculates the partial derivatives of `nF`; the factor
`1/n` does not change the path. The exact degree-six parity-polytope projector,
the box, penalty `lambda=96`, global curvature `288`, and accelerated recurrence
are imported without modification. With zero-based `k`, one update is

```math
\begin{aligned}
y_k &= \Pi_{[0,1]^n}(x_k-\nabla(nF)(x_k)/288),\\
p_k &= \sum_{i=0}^{k}\frac{i+1}{2}\nabla(nF)(x_i),\\
z_k &= \Pi_{[0,1]^n}(b_0-p_k/288),\\
x_{k+1} &= \frac{k+1}{k+3}y_k+\frac{2}{k+3}z_k,
\qquad x_0=b_0.
\end{aligned}
```

The hard-decision estimate is bit one iff `b_i>1/2`; values within `1e-12` of
`1/2` are ties. The candidate latches the first tie-free, parity-valid estimate
after updates 1 through 30 and continues to update 30 for a deterministic trace.
No zero-update readout is eligible.

Frozen source identities before population access are:

- convex objective source SHA-256
  `5df9ae2489356a8d9e0f38efe5453713fec3130dfb68f8a14119638357b251f3`;
- accelerated source SHA-256
  `3eb0f8b85ba12a418fda9484cd658c43748a5bfc1db1dc92f9cc58b6f1edb5fc`;
- immutable generator/BP adapter SHA-256
  `5ce7ba12efe06b4e9a4d5b31401064128b5b95e12fe38a990e24bf228a368ec8`;
- archived generator source SHA-256
  `6c09396c7f394ad2c45ae4ee0b22d8b556c384784e2ce21fcea0ce3632009f7d`;
- archived configuration SHA-256
  `7730e668a4dc48bbf8afb8a5ed1ba365ae4b4bfb7f5306be86a795eb203286b9`.

The candidate path is continuously differentiable in the objective and uses
ordinary partial derivatives. Euclidean projection onto a polytope and the box
is differentiable almost everywhere, with a set-valued generalized derivative
at active-set changes. The hard decision, tie test, syndrome, and first-valid
latch are evaluation operations outside the differentiable training path.
This card therefore tests a differentiable optimization decoder, not a claim
that the discrete scorer itself is differentiable. The current Julia source is
not an automatic-differentiation certification.

## Frozen code, channel, and population identity

The graph is the regular degree-(3,6) code with `n=10,200`, `k=5,100`, graph
seed `169616412`, and graph SHA-256
`94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d`.
Transmission is the all-zero word under QPSK/AWGN. Physical `Es/N0=s` dB uses
noise variance `10^(-s/10)`. Positive LLR favors bit zero and channel LLRs are
clipped to `[-20,20]`. Frame `f` uses the archived deterministic noise seed
`20261012+f`.

The same frame number uses the same frozen unit-noise draw at every tested SNR;
only the registered noise scaling changes. Every LLR vector is hashed before
candidate execution. Cases are processed in ascending SNR and frame order;
there is no case selection.

Before either stage generates its first case, write and hash a stage activation
that binds this card, the Julia project and manifest, the activation verifier,
the local artifact shim and underlying shared artifact helper, all three
execution wrappers, the frozen objective and accelerated solver, the exact
ordered SNR grid, frame range, and 30-update cap. Every
wrapper must verify the activation and its own relevant source pins before
opening a packet, generator, candidate trace, truth object, or BP result. The
coarse activation contains no outcome-derived field. The fine activation must
add the committed coarse score and manifest hashes, the first provisional
crossing `s_c`, and the exact grid derived from it. A source or activation
mismatch fails before population access.

### Stage 1: coarse exposed-development sweep

- frames: `20001:20024`, all 24 at every level;
- SNR grid: `1.5, 2.0, ..., 12.0` dB, all 22 levels;
- provisional crossing: the lowest level with `C_s >= B_s-4`;
- no coarse-grid suffix is called a stable working threshold;
- if no level crosses, the registered conclusion is “no working SNR through
  12.0 dB under this 30-update method,” and Stage 2 does not run.

### Stage 2: fine exposed-development sweep

If the first coarse crossing is `s_c`, freeze and hash the exact fine grid
before opening a fine case:

```math
\{s_c-0.5,s_c-0.4,\ldots,s_c+0.5\}\ \text{dB}.
```

- frames: `30001:30200`, all 200 at every level;
- primary crossing: the lowest level with `C_s >= B_s-30`;
- stable working threshold: the lowest primary crossing for which every higher
  tested fine-grid level also passes. A nonmonotone pass is reported but is not
  called the stable threshold.

Both populations were exposed in earlier native-gap development work. They are
appropriate for method development and threshold location, not for a fresh
confirmation claim.

## Candidate/truth firewall and deterministic replay

Packet preparation writes only graph/channel fields needed by the candidate:
checks, case identity, SNR, noise seed, LLR vector, and hashes. It contains no
transmitted word, BP estimate, BP iteration count, recovery flag, or scorer
field. The candidate process may import only the frozen objective and
accelerated solver, consumes the packet, commits its trace and readouts, and
then repeats every case from initialization.

Primary and replay must agree bit-for-bit on the scientific trace: every
latched update and hard estimate, update-30 state and hard-estimate hashes,
syndrome and tie fields, and candidate result row. Timing, allocation, and
peak-memory telemetry are measured separately and are excluded from replay
equality.

Only after candidate commit may the scorer regenerate each case, verify its
LLR hash, run exact sum-product BP, and compare candidate and BP estimates with
the transmitted word. BP uses flooding sum-product, no damping, first zero
syndrome or 80 message-passing iterations. The scorer may not modify or rerun
the candidate.

## Work, correctness, metrics, and decisions

Each candidate case receives exactly 30 attempted accelerated updates. Each
update has one `O(E)` objective/partial-derivative evaluation, two
componentwise box projections, and one convex-combination pass. Core memory is
`O(E+n)`. No line search, restart, randomization, learned parameter, BP call,
truth access, SNR-dependent coefficient, or extra update is allowed.

Independent failure conditions are: a wrong parity-valid codeword; any
hard-readout tie at an eligible update 1 through 30; source/hash mismatch;
input mismatch; nondeterministic replay; candidate access to truth or BP; more
than 30 candidate updates; or work outside the declared bounded-degree `O(E)`
envelope. This prospective wording makes the tie gate explicit before any
population outcome opens; a tie is a coordinate within `1e-12` of `1/2`.

For every SNR report `C_s`, `B_s`, the deficit `C_s-B_s`, first-valid update
distribution, wrong-valid count, tie count, update-30 syndrome weight and bit
errors, and continuous objective/mapping telemetry. Continuous convergence is
never substituted for hard-decision transmitted-word recovery.

The expected qualitative outcome, frozen before execution, is no crossing near
1.5 dB and a crossing at a materially higher SNR. The coarse grid is allowed to
show no crossing through 12 dB. No exact threshold or recovery count is
predicted because the frozen accelerated solver has no population result.

A stable fine-grid crossing identifies the lowest exposed-development SNR at
which this exact objective, initialization, solver, and 30-update budget meet
the active recovery target. It does not establish a code threshold, global
optimality, generalization to another graph or block length, or untouched-case
performance. A later claim of confirmation requires a separately collision-
audited population after freezing the method and selected SNR.
