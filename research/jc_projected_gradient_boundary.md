# Mathematical boundary of projected descent on \(J_C\)

**Status:** analytical note, 8 November 2026. This document derives the
mathematics discussed around the 1.5-dB failure of the one-scalar projected
gradient decoder. It introduces no experiment and reports no new decoder
result. Exact identities, registered measurements, unregistered numerical
checks, and unproved hypotheses are separated explicitly.

## Conclusion first

There is a defensible reason to stop repeating variants that preserve all of
the following:

- one scalar \(x_i\) per bit;
- the unchanged objective \(J_C\);
- the Euclidean direction \(-\nabla J_C\), or the retained fixed diagonal,
  which is only a scalar multiple of that direction;
- componentwise projection onto the box; and
- a change only to the scalar step units, update cap, or normalization.

The mathematical statement is narrower than “no gradient method can work.”
Positive scalar rescaling cannot change the path of the continuous-time
projected gradient flow. At an exact box-constrained stationary point, every
positive scalar projected-gradient step returns the same point. The retained
budget-90 protocol also recovered \(0/200\) transmitted words at 1.5 dB.

This does **not** rule out a finite step that jumps over an intervening rise,
an update with auxiliary velocity, a nonscalar matrix applied to the partial
derivatives, a state-dependent matrix, a different objective function, or an
expanded-variable method with check-local replicas and multipliers. The
active recipient-excluded two-hop positive-definite matrix belongs to the
open matrix-applied class; it has not produced a fresh direction-screen or
decoder result.

## 1. Objective, signs, and coordinates

Let \(Q=[-1,1]^n\). A positive channel log-likelihood ratio (LLR) \(L_i\)
favors bit zero, and the hard-decision estimate is bit one exactly when
\(x_i<0\). Define

\[
F(x)=\widetilde J_C(x)
=-\frac{L^{\mathsf T}x}{2n}
+\frac{w_p}{n}\sum_c\left(1-\prod_{i\in c}x_i\right)^2
+\frac{w_b}{n}\sum_i(1-x_i^2)^2,
\]

with \(w_p=2\), \(w_b=0.2\), and the retained regular \((3,6)\) Tanner
graph. Write

\[
p_c=\prod_{j\in c}x_j,
\qquad
q_{ci}=\prod_{j\in c\setminus i}x_j.
\]

The exact partial derivative is

\[
\partial_iF(x)
=-\frac{L_i}{2n}
-\frac{2w_p}{n}\sum_{c\ni i}(1-p_c)q_{ci}
+\frac{4w_b}{n}x_i(x_i^2-1).
\tag{1}
\]

The registered one-scalar diagonal is

\[
D=\frac{13.6}{n}I,
\qquad
-D^{-1}\nabla F(x)=-\frac{n}{13.6}\nabla F(x).
\tag{2}
\]

Thus the retained diagonal changes only the scalar units of the Euclidean
negative-gradient direction. It does not create another direction.

The two-hop construction uses a directed-edge state \(z\), but the objective
depends only on the incident-edge means \(x=Cz\):

\[
J_C(z)=F(Cz).
\tag{3}
\]

Every displacement in \(\ker C\) is therefore exactly flat for \(J_C\).
Any rigorous well or rim for that construction must be stated in the mean
coordinate \(x=Cz\), not as an isolated well in the full edge-coordinate
space.

## 2. Exact force law at a hard vertex

Let \(s\in\{-1,1\}^n\), and let \(k_i\) be the number of violated checks
incident on bit \(i\). At a satisfied check, \(p_c=1\), so its contribution
to (1) is zero. At a violated check, \(p_c=-1\) and
\(q_{ci}=-s_i\), so its contribution is \(4w_ps_i/n\). The binary term is
zero at a hard vertex. Therefore

\[
\boxed{
\partial_iF(s)
=-\frac{L_i}{2n}+\frac{4w_p}{n}k_i s_i
}
\tag{4}
\]

and

\[
[-\nabla F(s)]_i
=\frac{L_i-8w_pk_i s_i}{2n}.
\tag{5}
\]

The component points from \(s_i\) toward zero precisely when

\[
s_i[-\partial_iF(s)]<0
\quad\Longleftrightarrow\quad
s_iL_i<8w_pk_i.
\tag{6}
\]

