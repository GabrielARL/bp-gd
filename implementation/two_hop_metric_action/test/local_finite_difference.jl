using LinearAlgebra
using Test

if !isdefined(Main, :RQ2CompoundObjectiveJC)
    include(joinpath(@__DIR__, "..", "compound_objective_jc.jl"))
end
const JC = RQ2CompoundObjectiveJC

function five_point_testlocal_derivative(value_function, state, coordinate;
                                         step=1.0e-5)
    plus_one = copy(state)
    minus_one = copy(state)
    plus_two = copy(state)
    minus_two = copy(state)
    plus_one[coordinate] += step
    minus_one[coordinate] -= step
    plus_two[coordinate] += 2step
    minus_two[coordinate] -= 2step
    (-value_function(plus_two) + 8value_function(plus_one) -
     8value_function(minus_one) + value_function(minus_two)) / (12step)
end

@testset "finite-difference action with retained V5 coefficients" begin
    graph = repeated_path_graph()
    pattern = TwoHopPattern(graph)
    edges = edge_count(graph)
    z = [0.73sin(0.29edge) - 0.06cos(0.17edge) for edge in 1:edges]
    llr = [17.0sin(0.37variable) for variable in 1:graph.n]
    partial_derivatives = [0.31sin(0.23edge) + 0.19cos(0.41edge)
                           for edge in 1:edges]
    metric = [0.3 + 0.09edge for edge in 1:edges]
    coefficients = MetricCoefficients(
        0.0,
        [-0.098969711158939794,
         -0.19129556359240465,
         -0.70584476358886339,
         -0.0036899816577923542],
    )

    _, matrix_a, _ = explicit_direction(
        graph, pattern, z, llr, partial_derivatives, metric, coefficients)
    inverse_square_root = Diagonal(1.0 ./ sqrt.(metric))
    exact_jacobian = -(inverse_square_root * matrix_a * inverse_square_root)
    step = 2.0^-20

    for coordinate in eachindex(partial_derivatives)
        plus = copy(partial_derivatives)
        minus = copy(partial_derivatives)
        plus[coordinate] += step
        minus[coordinate] -= step
        plus_direction = generic_metric_action(
            graph, pattern, z, llr, plus, metric, coefficients).direction
        minus_direction = generic_metric_action(
            graph, pattern, z, llr, minus, metric, coefficients).direction
        finite_difference = (plus_direction - minus_direction) / (2step)
        @test finite_difference ≈ exact_jacobian[:, coordinate] atol=2.0e-9 rtol=2.0e-9
    end
end

@testset "synthetic J_C partial derivatives compose with the metric action" begin
    # Same graph, state, and LLR arrays as the Stage-B kernel's synthetic
    # source test.  They are literals, not a generated or registered frame.
    graph = EdgeGraph([[1, 2, 3], [1, 2, 4]], 4)
    pattern = TwoHopPattern(graph)
    state = [0.62, -0.31, 0.18, -0.47, 0.29, -0.11]
    llr = [2.4, -1.1, 0.7, -2.0]
    coefficients = MetricCoefficients(
        0.0,
        [-0.098969711158939794,
         -0.19129556359240465,
         -0.70584476358886339,
         -0.0036899816577923542],
    )
    state_before = copy(state)
    llr_before = copy(llr)

    objective = JC.evaluate_objective(graph, llr, state)
    # These binary64 words were independently transcribed from the registered
    # J_C source with SHA-256 000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c.
    @test reinterpret(UInt64, objective.value) == 0x3ff20c267fe38771
    @test reinterpret(UInt64, objective.mean_state) == UInt64[
        0x3fb3333333333338, 0xbf847ae147ae1480,
        0x3fc70a3d70a3d70a, 0xbfbc28f5c28f5c29,
    ]
    @test reinterpret(UInt64, objective.scalar_partial_derivatives) == UInt64[
        0xbfd41c1a73f49970, 0x3fc12f03f2d3c793,
        0xbfbf20189edd5052, 0x3fd1705fa1fc13b7,
    ]
    @test reinterpret(UInt64, objective.partial_derivatives) == UInt64[
        0xbfc41c1a73f49970, 0x3fb12f03f2d3c793,
        0xbfbf20189edd5052, 0xbfc41c1a73f49970,
        0x3fb12f03f2d3c793, 0x3fd1705fa1fc13b7,
    ]
    value_function = candidate_state ->
        JC.evaluate_objective(graph, llr, candidate_state).value
    for edge in eachindex(state)
        numerical = five_point_testlocal_derivative(
            value_function, state, edge)
        @test numerical ≈ objective.partial_derivatives[edge] atol=2.0e-10 rtol=2.0e-9
    end

    metric = JC.fixed_metric_diagonal(graph)
    @test metric == [1.2, 1.2, 1.4, 1.2, 1.2, 1.4]
    partial_derivatives_before = copy(objective.partial_derivatives)
    metric_before = copy(metric)
    candidate = generic_metric_action(
        graph, pattern, state, llr, objective.partial_derivatives,
        metric, coefficients)
    @test candidate.descent_inner_product < 0.0
    @test dot(objective.partial_derivatives, candidate.direction) ==
          candidate.descent_inner_product
    @test candidate.condition.guaranteed_lambda_min_A > 0.0

    zero = MetricCoefficients(zeros(FAMILY_COUNT + 1))
    lower_endpoint = generic_metric_action(
        graph, pattern, state, llr, objective.partial_derivatives,
        metric, zero)
    declared_lower_endpoint = baseline_direction(
        objective.partial_derivatives, metric)
    @test reinterpret(UInt64, lower_endpoint.direction) ==
          reinterpret(UInt64, declared_lower_endpoint)
    @test reinterpret(UInt64, lower_endpoint.baseline) ==
          reinterpret(UInt64, declared_lower_endpoint)

    @test reinterpret(UInt64, state) == reinterpret(UInt64, state_before)
    @test reinterpret(UInt64, llr) == reinterpret(UInt64, llr_before)
    @test reinterpret(UInt64, objective.partial_derivatives) ==
          reinterpret(UInt64, partial_derivatives_before)
    @test reinterpret(UInt64, metric) == reinterpret(UInt64, metric_before)
    @test objective.partial_derivatives !== candidate.direction
end
