# Why the BP–GD study is considering a move from \(J_C\) penalties to parity-polytope constraints

**Status:** explanatory synthesis, 8 November 2026. This document reports no
new experiment or decoder result. Registered results, external indicative
checks, constructed mathematical examples, and open proposals are labeled
separately. It does not activate or replace the open state-dependent two-hop
matrix branch.

## Conclusion first

The gradient is not failing to optimize \(J_C\). It is faithfully optimizing
a nonconvex landscape that can contain wrong local minima.

The registered 6-dB results show that a projected-gradient construction can
work well in the easier regime. They are consistent with the initialization
entering a useful basin of attraction on those cases. At 1.5 dB, the frozen
scalar protocol recovered no transmitted words through 90 updates, and an
external indicative continuation is consistent with frequent convergence to
wrong basins.

This motivates a change in responsibility:

\[
\boxed{
\begin{array}{c}
\text{differentiate the signal cost},\\[2mm]
\text{represent parity by parity-polytope feasibility},\\[2mm]
\text{enforce shared-to-local consistency with projections and multipliers}.
\end{array}}
\]

Parity can also appear in a differentiable cost. What is generally unavailable
from one ordinary finite-weight penalty is the complete combination of being

- smooth and convex;
- exact at a finite penalty weight;
- zero only at binary parity-valid points; and
- easy to minimize by ordinary gradient descent.

The rest of this note explains how the study reached that boundary and what
the proposed constrained formulation does and does not solve.

## 1. Starting observation

The study began with a large recovery gap on paired registered cases. For each
comparison, the parity-check matrix, transmitted word, noise realization, and
vector of channel log-likelihood ratios (LLRs) were held fixed.

At 30 updates, native projected gradient descent recovered \(112/200\)
transmitted words at 6 dB and \(0/200\) at 1.5 dB. Native exact sum-product BP
recovered \(200/200\) and \(199/200\), respectively. This established the gap,
but it did not identify its cause.

The two methods traverse the same Tanner graph but do not retain or update the
same quantities. BP retains directed variable-to-check and check-to-variable
messages and uses recipient exclusion. The ordinary gradient control retains
one scalar per bit, calculates partial derivatives of a declared objective
function, applies its declared direction and step rule, and projects onto its
box.

## 2. What the controlled campaign changed

Correctly assigned check-specific information materially improved recovery at
6 dB. The selected compound-box projected-gradient construction recovered
\(177/200\) transmitted words after 30 updates and \(200/200\) after 90 updates
on registered fresh frames 50025--50224. This is the strongest retained
gradient-based recovery result, but it is not a cross-SNR result approaching
BP. That exact construction has no completed 1.5-dB transfer.

A related registered native-compound budget diagnostic separated the effect of
the update limit. It changed from \(113/200\) at update 30 to \(193/200\) at
update 90 at 6 dB, but remained at \(0/200\) at both updates at 1.5 dB. More
updates repaired many high-SNR cases but did not repair the low-SNR result.

The central controlled boundary came from holding the recurrence fixed while
changing the state freedom, direction, and application rule. At 1.5 dB, direct
unit application of recurrence minus state recovered \(196/200\) transmitted
words, while every tested true-gradient arm recovered \(0/200\). Direct
application of that recurrence is a fixed-point update, not a gradient step.

Nonintegrability witnesses on \(400/400\) instances also ruled out representing
the exact recurrence as the gradient of one smooth scalar objective in the
tested coordinates under a fixed matrix. This did not rule out all
gradient-based constructions. Fixed-matrix, one-hop, and the sealed
graph-factorized families were later pruned only within their registered
scopes. The state-dependent recipient-excluded two-hop positive-definite matrix
still has a retained fit but no fresh direction-screen or decoder result.

These results changed the question from

\[
\text{``How should we descend }J_C\text{?''}
\]

to

\[
\text{``Is }J_C\text{ the right landscape to descend?''}
\]

## 3. The implemented objective

Let \(x\in[-1,1]^n\) denote the incident-edge mean used by the objective. A
positive channel LLR \(L_i\) favors bit zero, and the hard-decision estimate is
bit one when \(x_i<0\). In these mean coordinates, the implemented objective is