At the channel hard decision, \(s_i=\operatorname{sign}(L_i)\), this becomes

\[
|L_i|<8w_pk_i=16k_i.
\tag{7}
\]

On the exported 1.5-dB population used by the unregistered numerical check,
the observed LLR range was approximately \([-9.401,14.925]\). Consequently,
at the corresponding **hard vertex**, every bit incident on at least one
violated check points toward zero.

Equation (4) gives the precise intuitive mechanism. The parity contribution
from one violated check pushes all six incident coordinates toward changing
sign with the same magnitude. It does not identify which incident bit caused
the violation. The complete force can still distinguish the six bits through
their total counts \(k_i\) and their channel LLRs. When the \(k_i\) values are
equal, the LLR is the remaining hard-vertex tie-breaker. Away from a hard
vertex, the partner-product magnitudes \(q_{ci}\) and the binary term also
distinguish the coordinates.

This corrects two overly strong slogans:

- a gradient update changes all coordinates simultaneously; it does not
  “move one bit at a time”; and
- the gradient cannot distinguish recipients through one violated check at a
  hard vertex, but the full gradient is not generally identical at all six
  recipients.

Exact sum-product BP uses directed variable-to-check and check-to-variable
messages. Its check-to-variable update for bit \(i\) excludes the message
received from \(i\) and depends on the other five incoming messages. That
recipient-excluded calculation is the relevant structural contrast; the
vertex identity above does not by itself prove a performance theorem.

The registered initialization is \(x_i^{(0)}=\tanh(L_i/2)\), not a hard
vertex. Equations (4)--(7) therefore explain the hard-vertex mechanism, while
the exact initial numerical race must use (1) at the soft initialization.

## 3. Initial SNR split on the depth-one tree

The first-neighborhood combinatorics can be calculated without simulating the
decoder. Assume independent hard-decision errors with probability \(p\) on a
depth-one neighborhood of the \((3,6)\)-regular ensemble. Conditioned on the
central bit being wrong, an incident check is violated when an even number of
its other five bits are wrong. Hence

\[
q_{\mathrm w}(p)
=\sum_{\substack{r=0\\r\text{ even}}}^{5}
{5\choose r}p^r(1-p)^{5-r}
=\frac{1+(1-2p)^5}{2}.
\tag{8}
\]

On the depth-one tree, the three incident checks are independent, so

\[
K\mid\{\text{central bit wrong}\}
\sim\operatorname{Binomial}(3,q_{\mathrm w}(p)).
\tag{9}
\]

The expected number of checks containing exactly one wrong bit is

\[
\mathbb E[N_{1\text{-wrong}}]=m\,6p(1-p)^5.
\tag{10}
\]

Here (m) is the number of parity checks; for this regular graph,
(m=nd_v/d_c=n/2=5{,}100).

Using the exposed population averages gives:

| quantity | 1.5 dB | 6 dB |
|---|---:|---:|
| hard-error rate \(p\) | 0.117451 | 0.022941 |
| predicted \(P(K=0,1,2,3)\) | (0.0502, 0.2577, 0.4408, 0.2513) | (0.00115, 0.0294, 0.2517, 0.7178) |
| observed fraction with \(K=3\) | 0.251 | 0.718 |
| predicted one-wrong-bit checks per frame | 1,924 | 625 |
| observed one-wrong-bit checks per frame | 1,922 | 625 |

This explains the **initial** SNR split under the independent/tree
assumptions. At 6 dB, a wrong bit is usually incident on three violated
checks; at 1.5 dB, clustered hard errors make one or two violated incident
checks much more common.

At a channel-aligned hard vertex, the common-factor speed toward zero is

\[
16k_i-|L_i|.
\tag{11}
\]

Under the additional local-tree assumption that an isolated wrong bit is the
only wrong bit in all three incident checks, its speed is
\(48-|L_i|\), while a correct neighbor incident on only the shared violated
check has speed \(16-|L_j|\). If a wrong bit instead has only one violated
incident check and the competing correct bits also have \(k=1\), the smallest
\(|L|\) reaches zero first under the frozen vertex velocity.

