#!/usr/bin/env julia

using ConvexParityDistance
using ConvexParityDistanceLocalCurvature
using LinearAlgebra
using Printf

const CPD = ConvexParityDistance
const Adaptive = ConvexParityDistanceLocalCurvature

function synthetic_regular_problem(; n=10_200)
    iseven(n) || throw(ArgumentError("synthetic block length must be even"))
    m = n ÷ 2
    checks = Vector{Vector{Int}}(undef, m)
    for zero_check in 0:(m - 1)
        checks[zero_check + 1] = Int[
            zero_check + 1,
            mod(zero_check + 1, m) + 1,
            mod(zero_check + 2, m) + 1,
            m + zero_check + 1,
            m + mod(zero_check + 3, m) + 1,
            m + mod(zero_check + 7, m) + 1,
        ]
    end
    llr = [0.65sin(0.013index) + 0.31cos(0.007index) +
           0.09sin(0.031index) for index in 1:n]
    CPD.Problem(checks, llr)
end

function benchmark_adaptive(problem; updates=1_000)
    state = Adaptive.initialize_state(problem)
    workspace = Adaptive.AdaptiveWorkspace(problem)
    summaries = Adaptive.AdaptiveStepSummary[]
    elapsed = @elapsed begin
        for _ in 1:updates
            summary = Adaptive.adaptive_step!(workspace, problem, state)
            push!(summaries, summary)
            summary.stationary && break
        end
    end
    checkpoint = Adaptive.checkpoint_evaluate!(workspace, problem, state)
    (; elapsed, executed=length(summaries),
       objective_evaluations=sum(row.objective_evaluations for row in summaries),
       trial_evaluations=sum(row.trial_evaluations for row in summaries),
       backtracks=sum(row.backtracks for row in summaries),
       mapping=checkpoint.mapping_norm_inf,
       checksum=CPD.vector_sha256(state))
end

function benchmark_fixed(problem; updates=1_000)
    state = CPD.initialize_state(problem)
    workspace = CPD.SolverWorkspace(problem)
    elapsed = @elapsed for _ in 1:updates
        CPD.step!(workspace, problem, state)
    end
    checkpoint = CPD.checkpoint_evaluate!(workspace, problem, state)
    (; elapsed, executed=updates, objective_evaluations=updates,
       mapping=checkpoint.mapping_norm_inf,
       checksum=CPD.vector_sha256(state))
end

Threads.nthreads() == 1 || error("benchmark requires one Julia thread")
BLAS.set_num_threads(1)
problem = synthetic_regular_problem()
update_limit = isempty(ARGS) ? 1_000 : parse(Int, only(ARGS))
update_limit > 0 || throw(ArgumentError("update limit must be positive"))

# Compile both paths before measuring the production-size trajectories. The
# sliced production graph is not regular, so use a compact regular graph.
warm_checks = [
    [3, 4, 5, 6, 7, 8], [1, 2, 5, 6, 7, 8],
    [1, 2, 3, 4, 7, 8], [1, 2, 3, 4, 5, 6],
]
warm_problem = CPD.Problem(warm_checks, collect(range(-1.0, 1.0; length=8)))
warm_adaptive_state = Adaptive.initialize_state(warm_problem)
Adaptive.adaptive_step!(Adaptive.AdaptiveWorkspace(warm_problem), warm_problem,
                        warm_adaptive_state)
warm_fixed_state = CPD.initialize_state(warm_problem)
CPD.step!(CPD.SolverWorkspace(warm_problem), warm_problem, warm_fixed_state)

adaptive = benchmark_adaptive(problem; updates=update_limit)
adaptive_replay = benchmark_adaptive(problem; updates=update_limit)
fixed = benchmark_fixed(problem; updates=update_limit)

adaptive.checksum == adaptive_replay.checksum || error(
    "adaptive synthetic replay checksum differs")
adaptive.executed == adaptive_replay.executed || error(
    "adaptive synthetic replay update count differs")
adaptive.objective_evaluations == adaptive_replay.objective_evaluations || error(
    "adaptive synthetic replay evaluation count differs")

@printf("synthetic_n=%d synthetic_m=%d update_limit=%d\n",
        length(problem.llr), length(problem.checks), update_limit)
@printf("adaptive_seconds=%.9f adaptive_updates=%d adaptive_objective_evaluations=%d adaptive_trial_evaluations=%d adaptive_backtracks=%d adaptive_mapping_inf=%.17g adaptive_checksum=%s\n",
        adaptive.elapsed, adaptive.executed, adaptive.objective_evaluations,
        adaptive.trial_evaluations, adaptive.backtracks, adaptive.mapping,
        adaptive.checksum)
@printf("adaptive_replay_seconds=%.9f adaptive_replay_checksum=%s\n",
        adaptive_replay.elapsed, adaptive_replay.checksum)
@printf("fixed_seconds=%.9f fixed_updates=%d fixed_objective_evaluations=%d fixed_mapping_inf=%.17g fixed_checksum=%s\n",
        fixed.elapsed, fixed.executed, fixed.objective_evaluations,
        fixed.mapping, fixed.checksum)