\[
J_C(x)=
-\frac{L^{\mathsf T}x}{2n}
+\frac{w_p}{n}\sum_c
\left(1-\prod_{i\in c}x_i\right)^2
+\frac{w_b}{n}\sum_i(1-x_i^2)^2,
\]

with \(w_p=2\) and \(w_b=0.2\). The production evaluator clips each LLR to
\([-20,20]\). Its stored state uses directed-edge coordinates \(z\), but
\(J_C(z)=J_C(Cz)\) depends only on their incident-edge means \(x=Cz\).

The implementation is visible in
[`compound_objective_jc.jl`](../implementation/two_hop_metric_action/compound_objective_jc.jl),
with the parity loop beginning at line 103 and the channel and binary terms at
lines 127--136.

## 4. How paired hard errors hide from one check

At a hard-sign vector, one check sees

- zero wrong signs: \(\prod_i x_i=+1\);
- one wrong sign: \(\prod_i x_i=-1\); and
- two wrong signs: \(\prod_i x_i=+1\).

Therefore, at a hard vertex, a check containing two wrong bits has

\[
\left(1-\prod_i x_i\right)^2=0.
\]

That check is satisfied and contributes no parity force at that vertex. It
cannot distinguish the all-correct local pattern from a two-error local
pattern. This is not an implementation defect: both patterns genuinely have
even parity. The channel LLRs and overlapping checks must decide which local
pattern is globally preferable.

This statement concerns the contribution of that one satisfied check at a
hard vertex. It does not say that the complete gradient is zero. The channel,
other checks, and the term \((1-x_i^2)^2\) still contribute away from the
appropriate zeros.

## 5. How a product-penalty hill appears

Now consider correcting the two signs together. Let

\[
x_i=x_j=t,
\]

and hold the other members of the check at \(+1\). Along this symmetric path,
the check contribution is

\[
J_{\mathrm{check}}(t)
=\frac{w_p}{n}(1-t^2)^2.
\]

It is zero at both parity-valid endpoints,

\[
J_{\mathrm{check}}(-1)=J_{\mathrm{check}}(+1)=0,
\]

but positive between them:

\[
J_{\mathrm{check}}(0)=\frac{w_p}{n}.
\]

Thus this continuous route has the form

\[
\text{wrong satisfied pattern}
\longrightarrow
\text{higher cost}
\longrightarrow
\text{correct satisfied pattern}.
\]

The term \((1-t^2)^2\) that favors hard magnitudes raises the same intervening
hill. A gradient update can change every coordinate simultaneously; it does
not literally change one bit at a time. The problem is that even a collective
small correction can be uphill.

This symmetric path demonstrates one uphill route. It is not, by itself, a
proof that every continuous route between the endpoints crosses a positive
minimum barrier. Such a claim requires a separate minimum-rim and finite-jump
certificate.

## 6. A constructed \(J_C\)-shaped example

The following two-coordinate example uses the same term shapes and weights. It
is a mathematical illustration, not an extracted code frame or a decoder
result. Omitting the common \(1/n\) scale, define

\[
\begin{aligned}
F(x_1,x_2)
={}&-\frac{x_1+4.6x_2}{2}
+2(1-x_1x_2)^2\\
&+0.2\left[(1-x_1^2)^2+(1-x_2^2)^2\right],
\end{aligned}
\]

with \((x_1,x_2)\in[-1,1]^2\). The desired valid word has lower cost:

\[
F(+1,+1)=-2.8.
\]

At

\[
x^*=(-1,-0.5),
\]

however,

\[
F(x^*)=2.2625,
\qquad
\nabla F(x^*)=(0.5,0).
\]

A projected-gradient trial is

\[
x^*-\eta\nabla F(x^*)
=(-1-0.5\eta,-0.5).
\]

The first coordinate lies outside the box, so projection returns

\[
\Pi_{[-1,1]^2}
\left(x^*-\eta\nabla F(x^*)\right)
=x^*
\]

for every \(\eta>0\). Increasing \(x_1\) is initially uphill; decreasing it is
forbidden by the box. The \(x_2\) slope is zero, and the second derivative in
that tangent direction is \(3.8>0\). Therefore, \(x^*\) is a wrong constrained
local minimum even though a much lower valid word exists elsewhere.

The example isolates the landscape mechanism. It does not prove how often the
registered channel initialization enters an analogous basin on the full
\((3,6)\) graph.

## 7. What an exact projected zero means