The reported 31.5% at 1.5 dB and 1.4% at 6 dB are more detailed
**initial per-check race forecasts** calculated from the exact soft-state
velocity and distance to zero. They are not observed pair formations. The
calculation does not integrate the nonlinear trajectory, deduplicate a bit
shared by several checks, or establish that a predicted crossing persists.
Also, \(K=3\) does not by itself mean that an error is isolated in the full
graph.

## 4. Necessary conditions at a wrong box-stationary point

Work in the all-zero transmitted-word gauge and assume no exact-zero sign
ties. A wrong bit has \(x_i<0\). Let its degree be \(d_i\), and let \(k_i\)
count its violated incident checks under the hard-decision estimate.

At the lower wall \(x_i=-1\), the box KKT condition requires
\(\partial_iF(x)\ge 0\). A satisfied incident check contributes at most
\(w_p/(2n)\) upward because

\[
(1-a)a\le\frac14,\qquad 0\le a\le1.
\]

Violated-check contributions have the opposite sign and can be discarded
when deriving a necessary upper bound. Therefore

\[
\boxed{L_i\le w_p(d_i-k_i)}
\qquad (x_i=-1).
\tag{12}
\]

For an interior wrong bit, \(-1<x_i<0\), stationarity requires
\(\partial_iF(x)=0\). Each satisfied incident check contributes at most
\(2w_p/n\), while

\[
\max_{0\le a\le1}4w_ba(1-a^2)
=\frac{8w_b}{3\sqrt3}.
\]

It follows that

\[
\boxed{
L_i\le4w_p(d_i-k_i)+\frac{16w_b}{3\sqrt3}
}
\qquad (-1<x_i<0).
\tag{13}
\]

For \(d_i=3\), \(w_p=2\), and \(w_b=0.2\), these become

\[
L_i\le2(3-k_i)
\quad\text{at the wall},
\tag{14}
\]

and

\[
L_i\le24-8k_i+\frac{3.2}{3\sqrt3}
=24.61584\ldots-8k_i
\quad\text{in the interior}.
\tag{15}
\]

These are necessary conditions, not a classification theorem. In particular,
they do not rule out \(k_i=2\) or \(k_i=3\) for every channel realization.
The exact interior balance also contains positive satisfied-check
contributions **minus** violated-check contributions. The simpler
all-positive balance used in the scratch calculation is valid for the tested
\(k_i=0\) class, not for all wrong bits.

The unregistered continuation reported the following aggregate over all 200
1.5-dB terminal states:

| violated incident checks \(k_i\) | 0 | 1 | 2 | 3 |
|---:|---:|---:|---:|---:|
| wrong-bit count | 94,861 | 52,521 | 547 | 0 |

Those counts show terminal configurations dominated by wrong bits with zero
or one violated incident check. They do not prove that every terminal is an
absorbing set: on a degree-three graph, the standard absorbing-set majority
condition fails for the 547 wrong bits with \(k_i=2\). The bitwise inequality
and balance checks were also performed on only two selected frames; the
reported \(2.5\times10^{-4}\) root agreement used a grid spaced by
\(5\times10^{-4}\), so it is a numerical consistency check rather than a
certificate.

## 5. What exact box stationarity closes

The registered card defines

\[
G_\eta(x)=
\frac{x-\Pi_Q\!\left(x-\eta D^{-1}\nabla F(x)\right)}{\eta},
\qquad \eta=0.2.
\tag{16}
\]

Because \(D\) is a positive scalar multiple of the identity,

\[
G_\eta(x^\star)=0
\quad\Longleftrightarrow\quad
0\in\nabla F(x^\star)+N_Q(x^\star),
\tag{17}
\]

where \(N_Q(x^\star)\) is the normal cone of the box. Equivalently, every
feasible infinitesimal direction \(d\) satisfies

\[
\nabla F(x^\star)^{\mathsf T}d\ge0.
\tag{18}
\]

At an exact point satisfying (17), every positive scalar Euclidean projected
gradient step is fixed:

\[
\Pi_Q\!\left(x^\star-\alpha\nabla F(x^\star)\right)=x^\star,
\qquad \alpha>0.
\tag{19}
\]

Thus a memoryless scalar projected-gradient method cannot leave that exact
point. A finite-tolerance value of \(\|G_\eta\|_\infty\), however, is not an
exact proof that (17) holds.

