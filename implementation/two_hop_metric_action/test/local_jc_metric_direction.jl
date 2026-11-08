#!/usr/bin/env julia

using LinearAlgebra
using SHA
using Test

if !isdefined(Main, :RQ2CompoundObjectiveJC)
    include(joinpath(@__DIR__, "..", "compound_objective_jc.jl"))
end
if !isdefined(Main, :RQ2JCMetricDirection)
    include(joinpath(@__DIR__, "..", "jc_metric_direction.jl"))
end

const JCObjective = RQ2CompoundObjectiveJC
const JCDirection = RQ2JCMetricDirection

function jc_composition_case()
    graph = Metric.EdgeGraph([[1, 2, 3], [1, 2, 4]], 4)
    pattern = Metric.TwoHopPattern(graph)
    state = [0.62, -0.31, 0.18, -0.47, 0.29, -0.11]
    llr = [2.4, -1.1, 0.7, -2.0]
    coefficients = Metric.MetricCoefficients(
        0.0,
        [-0.098969711158939794,
         -0.19129556359240465,
         -0.70584476358886339,
         -0.0036899816577923542],
    )
    (; graph, pattern, state, llr, coefficients)
end

function compose(case; graph=case.graph, pattern=case.pattern,
                 state=case.state, llr=case.llr,
                 coefficients=case.coefficients,
                 metric_source=Metric,
                 objective_source=JCObjective)
    JCDirection.evaluate_jc_metric_direction(
        metric_source, objective_source, graph, pattern, state, llr,
        coefficients)
end

function jc_captured_error(operation)
    try
        operation()
    catch error
        return error
    end
    error("expected operation to fail")
end

@testset "production J_C source identity and finite differences" begin
    case = jc_composition_case()
    state_before = copy(case.state)
    llr_before = copy(case.llr)
    objective = JCObjective.evaluate_objective(
        case.graph, case.llr, case.state)

    @test objective.schema_version ==
          "rq2-two-hop-positive-metric-001/compound-objective-jc-v1"
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
    @test objective.terms.channel +
          (objective.terms.parity + objective.terms.binary) == objective.value
    @test objective.clipped_llr == case.llr

    value_function = candidate_state ->
        JCObjective.evaluate_objective(
            case.graph, case.llr, candidate_state).value
    for edge in eachindex(case.state)
        numerical = five_point_testlocal_derivative(
            value_function, case.state, edge)
        @test numerical ≈ objective.partial_derivatives[edge] atol=2.0e-10 rtol=2.0e-9
    end

    metric = JCObjective.fixed_metric_diagonal(case.graph)
    @test metric == [1.2, 1.2, 1.4, 1.2, 1.2, 1.4]
    @test all(value -> isfinite(value) && value > 0.0, metric)
    @test reinterpret(UInt64, case.state) == reinterpret(UInt64, state_before)
    @test reinterpret(UInt64, case.llr) == reinterpret(UInt64, llr_before)

    raw_llr = [-27.0, 23.0, 1.2, -0.45]
    clipped_llr = clamp.(raw_llr, -20.0, 20.0)
    raw = JCObjective.evaluate_objective(case.graph, raw_llr, case.state)
    clipped = JCObjective.evaluate_objective(
        case.graph, clipped_llr, case.state)
    @test raw.clipped_llr == clipped_llr
    @test reinterpret(UInt64, raw.value) == reinterpret(UInt64, clipped.value)
    @test reinterpret(UInt64, raw.partial_derivatives) ==
          reinterpret(UInt64, clipped.partial_derivatives)
end

