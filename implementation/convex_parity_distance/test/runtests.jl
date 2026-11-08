using ConvexParityDistance
using LinearAlgebra
using Random
using Test

function even_vertices(d::Int=CHECK_DEGREE)
    [Float64[(mask >> (index - 1)) & 1 for index in 1:d]
     for mask in 0:(2^d - 1) if iseven(count_ones(mask))]
end

function odd_facets(d::Int=CHECK_DEGREE)
    [(Float64[isone((mask >> (index - 1)) & 1) ? 1.0 : -1.0
              for index in 1:d], count_ones(mask) - 1)
     for mask in 0:(2^d - 1) if isodd(count_ones(mask))]
end

const EVEN_VERTICES = even_vertices()
const ODD_FACETS = odd_facets()

function projection_certificate(input, projection; tolerance=2.0e-12)
    @test all(-tolerance .<= projection .<= 1.0 + tolerance)
    for (normal, bound) in ODD_FACETS
        @test dot(normal, projection) <= bound + tolerance
    end
    residual = input - projection
    for vertex in EVEN_VERTICES
        # This variational inequality over every vertex independently
        # certifies Euclidean projection onto their convex hull.
        @test dot(residual, vertex - projection) <= tolerance
    end
end

function synthetic_problem(llr=zeros(8))
    checks = [
        [3, 4, 5, 6, 7, 8],
        [1, 2, 5, 6, 7, 8],
        [1, 2, 3, 4, 7, 8],
        [1, 2, 3, 4, 5, 6],
    ]
    Problem(checks, llr)
end

@testset "frozen constants and problem boundary" begin
    @test CHECK_DEGREE == 6
    @test VARIABLE_DEGREE == 3
    @test PARITY_WEIGHT == 96.0
    @test STEP_SIZE == 1.0 / 288.0
    @test DISTANCE_TOLERANCE == 1.0e-10

    problem = synthetic_problem(collect(range(-2.0, 2.0; length=8)))
    @test length(problem.checks) == 4
    @test all(length(check) == 6 for check in problem.checks)
    @test_throws ArgumentError Problem(problem.checks[1:3], problem.llr)
    @test_throws ArgumentError Problem([[1, 1, 2, 3, 4, 5]], zeros(5))
    @test_throws ArgumentError Problem([[1, 2, 3, 4, 5, 9]], zeros(8))
    @test_throws ArgumentError Problem(problem.checks, [Inf; zeros(7)])
end

@testset "parity-polytope projection vertices and analytic literals" begin
    for vertex in EVEN_VERTICES
        @test parity_project_box(vertex) == vertex
    end

    one_error = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    expected = [5 / 6; fill(1 / 6, 5)]
    actual = parity_project_box(one_error)
    @test actual ≈ expected atol=3.0e-16 rtol=0.0
    projection_certificate(one_error, actual)

    two_coordinates = [0.9, 0.1, 0.0, 0.0, 0.0, 0.0]
    expected_two = [23 / 30, 7 / 30, 2 / 15, 2 / 15, 2 / 15, 2 / 15]
    projected_two = parity_project_box(two_coordinates)
    @test projected_two ≈ expected_two atol=3.0e-16
    projection_certificate(two_coordinates, projected_two)

    @test parity_project_box(fill(0.5, 6)) == fill(0.5, 6)
    @test_throws DimensionMismatch parity_project_box(zeros(5))
    @test_throws ArgumentError parity_project_box([1.1; zeros(5)])
    @test_throws ArgumentError parity_project_box([NaN; zeros(5)])
end

@testset "exhaustive odd vertices" begin
    for mask in 0:63
        isodd(count_ones(mask)) || continue
        input = Float64[(mask >> (index - 1)) & 1 for index in 1:6]
        projection = parity_project_box(input)
        projection_certificate(input, projection)
        @test sum(abs2, input - projection) ≈ 1 / 6 atol=8.0e-16
    end
end