### Positive scalar rescaling does not change the continuous path

Let \(T_Q(x)\) denote the cone of feasible instantaneous directions at
\(x\), and define

\[
v(x)=\Pi_{T_Q(x)}[-\nabla F(x)].
\tag{20}
\]

Along the projected gradient flow \(\dot x=v(x)\), orthogonal projection onto
the feasible-direction cone gives

\[
\frac{d}{dt}F(x(t))
=\nabla F(x)^{\mathsf T}v(x)
=-\|v(x)\|_2^2\le0.
\tag{21}
\]

Now let \(a(x,t)>0\) and consider

\[
\dot x=a(x,t)v(x).
\tag{22}
\]

Under the usual existence and uniqueness conditions, define

\[
\tau(t)=\int_0^t a(x(s),s)\,ds.
\]

Then \(dx/d\tau=v(x)\). Equations (20) and (22) therefore trace the same
geometric orbit; the positive scalar changes only its timing. Equality of
asymptotic limits additionally requires the accumulated scaled time to be
unbounded.

This result closes normalization and positive global scalar rescaling for the
continuous flow. It does **not** prove that every discrete scalar step
sequence follows the same path. The finite update

\[
x^{+}=\Pi_Q(x-\alpha\nabla F(x))
\tag{23}
\]

can land on a different path when \(\alpha\) changes. To close a declared
bounded step family \(\mathcal A\), one sufficient route is to exhibit a
wrong-readout region \(R\subset Q\) such that

\[
\Pi_Q(x-\alpha\nabla F(x))\in R
\quad\text{for every }x\in R
\text{ and every }\alpha\in\mathcal A.
\tag{24}
\]

An unrestricted large step is not closed by a local stationary-point
calculation.

A momentum update, for example,

\[
x^{(t+1)}=\Pi_Q\!\left(
x^{(t)}-\alpha_t\nabla F(x^{(t)})
+\mu_t(x^{(t)}-x^{(t-1)})
\right),
\tag{25}
\]

is not a scalar rescaling of the projected-gradient flow because its next
direction depends on an auxiliary history state. Nonzero incoming momentum
can carry an iterate away from a point where the memoryless update would be
fixed and can cross an objective rise. If both the current and previous
states equal an exact stationary point, however, (25) is fixed as well.
This explains why momentum is not covered by the orbit theorem, without
claiming that it will improve decoding.

## 6. What a positive barrier would mean

For a terminal point \(x^\star\) and a target set \(A\), define the minimum
path height

\[
\beta(x^\star,A)=
\inf_{\substack{\gamma(0)=x^\star\\\gamma(1)\in A}}
\left[
\max_{t\in[0,1]}F(\gamma(t))-F(x^\star)
\right],
\tag{26}
\]

where \(\gamma\) ranges over continuous feasible paths in \(Q\). A positive
value \(\beta>0\) proves that every continuous path to \(A\) rises above the
terminal objective value.

In two selected scratch frames, a 201-point sampling of the straight segment
from the terminal state to the transmitted vertex had sampled rises of
approximately \(0.145\) and \(0.139\). Without an interpolation or interval
error bound, those sampled maxima do not rigorously bound the maximum between
sample points. If the exact maximum rise along a tested straight path were
\(h\), then only

\[
\beta(x^\star,x_{\mathrm{word}})\le h
\]

would follow: one explicit path gives an **upper** bound on the best possible
path height. Neither the sampled values nor an exact straight-path maximum
would prove that a curved path must rise, that a positive rim exists, or that
the terminal point is a local minimum.

The proposed barrier card specifies a sufficient all-directions certificate.
Suppose interval calculations establish, throughout \(Q\cap B_r(x^\star)\),
a Hessian lower bound \(\nabla^2F\succeq\mu I\), a normal-cone residual at
most \(\epsilon\), and an objective enclosure
\(F(x^\star)\in[L_0,U_0]\). Then every feasible point \(y\) on the radius-
\(r\) boundary satisfies

\[
F(y)\ge L_0-\epsilon r+\frac{\mu r^2}{2}.
\tag{27}
\]

Consequently,