For the Euclidean direction, define

\[
G_\eta(x)
=\frac{x-\Pi_{[-1,1]^n}
\left(x-\eta\nabla J_C(x)\right)}{\eta}.
\]

At an exact point satisfying

\[
G_\eta(x^*)=0,
\]

ordinary projected \(-\nabla J_C\) has no feasible infinitesimal descent
direction. More scalar projected-gradient updates return the same point, a
change only to the positive scalar step cannot create a new direction, and a
local strict-decrease line search cannot accept the uphill movement required
to leave a strict well.

The protocol-specific registered diagnostic includes its frozen diagonal:

\[
G_\eta^D(x)
=\frac{x-\Pi_{[-1,1]^n}
\left(x-\eta D^{-1}\nabla J_C(x)\right)}{\eta},
\qquad
D=\frac{13.6}{n}I.
\]

Because \(D\) is a positive scalar multiple of the identity, \(G_\eta\) and
\(G_\eta^D\) describe the same Euclidean direction and have the same exact
zero set after a corresponding positive scalar step change. Their finite
tolerance values are not interchangeable. For the registered \(n=10{,}200\)
population, \(D^{-1}\) scales the interior gradient by \(750\).

The inequality

\[
J_C(x_{\mathrm{word}})<J_C(x^*)
\]

does not alter this local conclusion. It establishes that a lower valley
exists, not that a downhill route connects the current point to it.

Exact stationarity also does not close every conceivable update involving
\(\nabla J_C\). Auxiliary momentum can alter the route before the method
enters the basin; a finite nonmonotone jump can cross an intervening rise; a
different initialization can enter another basin; and a nonscalar or
state-dependent \(P(x)\) can change the direction before stationarity. A
finite jump requires a separate no-lower-jump analysis. At an exact stationary
state with zero auxiliary velocity, however, additional ordinary local descent
cannot escape.

## 8. Evidence boundary at 1.5 dB

The registered result for the frozen native compound protocol is

| SNR | recovery at update 30 | recovery at update 90 |
|---|---:|---:|
| 6 dB | 113/200 | 193/200 |
| 1.5 dB | 0/200 | 0/200 |

This closes the explanation that increasing the old update budget from 30 to
90 repairs the 1.5-dB count. It is not a theorem about every scalar step
sequence.

An external NumPy continuation reported, at 1.5 dB,

- \(0/200\) recoveries;
- 197 terminals meeting its own \(10^{-8}\) approximate-stationarity
  tolerance and three 6,000-update caps;
- a median of approximately 744 wrong bits at the terminal state; and
- \(J_C(x_{\mathrm{terminal}})>J_C(x_{\mathrm{word}})\) on all 200 frames.

Those values are useful indicative mechanism evidence, but they are not a
registered stationarity result. The external calculation used an unscaled
diagnostic at a finite tolerance and did not perform the registered independent
\(10^{-10}\) confirmation pass. The exact zero set is shared after scalar step
conversion; the finite numerical labels are not equivalent.

The resulting stopping statement is therefore:

> Stop treating changes only to the scalar step, normalization, or update
> budget of the one-scalar Euclidean projected \(-\nabla J_C\) protocol as new
> low-SNR performance routes. Do not claim that state-dependent matrices,
> finite nonmonotone jumps, different objectives, or expanded-variable methods
> are impossible.

## 9. Parity can be placed in a differentiable cost

Parity is not forbidden from a differentiable objective. The obstruction is
to obtaining all of the following from one ordinary penalty at once:

- smoothness and convexity;
- exact parity at a finite penalty weight;
- zeros only at binary parity-valid points; and
- easy minimization by ordinary gradient descent.

Let \(\mathcal V_c\) be the set of binary even-parity patterns for check \(c\),
and suppose a nonnegative convex function \(p\) satisfies

\[
p(v)=0
\qquad
\text{for every }v\in\mathcal V_c.
\]

Every point \(u\) in their convex hull has a representation

\[
u=\sum_{v\in\mathcal V_c}\alpha_vv,
\qquad
\alpha_v\ge0,
\qquad
\sum_v\alpha_v=1.
\]

Convexity gives

\[
0\le p(u)
\le\sum_v\alpha_vp(v)
=0.
\]

Consequently,