@testset "random projection certificates and symmetries" begin
    rng = MersenneTwister(0x5eed)
    for _ in 1:1_000
        input = rand(rng, 6)
        projection = parity_project_box(input)
        projection_certificate(input, projection)
        @test parity_project_box(projection) ≈ projection atol=2.0e-15 rtol=0.0

        permutation = randperm(rng, 6)
        @test parity_project_box(input[permutation]) ≈
              projection[permutation] atol=2.0e-15 rtol=0.0

        weights = rand(rng, length(EVEN_VERTICES))
        weights ./= sum(weights)
        feasible = sum(weights[index] .* EVEN_VERTICES[index]
                       for index in eachindex(weights))
        @test parity_project_box(feasible) ≈ feasible atol=2.0e-15 rtol=0.0
    end

    repeated = [0.8, 0.8, 0.2, 0.2, 0.2, 0.2]
    baseline = parity_project_box(repeated)
    for permutation in ([2, 1, 3, 4, 5, 6], [1, 2, 6, 5, 4, 3])
        @test parity_project_box(repeated[permutation]) ≈
              baseline[permutation] atol=2.0e-15 rtol=0.0
    end
end

@testset "objective partial derivatives" begin
    llr = [-2.3, 1.7, -0.8, 0.4, 2.1, -1.2, 0.9, -0.3]
    problem = synthetic_problem(llr)
    state = [0.13, 0.81, 0.27, 0.68, 0.44, 0.92, 0.35, 0.57]
    evaluated = objective_gradient(problem, state)
    @test evaluated.value ≈ length(state) * evaluated.normalized_value
    @test evaluated.value ≈ evaluated.signal + evaluated.parity
    @test evaluated.normalized_value ≈
          evaluated.normalized_signal + evaluated.normalized_parity
    @test evaluated.parity ≈
          0.5 * PARITY_WEIGHT * evaluated.squared_distance_sum
    manual_count = sum(
        norm(state[check] - parity_project_box(state[check])) >
            DISTANCE_TOLERANCE
        for check in problem.checks)
    @test evaluated.checks_above_distance_tolerance == manual_count

    step = 1.0e-6
    for bit in eachindex(state)
        function value_at(offset)
            trial = copy(state)
            trial[bit] += offset
            objective_gradient(problem, trial).value
        end
        numerical = (value_at(-2step) - 8value_at(-step) +
                     8value_at(step) - value_at(2step)) / (12step)
        @test numerical ≈ evaluated.gradient[bit] atol=2.0e-8 rtol=2.0e-9
        @test evaluated.normalized_gradient[bit] ≈
              evaluated.gradient[bit] / length(state)
    end
end

@testset "convexity, Lipschitz bound, and fixed-step descent" begin
    rng = MersenneTwister(0xc0ffee)
    problem = synthetic_problem(randn(rng, 8))
    lipschitz_bound = PARITY_WEIGHT * VARIABLE_DEGREE
    for _ in 1:300
        first = rand(rng, 8)
        second = rand(rng, 8)
        theta = rand(rng)
        mixture = theta .* first .+ (1.0 - theta) .* second
        f_first = objective_gradient(problem, first)
        f_second = objective_gradient(problem, second)
        f_mixture = objective_gradient(problem, mixture)
        @test f_mixture.value <=
              theta * f_first.value + (1.0 - theta) * f_second.value + 2e-12
        @test norm(f_first.gradient - f_second.gradient) <=
              lipschitz_bound * norm(first - second) + 2e-11

        update = projected_gradient_step(problem, first)
        @test update.objective_after <= update.objective_before + 3e-12
        @test all(0.0 .<= update.state .<= 1.0)
        @test update.mapping ≈
              (first - update.state) ./ STEP_SIZE atol=0.0 rtol=0.0
    end

    zero_problem = synthetic_problem(zeros(8))
    fixed = fill(0.5, 8)
    mapping = projected_gradient_mapping(zero_problem, fixed)
    @test mapping.norm_inf == 0.0
    @test mapping.trial == fixed
end