\[
\Delta_r=
L_0-\epsilon r+\frac{\mu r^2}{2}-U_0>0
\tag{28}
\]

certifies a positive rim. If the transmitted vertex lies outside the ball,
then every continuous non-increasing path from the well to that vertex is
excluded.

A finite update can still jump across the higher interior region and land at
a lower endpoint. Therefore each declared finite proposal family needs a
separate no-lower-jump check. The proposed card performs that check only for
its frozen set of 13 projected trials; it does not close every nonlocal step.

## 7. Why all \(-P\nabla J_C\) directions cannot be ruled out

The unrestricted positive-definite-matrix class is too expressive for a
universal impossibility theorem.

**Lemma.** Let \(g\ne0\). A symmetric positive-definite matrix \(P\) satisfying

\[
d=-Pg
\tag{29}
\]

exists if and only if

\[
g^{\mathsf T}d<0.
\tag{30}
\]

**Proof.** If \(P\succ0\), then
\(g^{\mathsf T}d=-g^{\mathsf T}Pg<0\). Conversely, set

\[
r=\|g\|_2,
\qquad
u=\frac{g}{r},
\qquad
h=-d,
\]

\[
a=\frac{u^{\mathsf T}h}{r}
=-\frac{g^{\mathsf T}d}{\|g\|_2^2}>0,
\qquad
b=\frac{h}{r}-au.
\]

Then \(b\perp u\). Choose
\(c>\|b\|_2^2/a\) and define

\[
P=
a uu^{\mathsf T}
+u b^{\mathsf T}
+b u^{\mathsf T}
+c(I-uu^{\mathsf T}).
\tag{31}
\]

In the basis whose first vector is \(u\), the Schur complement is positive,
so \(P\succ0\). Also \(Pu=au+b=h/r\), hence \(Pg=h=-d\), proving (29).
\(\square\)

This is only a pointwise existence proof. It does not produce a matrix that
is local on the Tanner graph, reusable across states, continuous,
well-conditioned, independent of a teacher direction, or computable in
\(O(E)\) work. Those restrictions make a concrete matrix family testable.

The word “descent” in this lemma means the first-order condition (30). A
distant finite endpoint can have lower objective even when its connecting
displacement is not a descent direction at the origin.

Box stationarity does not repair the universal claim. At a box KKT point, no
feasible direction is strictly descending, but a nonscalar matrix can mix a
normal component into another coordinate before projection. For example, at
\(x^\star=(1,0)\) in \([-1,1]^2\), let \(g=(-1,0)\) and

\[
P=\begin{bmatrix}1&\rho\\\rho&1\end{bmatrix},
\qquad 0<\rho<1.
\]

The Euclidean projected negative-gradient step is fixed, whereas the
projected matrix direction moves to \((1,\alpha\rho)\) for sufficiently small
\(\alpha\). This example gives first-order-flat motion, not guaranteed
decrease, but it proves that Euclidean box stationarity does not make every
matrix-applied projected step stationary. More importantly, a matrix can
change the path and basin reached from the channel initialization before any
terminal point is encountered.

## 8. Evidence status

### Registered result retained in the record

For the frozen native compound protocol with the fixed scalar diagonal and
17-point strict-decrease step grid:

| signal-to-noise ratio | recovery at update 30 | recovery at update 90 |
|---|---:|---:|
| 6 dB | 113/200 | 193/200 |
| 1.5 dB | 0/200 | 0/200 |

Primary and replay outputs agreed. This closes the explanation that the
1.5-dB count would be repaired merely by extending the old 30-update budget
to 90 updates. It is not a theorem about every scalar step sequence.

### Unregistered indicative continuation

An external NumPy continuation reported, at 1.5 dB:

- \(0/200\) recoveries;
- 197 terminals meeting its own \(10^{-8}\) approximate-stationarity
  tolerance and three 6,000-update caps;
- a median of 744.5 wrong bits at the terminal states;
- \(94{,}861/52{,}521/547/0\) wrong bits with
  \(k_i=0/1/2/3\); and
- \(F(x_{\mathrm{terminal}})>F(x_{\mathrm{word}})\) on all 200 frames.

These values are useful mechanism evidence, but they are not a registered
stationarity result. The replica used

