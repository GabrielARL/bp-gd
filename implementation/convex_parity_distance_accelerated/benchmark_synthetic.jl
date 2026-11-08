#!/usr/bin/env julia

using ConvexParityDistance
using ConvexParityDistanceAccelerated
using LinearAlgebra
using Printf

const CPD = ConvexParityDistance
const Accelerated = ConvexParityDistanceAccelerated

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

function benchmark_accelerated(problem, update_limit)
    state = Accelerated.initialize_state(problem)
    workspace = Accelerated.AcceleratedWorkspace(problem)
    elapsed = @elapsed for _ in 1:update_limit
        Accelerated.accelerated_step!(workspace, problem, state)
    end
    checkpoint = Accelerated.checkpoint_evaluate!(workspace, problem, state)
    (; elapsed, mapping=checkpoint.mapping_norm_inf,
       checksum=CPD.vector_sha256(state),
       query_checksum=CPD.vector_sha256(workspace.query),
       mirror_checksum=CPD.vector_sha256(workspace.mirror))
end

function benchmark_fixed(problem, update_limit)
    state = CPD.initialize_state(problem)
    workspace = CPD.SolverWorkspace(problem)
    elapsed = @elapsed for _ in 1:update_limit
        CPD.step!(workspace, problem, state)
    end
    checkpoint = CPD.checkpoint_evaluate!(workspace, problem, state)
    (; elapsed, mapping=checkpoint.mapping_norm_inf,
       checksum=CPD.vector_sha256(state))
end

Threads.nthreads() == 1 || error("benchmark requires one Julia thread")
BLAS.set_num_threads(1)
update_limit = isempty(ARGS) ? 1_000 : parse(Int, only(ARGS))
update_limit > 0 || throw(ArgumentError("update limit must be positive"))
problem = synthetic_regular_problem()

# Compile on a compact regular graph before measuring the production-size path.
warm_checks = [
    [3, 4, 5, 6, 7, 8], [1, 2, 5, 6, 7, 8],
    [1, 2, 3, 4, 7, 8], [1, 2, 3, 4, 5, 6],
]
warm_problem = CPD.Problem(warm_checks, collect(range(-1.0, 1.0; length=8)))
warm_state = Accelerated.initialize_state(warm_problem)
Accelerated.accelerated_step!(Accelerated.AcceleratedWorkspace(warm_problem),
                              warm_problem, warm_state)

accelerated = benchmark_accelerated(problem, update_limit)
replay = benchmark_accelerated(problem, update_limit)
fixed = benchmark_fixed(problem, update_limit)

accelerated.checksum == replay.checksum || error(
    "accelerated synthetic replay output differs")
accelerated.query_checksum == replay.query_checksum || error(
    "accelerated synthetic replay query differs")
accelerated.mirror_checksum == replay.mirror_checksum || error(
    "accelerated synthetic replay mirror differs")

@printf("synthetic_n=%d synthetic_m=%d update_limit=%d\n",
        length(problem.llr), length(problem.checks), update_limit)
@printf("accelerated_seconds=%.9f accelerated_mapping_inf=%.17g accelerated_checksum=%s accelerated_query_checksum=%s accelerated_mirror_checksum=%s\n",
        accelerated.elapsed, accelerated.mapping, accelerated.checksum,
        accelerated.query_checksum, accelerated.mirror_checksum)
@printf("accelerated_replay_seconds=%.9f accelerated_replay_checksum=%s\n",
        replay.elapsed, replay.checksum)
@printf("fixed_seconds=%.9f fixed_mapping_inf=%.17g fixed_checksum=%s\n",
        fixed.elapsed, fixed.mapping, fixed.checksum)