@testset "in-place evaluation and update" begin
    problem = synthetic_problem([-1.4, 0.6, -0.2, 1.1, -1.8, 0.3, 0.8, -0.9])
    state = [0.12, 0.76, 0.31, 0.64, 0.48, 0.87, 0.23, 0.59]
    workspace = SolverWorkspace(problem)

    allocating = objective_gradient(problem, state)
    in_place = evaluate!(workspace, problem, state)
    @test in_place.value == allocating.value
    @test in_place.gradient == allocating.gradient
    @test in_place.gradient === workspace.gradient

    checkpoint_state = copy(state)
    checkpoint = checkpoint_evaluate!(workspace, problem, checkpoint_state;
                                      capture_hash=true)
    mapping = projected_gradient_mapping(problem, state)
    @test checkpoint_state == state
    @test checkpoint.value == allocating.value
    @test checkpoint.squared_distance_sum == allocating.squared_distance_sum
    @test checkpoint.maximum_check_distance == allocating.maximum_check_distance
    @test checkpoint.infeasible_checks == allocating.infeasible_checks
    @test checkpoint.checks_above_distance_tolerance ==
          allocating.checks_above_distance_tolerance
    @test checkpoint.mapping_norm_inf == mapping.norm_inf
    @test checkpoint.state_sha256 == vector_sha256(state)
    @test checkpoint.gradient === workspace.gradient

    expected = projected_gradient_step(problem, state)
    actual_state = copy(state)
    result = step!(workspace, problem, actual_state)
    @test actual_state == expected.state
    @test result.objective_before == expected.objective_before
    @test result.mapping_norm_inf == expected.mapping_norm_inf

    audited_state = copy(state)
    audited = audited_step!(workspace, problem, audited_state;
                            evaluate_after=true, capture_hashes=true,
                            capture_gradient=true)
    @test audited_state == expected.state
    @test audited.objective_after == expected.objective_after
    @test audited.gradient == expected.gradient
    @test audited.state_before_sha256 == expected.state_before_sha256
    @test audited.state_after_sha256 == expected.state_after_sha256
end

@testset "initialization, readout, syndrome, and ties" begin
    problem = synthetic_problem([4.0, -4.0, 2.0, -2.0, 1.0, -1.0, 0.5, -0.5])
    initial = initialize_state(problem)
    @test initial[1] < 0.5 < initial[2]
    @test initial[3] < 0.5 < initial[4]
    @test all(0.0 .<= initial .<= 1.0)

    all_zero = zeros(8)
    diagnostics = readout_diagnostics(problem, all_zero)
    @test diagnostics.hard == falses(8)
    @test diagnostics.syndrome_weight == 0
    @test diagnostics.tie_count == 0
    @test diagnostics.parity_valid

    workspace = SolverWorkspace(problem)
    buffered = readout!(workspace, problem, all_zero)
    @test buffered.syndrome_weight == diagnostics.syndrome_weight
    @test buffered.tie_count == diagnostics.tie_count
    @test buffered.parity_valid == diagnostics.parity_valid
    @test workspace.hard == diagnostics.hard
    @test workspace.syndrome == diagnostics.syndrome

    tied = copy(all_zero)
    tied[1] = 0.5
    tie_diagnostics = readout_diagnostics(problem, tied)
    @test tie_diagnostics.tie_count == 1
    @test !tie_diagnostics.parity_valid
    buffered_tie = readout!(workspace, problem, tied)
    @test buffered_tie.tie_count == 1
    @test !buffered_tie.parity_valid

    odd = falses(8)
    odd[1] = true
    @test count(identity, syndrome(problem.checks, odd)) == 3

    odd_state = Float64.(odd)
    buffered_odd = readout!(workspace, problem, odd_state)
    @test buffered_odd.syndrome_weight == 3
    @test workspace.hard == odd
end

@testset "deterministic hashes and replay" begin
    problem = synthetic_problem([-1.8, 0.9, -0.4, 1.3, -2.1, 0.2, 0.7, -1.1])
    function trace()
        state = initialize_state(problem)
        rows = NamedTuple[]
        for update in 1:12
            result = projected_gradient_step(problem, state)
            push!(rows, (; update,
                before=result.state_before_sha256,
                after=result.state_after_sha256,
                hard=result.hard_sha256,
                objective_before=result.objective_before,
                objective_after=result.objective_after))
            state = result.state
        end
        (; state, rows)
    end
    first = trace()
    second = trace()
    @test first.state == second.state
    @test first.rows == second.rows
    @test vector_sha256(first.state) == vector_sha256(second.state)
    @test all(row.objective_after <= row.objective_before + 3e-12
              for row in first.rows)
end
