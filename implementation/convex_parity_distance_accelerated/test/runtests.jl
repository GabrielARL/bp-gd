using ConvexParityDistance
using ConvexParityDistanceAccelerated
using Random
using Test

const CPD = ConvexParityDistance
const Accelerated = ConvexParityDistanceAccelerated
const REFERENCE_RTOL = 128eps(Float64)
const REFERENCE_ATOL = 128eps(Float64)

reference_close(left, right) = isapprox(
    left, right; rtol=REFERENCE_RTOL, atol=REFERENCE_ATOL)

function synthetic_problem(llr=zeros(8))
    checks = [
        [3, 4, 5, 6, 7, 8],
        [1, 2, 5, 6, 7, 8],
        [1, 2, 3, 4, 7, 8],
        [1, 2, 3, 4, 5, 6],
    ]
    CPD.Problem(checks, llr)
end

function reference_trace(problem, updates)
    initial = CPD.initialize_state(problem)
    query = copy(initial)
    output = copy(initial)
    mirror = copy(initial)
    gradient_sum = zeros(length(initial))
    rows = NamedTuple[]
    for zero_iteration in 0:(updates - 1)
        evaluated = CPD.objective_gradient(problem, query)
        gradient_weight = (zero_iteration + 1) / 2.0
        coupling_weight = 2.0 / (zero_iteration + 3.0)
        output = clamp.(query .- evaluated.gradient ./ GLOBAL_CURVATURE,
                        0.0, 1.0)
        gradient_sum .+= gradient_weight .* evaluated.gradient
        mirror = clamp.(initial .- gradient_sum ./ GLOBAL_CURVATURE,
                        0.0, 1.0)
        query = (1.0 - coupling_weight) .* output .+
                coupling_weight .* mirror
        push!(rows, (; output=copy(output), query=copy(query),
                     mirror=copy(mirror), gradient_sum=copy(gradient_sum),
                     objective=evaluated.value, gradient_weight,
                     coupling_weight))
    end
    (; initial, output, query, mirror, gradient_sum, rows)
end

function implementation_trace(problem, updates)
    state = Accelerated.initialize_state(problem)
    workspace = AcceleratedWorkspace(problem)
    rows = NamedTuple[]
    for _ in 1:updates
        summary = Accelerated.accelerated_step!(workspace, problem, state)
        push!(rows, (; output=copy(state), query=copy(workspace.query),
                     mirror=copy(workspace.mirror),
                     gradient_sum=copy(workspace.gradient_sum), summary))
    end
    (; state=copy(state), query=copy(workspace.query),
       mirror=copy(workspace.mirror),
       gradient_sum=copy(workspace.gradient_sum), rows)
end

function production_synthetic_problem(; n=10_200)
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

@testset "frozen accelerated constants and dependency" begin
    @test PARITY_WEIGHT == CPD.PARITY_WEIGHT == 96.0
    @test GLOBAL_CURVATURE == 288.0
    @test Problem === CPD.Problem
end

@testset "first output is the unchanged fixed projected-gradient step" begin
    problem = synthetic_problem([-2.3, 1.7, -0.8, 0.4, 2.1, -1.2, 0.9, -0.3])
    state = Accelerated.initialize_state(problem)
    initial = copy(state)
    fixed = CPD.projected_gradient_step(problem, initial)
    workspace = AcceleratedWorkspace(problem)
    summary = Accelerated.accelerated_step!(workspace, problem, state)

    @test state == fixed.state
    @test workspace.output == fixed.state
    @test summary.iteration == 1
    @test summary.gradient_weight == 0.5
    @test summary.coupling_weight == 2 / 3
    @test summary.objective_at_query == fixed.objective_before
    @test summary.query_mapping_inf == fixed.mapping_norm_inf
    @test all(0.0 .<= workspace.query .<= 1.0)
    @test all(0.0 .<= workspace.output .<= 1.0)
    @test all(0.0 .<= workspace.mirror .<= 1.0)
end