\[
p(u)=0
\qquad
\text{throughout}
\qquad
\mathcal P_c=\operatorname{conv}(\mathcal V_c).
\]

A convex function cannot therefore have only the isolated binary even-parity
patterns as its zero-valued minima. The product construction obtains isolated
hard zeros by giving up convexity, which permits multiple local minima and
intervening hills.

## 10. A differentiable convex parity cost

Let \(b\in[0,1]^n\) be the shared bit vector, let \(S_cb\) extract the entries
incident on check \(c\), and let \(\mathcal P_c\) be that check's parity
polytope. Define

\[
J_\rho(b)
=f_{\mathrm{sig}}(b)
+\frac{\rho}{2}\sum_c
\left\|
S_cb-\Pi_{\mathcal P_c}(S_cb)
\right\|^2.
\]

For a closed convex parity polytope, this cost is continuously differentiable,
with

\[
\nabla J_\rho(b)
=\nabla f_{\mathrm{sig}}(b)
+\rho\sum_c S_c^{\mathsf T}
\left[
S_cb-\Pi_{\mathcal P_c}(S_cb)
\right].
\]

If \(f_{\mathrm{sig}}\) is convex, then \(J_\rho\) is convex. The parity term
pulls each local configuration toward its parity polytope instead of creating
a product hill between valid hard configurations.

This does not provide a binary guarantee. The parity contribution is zero
throughout each \(\mathcal P_c\), including at fractional mixtures. It also
does not generally impose exact feasibility for a finite value of \(\rho\).

The one-dimensional example makes the finite-weight issue explicit:

\[
\min_x x
\qquad
\text{subject to}
\qquad
x=0.
\]

The constrained solution is \(x=0\). Replacing the constraint by

\[
F_\rho(x)=x+\frac{\rho}{2}x^2
\]

gives

\[
x_\rho=-\frac1\rho,
\]

which violates the constraint for every finite \(\rho\). Increasing \(\rho\)
reduces the violation but does not make it exactly zero. In the parity cost,
the restoring term

\[
\rho\left[S_cb-\Pi_{\mathcal P_c}(S_cb)\right]
\]

vanishes at feasibility, so a nonzero signal gradient can balance it at a
slightly infeasible point.

Thus a single differentiable convex objective is available if approximate
parity is acceptable. Exact enforcement requires another mechanism.

## 11. Check-local replicas and multipliers

Introduce a check-local replica \(z_c\) and impose

\[
z_c=S_cb,
\qquad
z_c\in\mathcal P_c.
\]

Define the residual

\[
r_c=S_cb-z_c.
\]

With multiplier \(y_c\), the augmented Lagrangian is

\[
\mathcal L_\rho(b,z,y)
=f_{\mathrm{sig}}(b)
+\sum_c\left[
y_c^{\mathsf T}r_c
+\frac{\rho}{2}\|r_c\|^2
\right],
\qquad
z_c\in\mathcal P_c.
\]

Its derivative with respect to the shared variables is

\[
\nabla_b\mathcal L_\rho
=\nabla f_{\mathrm{sig}}(b)
+\sum_cS_c^{\mathsf T}(y_c+\rho r_c).
\]

At exact agreement, \(r_c=0\), the quadratic contribution vanishes but the
multiplier need not. The condition can therefore be

\[
\nabla f_{\mathrm{sig}}(b)
+\sum_cS_c^{\mathsf T}y_c
=0.
\]

The multipliers can balance the signal gradient while the local replicas agree
with the shared variables. An ordinary differentiable nonnegative penalty that
vanishes on the feasible set cannot provide this persistent nonzero normal
force by itself.

A practical splitting procedure alternates among

1. updating the shared variables using the differentiable signal and
   shared-to-local terms;
2. projecting each check-local replica onto its parity polytope; and
3. updating the multipliers from the residuals.

This procedure uses derivatives, but it is not ordinary descent of one
unconstrained scalar objective. The shared variables and local replicas are
minimized subject to their declared sets, while the multipliers are updated to
enforce consistency.

## 12. Exactness boundary on the loopy graph

Each \(\mathcal P_c\) is exact for one parity check. On the present loopy
\((3,6)\) Tanner graph, however, intersecting those check polytopes through
shared-bit consistency produces the fundamental-polytope relaxation. It can
have a fractional solution, called a pseudocodeword in the LP-decoding
literature.

Therefore,

