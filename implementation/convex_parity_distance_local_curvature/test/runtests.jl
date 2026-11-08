using ConvexParityDistance
using ConvexParityDistanceLocalCurvature
using LinearAlgebra
using Random
using Test

const CPD = ConvexParityDistance
const Adaptive = ConvexParityDistanceLocalCurvature

function synthetic_problem(llr=zeros(8))
    checks = [
        [3, 4, 5, 6, 7, 8],
        [1, 2, 5, 6, 7, 8],
        [1, 2, 3, 4, 7, 8],
        [1, 2, 3, 4, 5, 6],
    ]
    CPD.Problem(checks, llr)
end

function reference_first_step(problem, state)
    evaluated = CPD.objective_gradient(problem, state)
    curvature = INITIAL_CURVATURE
    for trial_index in 1:MAXIMUM_TRIALS
        trial = clamp.(state .- evaluated.gradient ./ curvature, 0.0, 1.0)
        displacement = trial - state
        trial_evaluation = CPD.objective_gradient(problem, trial)
        model = evaluated.value + dot(evaluated.gradient, displacement) +
            0.5 * curvature * sum(abs2, displacement)
        scale = max(1.0, abs(evaluated.value),
                    abs(trial_evaluation.value), abs(model))
        allowance = MAJORIZATION_ULPS * eps(Float64) * scale
        if trial_evaluation.value <= model + allowance &&
                trial_evaluation.value <= evaluated.value + allowance
            return (; trial, curvature, trial_index, model, allowance,
                    objective_before=evaluated.value,
                    objective_after=trial_evaluation.value)
        end
        curvature == GLOBAL_CURVATURE && error("reference search failed")
        curvature = min(GLOBAL_CURVATURE, BACKTRACK_FACTOR * curvature)
    end
    error("reference search exhausted")
end

function run_trace(problem, updates)
    state = Adaptive.initialize_state(problem)
    workspace = Adaptive.AdaptiveWorkspace(problem)
    rows = NamedTuple[]
    for update in 1:updates
        summary = Adaptive.adaptive_step!(workspace, problem, state)
        checkpoint = Adaptive.checkpoint_evaluate!(workspace, problem, state;
                                                   capture_hash=true)
        push!(rows, (; update, summary, state=copy(state),
                     state_sha256=checkpoint.state_sha256,
                     mapping=checkpoint.mapping_norm_inf))
        summary.stationary && break
    end
    (; state, rows)
end

@testset "frozen successor constants and dependency" begin
    @test PARITY_WEIGHT == CPD.PARITY_WEIGHT == 96.0
    @test GLOBAL_CURVATURE == 288.0
    @test MINIMUM_CURVATURE == 1.0
    @test INITIAL_CURVATURE == 1.0
    @test BACKTRACK_FACTOR == 2.0
    @test MAXIMUM_TRIALS == 10
    @test MAJORIZATION_ULPS == 256.0
    @test Problem === CPD.Problem
end

@testset "unchanged initialization, objective, mapping, and readout" begin
    problem = synthetic_problem([-2.3, 1.7, -0.8, 0.4, 2.1, -1.2, 0.9, -0.3])
    state = [0.13, 0.81, 0.27, 0.68, 0.44, 0.92, 0.35, 0.57]
    workspace = AdaptiveWorkspace(problem)

    @test Adaptive.initialize_state(problem) == CPD.initialize_state(problem)
    before = copy(state)
    adaptive_checkpoint = Adaptive.checkpoint_evaluate!(
        workspace, problem, state; capture_hash=true)
    base_checkpoint = CPD.checkpoint_evaluate!(
        CPD.SolverWorkspace(problem), problem, state; capture_hash=true)
    @test state == before
    @test adaptive_checkpoint.value == base_checkpoint.value
    @test adaptive_checkpoint.gradient == base_checkpoint.gradient
    @test adaptive_checkpoint.mapping_norm_inf == base_checkpoint.mapping_norm_inf
    @test adaptive_checkpoint.squared_distance_sum ==
          base_checkpoint.squared_distance_sum
    @test adaptive_checkpoint.state_sha256 == base_checkpoint.state_sha256

    adaptive_readout = Adaptive.readout!(workspace, problem, state)
    base_workspace = CPD.SolverWorkspace(problem)
    base_readout = CPD.readout!(base_workspace, problem, state)
    @test adaptive_readout == base_readout
    @test workspace.checkpoint.hard == base_workspace.hard
    @test workspace.checkpoint.syndrome == base_workspace.syndrome
end

@testset "first step matches independent majorization search" begin
    rng = MersenneTwister(0x51eed)
    witnessed_backtrack = false
    for _ in 1:200
        problem = synthetic_problem(4.0 .* randn(rng, 8))
        state = rand(rng, 8)
        expected = reference_first_step(problem, state)
        actual_state = copy(state)
        workspace = AdaptiveWorkspace(problem)
        summary = Adaptive.adaptive_step!(workspace, problem, actual_state)

        @test actual_state == expected.trial
        @test summary.seed_curvature == INITIAL_CURVATURE
        @test summary.seed_kind == :initial
        @test isnan(summary.secant_curvature)
        @test summary.accepted_curvature == expected.curvature
        @test summary.trial_evaluations == expected.trial_index
        @test summary.objective_evaluations == expected.trial_index + 1
        @test summary.objective_before == expected.objective_before
        @test summary.objective_after == expected.objective_after
        @test summary.model_upper_bound == expected.model
        @test summary.majorization_allowance == expected.allowance
        @test summary.projection_inequality <=
              summary.majorization_allowance
        @test summary.objective_after <=
              summary.model_upper_bound + summary.majorization_allowance
        @test summary.objective_after <=
              summary.objective_before + summary.majorization_allowance
        @test 0.0 <= minimum(actual_state) <= maximum(actual_state) <= 1.0
        witnessed_backtrack |= summary.backtracks > 0
    end
    @test witnessed_backtrack