\[
G_{\mathrm{replica}}(x)
=\frac{x-\Pi_Q(x-\nabla F(x)/\kappa)}{1/\kappa},
\qquad \kappa=13.6/n,
\tag{32}
\]

whereas the registered vector is (16). In the interior,

\[
G_{\mathrm{replica}}=\nabla F,
\qquad
G_{\mathrm{registered}}=D^{-1}\nabla F=750\nabla F.
\tag{33}
\]

The exact zero set is the same, but the finite \(10^{-8}\) labels are not
equivalent. Projection also prevents a general scalar conversion of the
nonzero boundary values. The replica lacked the registered independent
\(10^{-10}\) confirmation pass. The checked-in repository contains the
registered continuation card, but no completed registered execution artifact.

### Retained recurrence comparison

The direct recurrence experiment recovered \(196/200\) transmitted words at
1.5 dB only for free state plus recurrence-minus-state plus unit application;
every tested true-gradient arm recovered \(0/200\). Direct recurrence
application is a fixed-point update, not a gradient step.

A later cross-tabulation found that all 196 successful recurrence-proxy
trajectories reached their first zero-syndrome endpoint before any positive
endpoint-to-endpoint \(J_C\) change; 96 had no positive endpoint change over
all 30 updates. This does not prove monotonicity inside a finite update, and
the table does not establish that the first parity-valid estimate was already
the transmitted word. It does show why “BP succeeds only because it goes
uphill” is not established by the retained record.

## 9. Research decision

There is only one literal Euclidean direction \(-\nabla J_C\). On this regular
graph, the retained fixed diagonal gives the same direction. Further runs
that change only the scalar learning-rate units, normalization, or update cap
repeat the same mechanism rather than define a new method. Registered evidence
closes the performance-seeking extension from 30 to 90 updates; the registered
longer-budget stationarity continuation remains unfinished.

The following distinctions should remain explicit:

| construction | status relative to this note |
|---|---|
| Positive scalar rescaling of the projected gradient flow | Same continuous path; changes timing only |
| Frozen 17-point projected-gradient protocol | Registered 0/200 at 1.5 dB through 90 updates; registered continuation unfinished |
| Another finite scalar step sequence | Not universally closed; needs a declared no-jump argument |
| Update with momentum or another auxiliary state | Uses partial derivatives but is not the literal \(-\nabla J_C\) flow; unclosed and not justified merely because it is unrun |
| Fixed nonscalar positive-definite matrix | Changes direction and basin; not closed by Euclidean stationarity |
| Simple state-dependent two-hop positive-definite matrix | Active causal branch; retained fit only, with no fresh direction or decoder result |
| Check-local replicas with multipliers | Expanded-variable optimization, not \(-\nabla J_C\) on the one-scalar objective |

The practical stopping statement is therefore:

> Stop treating scalar step, normalization, or budget variations of the
> one-scalar Euclidean projected \(-\nabla J_C\) protocol as new performance
> routes at 1.5 dB. Do not claim that state-dependent matrices, finite
> nonmonotone jumps, different objectives, or expanded-variable methods are
> impossible.

The active matrix question is not whether some positive-definite \(P\) exists
pointwise; the lemma shows that this is almost vacuous whenever a strict
descent direction is already known. The useful question is whether a frozen,
simple, recipient-excluded, graph-local, well-conditioned, \(O(E)\) rule
\(P(x,L)\) can calculate a successful direction without BP, a teacher
direction, or the transmitted word at inference. That is the purpose of the
unopened two-hop direction screen.

## Source boundary

- The objective, fixed diagonal, registered vector, and protocol-specific
  claim boundary are recorded in
  [`rq2_jc_projected_stationarity_001_card.md`](rq2_jc_projected_stationarity_001_card.md).
- The interval-Hessian positive-rim and finite no-lower-jump design is
  recorded in
  [`proposed_jc_mean_coordinate_barrier_card.md`](proposed_jc_mean_coordinate_barrier_card.md).
- The active two-hop branch and recurrence cross-tabulation are recorded in
  [`active_goal.md`](active_goal.md).
- The unregistered numerical values came from the external indicative folder
  `_claude_stationarity_indicative_20261107`; that folder explicitly labels
  itself unregistered and contains no registered primary/replay execution.