\[
\text{exact local parity-polytope feasibility}
\not\Longrightarrow
\text{a guaranteed binary codeword on this loopy graph}.
\]

A linear cost over the exact global codeword polytope has a valid codeword at
an optimal vertex. A unique optimum selects that vertex. If several codewords
tie, fractional mixtures on the optimal face are also optimal and require a
deterministic vertex or tie rule. Constructing or projecting onto the exact
global polytope can be much more expensive than the check-local relaxation.

Thus the coding difficulty does not disappear. It moves from a nonconvex
objective landscape into the representation and enforcement of the feasible
set.

## 13. Resulting research direction

The prospective formulation is

\[
\boxed{
\text{linear or differentiable lifted signal cost}
+\text{ parity-polytope feasibility}
+\text{ shared-to-local consistency and multipliers}.
}
\]

This is not another scalar-step modification of \(J_C\). It changes the
objective, state, parity representation, update operation, and memory. Before
it can be treated as a decoder result, it requires a prospective experiment
card, finite-difference checks of every declared derivative, projection and
consistency invariants, deterministic replay, a declared work budget, and
recovery and coded-bit-error evaluation on unopened cases.

It also does not supersede the active two-hop matrix branch. That branch must
be completed or prospectively amended under its own registered gates. This
note records why a constrained successor would be scientifically distinct if
the study opens it later.

The causal progression is

\[
\boxed{
\begin{array}{c}
\text{strong 6-dB projected-gradient result}\\
\downarrow\\
\text{related scalar }J_C\text{ control remains }0/200\text{ at 1.5 dB}\\
\downarrow\\
\text{budget, scalar rescaling, and several local families pruned}\\
\downarrow\\
\text{product-based landscape identified as a plausible bottleneck}\\
\downarrow\\
\text{consider moving parity from a penalty function into constrained geometry}.
\end{array}}
\]

The study is not abandoning differentiation. It is reconsidering what the
partial derivatives should be responsible for: signal ranking rather than
soft enforcement of every coding constraint.

## Source boundary

- The paired experiment history and current decision tree are in
  [`../explainers/the_path_so_far.html`](../explainers/the_path_so_far.html)
  and
  [`../explainers/the_path_so_far_tree.html`](../explainers/the_path_so_far_tree.html).
- The exact projected-descent mathematics, evidence classification, and scope
  limits are in
  [`jc_projected_gradient_boundary.md`](jc_projected_gradient_boundary.md).
- The registered continuation protocol, which remains unfinished, is in
  [`rq2_jc_projected_stationarity_001_card.md`](rq2_jc_projected_stationarity_001_card.md).
- The active two-hop scope and its approval gates are in
  [`active_goal.md`](active_goal.md).
- The implemented objective and partial derivatives are in
  [`../implementation/two_hop_metric_action/compound_objective_jc.jl`](../implementation/two_hop_metric_action/compound_objective_jc.jl).

## Terminology audit

The literature-attested expressions used here include *parity polytope*,
*fundamental polytope*, *pseudocodeword*, *constrained stationary point*,
*augmented Lagrangian*, *projected gradient descent*, *local minimum*, and
*basin of attraction*. The primary local terminology sources are:

- Barman et al.,
  `/home/gabiel/Dropbox/Phd/papers/06_channel_coding/02_lp_admm_and_proximal_decoding/ADMM_LP_decoding_with_parity-polytope_projection__Barman_2013.pdf`,
  pages 4--7; and
- Wadayama,
  `/home/gabiel/Dropbox/Phd/papers/06_channel_coding/03_gradient_and_bit_flipping_decoding/Trainable_projected-gradient_LDPC_decoding_with_restarts__Wadayama_2019.pdf`,
  pages 1--3.

The requested phrases *binary attraction*, *projected gradient mapping*,
*agreement residual*, and *fractional pseudocodeword* were not found as
complete expressions in the indexed corpus. This note instead writes the
explicit term \((1-x_i^2)^2\), defines \(G_\eta\) without assigning it that
unsupported label, calls \(r_c\) a residual, and uses the separately attested
expressions *fractional solution* and *pseudocodeword*.

The terminology corpus manifest is
`255f4aece68bd073d16381e9832403ca826ac536d91e5984516e2e4478ac5b6f`.
Four PDFs were unavailable to text extraction during the audit.