end

@testset "sequential cache, secant seed, and monotone trajectories" begin
    rng = MersenneTwister(0xc011ab1e)
    secant_witnessed = false
    cached_witnessed = false
    fallback_witnessed = false
    for case_index in 1:30
        problem = synthetic_problem(3.0 .* randn(rng, 8))
        state = Adaptive.initialize_state(problem)
        workspace = AdaptiveWorkspace(problem)
        previous = CPD.objective_gradient(problem, state).value
        for update in 1:80
            summary = Adaptive.adaptive_step!(workspace, problem, state)
            @test MINIMUM_CURVATURE <= summary.accepted_curvature <=
                  GLOBAL_CURVATURE
            @test inv(GLOBAL_CURVATURE) <= summary.step_size <=
                  inv(MINIMUM_CURVATURE)
            @test 0 <= summary.backtracks < MAXIMUM_TRIALS
            @test summary.objective_after <=
                  previous + summary.majorization_allowance
            @test summary.projection_inequality <=
                  summary.majorization_allowance
            @test all(0.0 .<= state .<= 1.0)
            if !summary.stationary
                @test summary.objective_after <=
                      summary.model_upper_bound + summary.majorization_allowance
                @test summary.projected_mapping_inf > 0.0
            end
            update > 1 && (cached_witnessed |= summary.objective_evaluations ==
                                               summary.trial_evaluations)
            secant_witnessed |= summary.seed_kind == :secant
            fallback_witnessed |= summary.seed_kind == :fallback
            previous = summary.objective_after
            summary.stationary && break
        end
    end
    @test secant_witnessed
    @test cached_witnessed
    @test fallback_witnessed
end

@testset "external state mutation invalidates cache and secant history" begin
    problem = synthetic_problem([-1.4, 0.6, -0.2, 1.1, -1.8, 0.3, 0.8, -0.9])
    state = Adaptive.initialize_state(problem)
    workspace = AdaptiveWorkspace(problem)
    first = Adaptive.adaptive_step!(workspace, problem, state)
    @test !first.stationary
    state[1] = 0.37
    expected = reference_first_step(problem, state)
    second = Adaptive.adaptive_step!(workspace, problem, state)
    @test second.seed_kind == :initial
    @test second.objective_evaluations == second.trial_evaluations + 1
    @test second.accepted_curvature == expected.curvature
    @test state == expected.trial
end

@testset "fixed-map stationarity and linear-region acceleration" begin
    zero_problem = synthetic_problem(zeros(8))
    zero_state = fill(0.5, 8)
    zero_workspace = AdaptiveWorkspace(zero_problem)
    zero_summary = Adaptive.adaptive_step!(
        zero_workspace, zero_problem, zero_state)
    @test zero_summary.stationary
    @test zero_summary.trial_evaluations == 0
    @test zero_summary.objective_evaluations == 1
    @test zero_summary.projected_mapping_inf == 0.0
    @test Adaptive.checkpoint_evaluate!(
        zero_workspace, zero_problem, zero_state).mapping_norm_inf == 0.0

    linear_problem = synthetic_problem(fill(0.1, 8))
    adaptive_state = Adaptive.initialize_state(linear_problem)
    adaptive_workspace = AdaptiveWorkspace(linear_problem)
    adaptive_updates = 0
    while Adaptive.checkpoint_evaluate!(
            adaptive_workspace, linear_problem,
            adaptive_state).mapping_norm_inf > 1.0e-12
        adaptive_updates += 1
        Adaptive.adaptive_step!(adaptive_workspace, linear_problem,
                                adaptive_state)
        adaptive_updates <= 20 || error("adaptive linear fixture did not stop")
    end

    fixed_state = CPD.initialize_state(linear_problem)
    fixed_workspace = CPD.SolverWorkspace(linear_problem)
    fixed_updates = 0
    while CPD.checkpoint_evaluate!(
            fixed_workspace, linear_problem,
            fixed_state).mapping_norm_inf > 1.0e-12
        fixed_updates += 1
        CPD.step!(fixed_workspace, linear_problem, fixed_state)
        fixed_updates <= 2_000 || error("fixed linear fixture did not stop")
    end
    @test adaptive_state == zeros(8)
    @test fixed_state == zeros(8)
    @test adaptive_updates <= 5
    @test fixed_updates >= 1_000
    @test 200adaptive_updates < fixed_updates
end

@testset "deterministic replay" begin
    problem = synthetic_problem([-1.8, 0.9, -0.4, 1.3, -2.1, 0.2, 0.7, -1.1])
    first = run_trace(problem, 100)
    second = run_trace(problem, 100)
    @test first.state == second.state
    @test length(first.rows) == length(second.rows)
    @test first.rows == second.rows
    @test CPD.vector_sha256(first.state) == CPD.vector_sha256(second.state)
end