@testset "complete reference-free J_C-to-direction composition" begin
    case = jc_composition_case()
    state_before = copy(case.state)
    llr_before = copy(case.llr)
    coefficients_before = case.coefficients
    result = compose(case)
    objective = JCObjective.evaluate_objective(
        case.graph, case.llr, case.state)
    metric = JCObjective.fixed_metric_diagonal(case.graph)
    direct = Metric.generic_metric_action(
        case.graph, case.pattern, case.state, objective.clipped_llr,
        objective.partial_derivatives, metric, case.coefficients)
    zero = Metric.MetricCoefficients(zeros(Metric.FAMILY_COUNT + 1))
    lower = Metric.generic_metric_action(
        case.graph, case.pattern, case.state, objective.clipped_llr,
        objective.partial_derivatives, metric, zero)
    declared = Metric.baseline_direction(
        objective.partial_derivatives, metric)

    @test result.schema_version ==
          "rq2-two-hop-positive-metric-001/jc-metric-direction-v1"
    @test result.objective_schema_version == objective.schema_version
    @test reinterpret(UInt64, result.objective_value) ==
          reinterpret(UInt64, objective.value)
    @test result.objective_terms == objective.terms
    @test reinterpret(UInt64, result.mean_state) ==
          reinterpret(UInt64, objective.mean_state)
    @test reinterpret(UInt64, result.clipped_llr) ==
          reinterpret(UInt64, objective.clipped_llr)
    @test reinterpret(UInt64, result.partial_derivatives) ==
          reinterpret(UInt64, objective.partial_derivatives)
    @test reinterpret(UInt64, result.metric_diagonal) ==
          reinterpret(UInt64, metric)
    @test reinterpret(UInt64, result.candidate_direction) ==
          reinterpret(UInt64, direct.direction)
    @test reinterpret(UInt64, result.lower_endpoint_direction) ==
          reinterpret(UInt64, lower.direction)
    @test reinterpret(UInt64, result.lower_endpoint_direction) ==
          reinterpret(UInt64, declared)
    @test result.exact_zero_lower_endpoint_bit_exact
    @test result.candidate_condition == direct.condition
    @test result.candidate_family_normalizations ==
          direct.family_normalizations
    @test result.candidate_family_row_sum_bounds ==
          direct.family_row_sum_bounds
    @test reinterpret(UInt64, result.descent_inner_product) ==
          reinterpret(UInt64, direct.descent_inner_product)
    @test result.strict_descent_applicable
    @test result.strict_descent_passed
    @test result.relative_condition_passed ==
          (direct.condition.relative_condition_bound <= 1.0e4)
    @test result.full_condition_passed ==
          (direct.condition.full_euclidean_condition_bound <= 1.0e4)
    @test result.local_candidate_gate_passed ==
          (result.strict_descent_passed &&
           result.relative_condition_passed &&
           result.full_condition_passed)
    for forbidden_output in (
            :reference_direction, :next_state, :projected_state,
            :step_length, :readout, :hard_decision, :syndrome,
            :recovery, :ber)
        @test forbidden_output ∉ propertynames(result)
    end
    @test reinterpret(UInt64, case.state) == reinterpret(UInt64, state_before)
    @test reinterpret(UInt64, case.llr) == reinterpret(UInt64, llr_before)
    @test case.coefficients === coefficients_before
end

@testset "zero direction has no applicable descent test" begin
    case = jc_composition_case()
    zero_state = zeros(length(case.state))
    zero_llr = zeros(length(case.llr))
    result = compose(case; state=zero_state, llr=zero_llr)
    @test all(iszero, result.partial_derivatives)
    @test all(iszero, result.candidate_direction)
    @test reinterpret(UInt64, result.descent_inner_product) ==
          reinterpret(UInt64, 0.0)
    @test !result.strict_descent_applicable
    @test result.strict_descent_passed
    @test result.local_candidate_gate_passed ==
          (result.relative_condition_passed && result.full_condition_passed)
end

@testset "production composition capability boundary" begin
    objective_path = joinpath(
        @__DIR__, "..", "compound_objective_jc.jl")
    direction_path = joinpath(
        @__DIR__, "..", "jc_metric_direction.jl")
    @test isfile(objective_path)
    @test isfile(direction_path)
    objective_source = read(objective_path, String)
    direction_source = read(direction_path, String)
    @test occursin("evaluate_objective", objective_source)
    @test occursin("partial_derivatives", objective_source)
    @test occursin("evaluate_jc_metric_direction", direction_source)
    @test occursin("caller_coefficients", direction_source)
    @test !occursin("teacher", lowercase(direction_source))
    @test !occursin("exact_recurrence", lowercase(direction_source))
    @test !occursin("sum_product", lowercase(direction_source))
    for forbidden_call in (
            "include(", "open(", "read(", "write(", "rand(",
            "randn(", "projected_step(", "line_search(",
            "hard_decision(", "readout(", "decoder_update(")
        @test !occursin(forbidden_call, objective_source)
        @test !occursin(forbidden_call, direction_source)
    end
end

@testset "production composition fails closed" begin
    case = jc_composition_case()
    for (code, operation) in (
            (:objective_evaluation_failure,
             () -> compose(case; state=case.state[1:end-1])),
            (:objective_evaluation_failure,
             () -> compose(case; llr=[NaN; case.llr[2:end]])),
            (:identity_only_coefficients,
             () -> compose(case; coefficients=
                 Metric.MetricCoefficients(zeros(5)))),
            (:invalid_coefficients,
             () -> compose(case; coefficients=zeros(5))),
            (:invalid_source,
             () -> compose(case; objective_source=Main)),
        )
        error = jc_captured_error(operation)
        @test error isa JCDirection.DirectionCompositionError
        @test error.code == code
    end

    other_graph = Metric.EdgeGraph([[1, 2], [2, 3], [1, 3, 4]], 4)
    other_pattern = Metric.TwoHopPattern(other_graph)
    error = jc_captured_error(
        () -> compose(case; pattern=other_pattern))
    @test error isa JCDirection.DirectionCompositionError
    @test error.code == :candidate_action_failure

    objective_error = jc_captured_error(
        () -> JCObjective.evaluate_objective(
            case.graph, case.llr, [1.01; case.state[2:end]]))
    @test objective_error isa JCObjective.ObjectiveEvaluationError
    @test objective_error.code == :state_out_of_range
end