@testset "independent trajectory reproduction and feasible queries" begin
    rng = MersenneTwister(0xacce1e)
    for _ in 1:40
        problem = synthetic_problem(4.0 .* randn(rng, 8))
        expected = reference_trace(problem, 100)
        state = Accelerated.initialize_state(problem)
        workspace = AcceleratedWorkspace(problem)
        for update in 1:100
            summary = Accelerated.accelerated_step!(workspace, problem, state)
            row = expected.rows[update]
            # The allocating broadcast reference has a different floating-point
            # operation order from the scalar in-place implementation.  Compare
            # it at a tight roundoff tolerance; exact replay is a separate gate.
            @test reference_close(state, row.output)
            @test reference_close(workspace.output, row.output)
            @test reference_close(workspace.query, row.query)
            @test reference_close(workspace.mirror, row.mirror)
            @test reference_close(workspace.gradient_sum, row.gradient_sum)
            @test reference_close(summary.objective_at_query, row.objective)
            @test summary.gradient_weight == row.gradient_weight
            @test summary.coupling_weight == row.coupling_weight
            @test 0.0 <= summary.query_minimum <= summary.query_maximum <= 1.0
            @test 0.0 <= summary.output_minimum <= summary.output_maximum <= 1.0
            @test 0.0 <= summary.mirror_minimum <= summary.mirror_maximum <= 1.0
        end
    end
end

@testset "unchanged checkpoint mapping and readout" begin
    problem = synthetic_problem([-1.4, 0.6, -0.2, 1.1, -1.8, 0.3, 0.8, -0.9])
    state = Accelerated.initialize_state(problem)
    workspace = AcceleratedWorkspace(problem)
    for _ in 1:12
        Accelerated.accelerated_step!(workspace, problem, state)
    end
    before = copy(state)
    accelerated_checkpoint = Accelerated.checkpoint_evaluate!(
        workspace, problem, state; capture_hash=true)
    base_checkpoint = CPD.checkpoint_evaluate!(
        CPD.SolverWorkspace(problem), problem, state; capture_hash=true)
    @test state == before
    @test accelerated_checkpoint.value == base_checkpoint.value
    @test accelerated_checkpoint.gradient == base_checkpoint.gradient
    @test accelerated_checkpoint.mapping_norm_inf == base_checkpoint.mapping_norm_inf
    @test accelerated_checkpoint.state_sha256 == base_checkpoint.state_sha256

    accelerated_readout = Accelerated.readout!(workspace, problem, state)
    base_workspace = CPD.SolverWorkspace(problem)
    base_readout = CPD.readout!(base_workspace, problem, state)
    @test accelerated_readout == base_readout
    @test workspace.checkpoint.hard == base_workspace.hard
    @test workspace.checkpoint.syndrome == base_workspace.syndrome
end

@testset "external mutation fails closed" begin
    problem = synthetic_problem(fill(0.2, 8))
    state = Accelerated.initialize_state(problem)
    workspace = AcceleratedWorkspace(problem)
    Accelerated.accelerated_step!(workspace, problem, state)
    state[1] = 0.37
    @test_throws ArgumentError Accelerated.accelerated_step!(
        workspace, problem, state)

    wrong_initial = Accelerated.initialize_state(problem)
    wrong_initial[1] = 0.37
    @test_throws ArgumentError Accelerated.accelerated_step!(
        AcceleratedWorkspace(problem), problem, wrong_initial)
end

@testset "deterministic replay" begin
    problem = synthetic_problem([-1.8, 0.9, -0.4, 1.3, -2.1, 0.2, 0.7, -1.1])
    first = implementation_trace(problem, 300)
    second = implementation_trace(problem, 300)
    @test first.state == second.state
    @test first.query == second.query
    @test first.mirror == second.mirror
    @test first.gradient_sum == second.gradient_sum
    @test first.rows == second.rows
    @test CPD.vector_sha256(first.state) == CPD.vector_sha256(second.state)
end

@testset "production-size synthetic progress witness" begin
    problem = production_synthetic_problem()
    accelerated_state = Accelerated.initialize_state(problem)
    accelerated_workspace = AcceleratedWorkspace(problem)
    for _ in 1:1_000
        Accelerated.accelerated_step!(accelerated_workspace, problem,
                                      accelerated_state)
    end
    accelerated_mapping = Accelerated.checkpoint_evaluate!(
        accelerated_workspace, problem, accelerated_state).mapping_norm_inf

    fixed_state = CPD.initialize_state(problem)
    fixed_workspace = CPD.SolverWorkspace(problem)
    for _ in 1:1_000
        CPD.step!(fixed_workspace, problem, fixed_state)
    end
    fixed_mapping = CPD.checkpoint_evaluate!(
        fixed_workspace, problem, fixed_state).mapping_norm_inf
    @test accelerated_mapping < fixed_mapping
    @test accelerated_mapping <= 0.25fixed_mapping
end
