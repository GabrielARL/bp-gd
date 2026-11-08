#!/usr/bin/env julia

using SHA
using Test

const LOCAL_METRIC_SOURCE =
    normpath(joinpath(@__DIR__, "..", "two_hop_positive_metric.jl"))
const REGISTERED_METRIC_SOURCE_SHA256 =
    "8f5edffbd6a1e817422da857fc4c78d095e682b42c6cebfdc429437de7e71efb"
const OBSERVED_METRIC_SOURCE_SHA256 =
    bytes2hex(sha256(read(LOCAL_METRIC_SOURCE)))
OBSERVED_METRIC_SOURCE_SHA256 == REGISTERED_METRIC_SOURCE_SHA256 || error(
    "local metric source differs from the frozen V5 source")

if !isdefined(Main, :RQ2TwoHopPositiveMetric001)
    include(LOCAL_METRIC_SOURCE)
end
include(joinpath(@__DIR__, "..", "stage_b_direction_kernel.jl"))

const Metric = RQ2TwoHopPositiveMetric001
const Kernel = RQ2StageBDirectionKernel

function synthetic_case()
    graph = Metric.EdgeGraph([[1, 2, 3], [1, 2, 4]], 4)
    pattern = Metric.TwoHopPattern(graph)
    edges = Metric.edge_count(graph)
    state = [0.62, -0.31, 0.18, -0.47, 0.29, -0.11]
    llr = [2.4, -1.1, 0.7, -2.0]
    derivatives = [0.0, -0.0, 0.35, -0.44, 0.21, 0.56]
    metric_diagonal = [0.8, 1.1, 0.9, 1.3, 0.7, 1.4]
    coefficients = Metric.MetricCoefficients(
        0.2, [0.04, -0.03, 0.02, -0.01])
    (; graph, pattern, edges, state, llr, derivatives, metric_diagonal,
       coefficients)
end

function evaluate(case; state=case.state, llr=case.llr,
                  derivatives=case.derivatives,
                  metric_diagonal=case.metric_diagonal,
                  coefficients=case.coefficients,
                  teacher=ones(case.edges), pattern=case.pattern)
    Kernel.evaluate_direction_origin(
        Metric, case.graph, pattern, state, llr, derivatives,
        metric_diagonal, coefficients, teacher)
end

function captured_error(function_to_run)
    try
        function_to_run()
    catch error
        return error
    end
    error("expected the test operation to fail")
end

@testset "pinned source and diagnostic-only kernel" begin
    @test isfile(LOCAL_METRIC_SOURCE)
    @test OBSERVED_METRIC_SOURCE_SHA256 == REGISTERED_METRIC_SOURCE_SHA256
    source = read(joinpath(@__DIR__, "..", "stage_b_direction_kernel.jl"), String)
    @test occursin(":generic_metric_action", source)
    for forbidden in (
        "calculate_pass(", "generate_awgn", "exact_recurrence",
        "sum_product", "teacher_recurrence", "decoder_update",
        "hard_decision", "readout", "line_search", "projected_step")
        @test !occursin(forbidden, source)
    end
end

@testset "defined angles, relative error, descent, and conditions" begin
    case = synthetic_case()
    first = evaluate(case)
    result = evaluate(case; teacher=first.candidate_direction)
    @test result.schema_version ==
          "rq2-two-hop-positive-metric-001/stage-b-direction-origin-v2"
    @test result.candidate.angle_class == :defined
    @test result.candidate.angle_degrees <= 1.0e-6
    @test result.candidate.relative_direction_error == 0.0
    @test result.candidate.strict_descent_applicable
    @test result.candidate.strict_descent_passed
    @test result.candidate.descent_inner_product < 0.0
    @test result.candidate_condition.relative_condition_passed
    @test result.candidate_condition.full_condition_passed
    @test result.candidate_condition.condition_passed
    @test result.lower_endpoint_condition.condition_passed
    @test result.exact_zero_lower_endpoint_bit_exact
    @test result.local_candidate_gate_passed
    @test result.paired_angle_improvement_degrees !== nothing
    @test length(result.candidate_family_normalizations) == 4
    @test all(isfinite, result.candidate_family_normalizations)
    @test all(value -> value <= 1.0 + 16eps(Float64),
              result.candidate_family_row_sum_bounds)

    lower = result.lower_endpoint_direction
    teacher = result.teacher_direction
    metric = case.metric_diagonal
    numerator = sum(metric .* lower .* teacher)
    denominator = sqrt(sum(metric .* lower .* lower)) *
                  sqrt(sum(metric .* teacher .* teacher))
    expected_angle = acosd(clamp(numerator / denominator, -1.0, 1.0))
    @test result.lower_endpoint.angle_degrees ≈ expected_angle atol=2e-14 rtol=0
    expected_relative = sqrt(
        sum(metric .* (lower .- teacher).^2) /
        sum(metric .* teacher .* teacher))
    @test result.lower_endpoint.relative_direction_error ≈
          expected_relative atol=2e-14 rtol=2e-14
end

@testset "all four exact-zero classes and statistic populations" begin
    case = synthetic_case()
    zero_derivatives = zeros(case.edges)
    both_zero = evaluate(
        case; derivatives=zero_derivatives, teacher=zeros(case.edges))
    @test both_zero.candidate.angle_class == :both_zero
    @test both_zero.lower_endpoint.angle_class == :both_zero
    @test both_zero.candidate.angle_degrees === nothing
    @test both_zero.candidate.relative_direction_error === nothing
    @test !both_zero.candidate.strict_descent_applicable
    @test both_zero.candidate.strict_descent_passed

    candidate_zero = evaluate(
        case; derivatives=zero_derivatives, teacher=ones(case.edges))
    @test candidate_zero.candidate.angle_class == :candidate_zero_only
    @test candidate_zero.lower_endpoint.angle_class == :candidate_zero_only
    @test candidate_zero.candidate.angle_degrees === nothing
    @test candidate_zero.candidate.relative_direction_error == 1.0
    @test !candidate_zero.candidate.strict_descent_applicable

    teacher_zero = evaluate(case; teacher=zeros(case.edges))
    @test teacher_zero.candidate.angle_class == :teacher_zero_only
    @test teacher_zero.lower_endpoint.angle_class == :teacher_zero_only
    @test teacher_zero.candidate.angle_degrees === nothing
    @test teacher_zero.candidate.relative_direction_error === nothing
    @test teacher_zero.candidate.strict_descent_applicable
    @test teacher_zero.candidate.strict_descent_passed

    defined = evaluate(case; teacher=ones(case.edges))
    @test defined.candidate.angle_class == :defined
    @test defined.lower_endpoint.angle_class == :defined
    @test isfinite(defined.candidate.angle_degrees)
    @test isfinite(defined.candidate.relative_direction_error)
end

@testset "exact-zero generic action preserves every baseline bit" begin
    case = synthetic_case()
    signed_derivatives = [0.0, -0.0, 0.0, -0.0, 0.25, -0.4]
    result = evaluate(
        case; derivatives=signed_derivatives, teacher=ones(case.edges))
    reference = Metric.baseline_direction(
        signed_derivatives, case.metric_diagonal)
    @test reinterpret(UInt64, result.lower_endpoint_direction) ==
          reinterpret(UInt64, reference)
    @test reinterpret(UInt64, result.lower_endpoint_returned_baseline) ==
          reinterpret(UInt64, reference)
    @test reinterpret(UInt64, result.lower_endpoint_declared_baseline) ==
          reinterpret(UInt64, reference)
    @test result.lower_endpoint_direction !==
          result.lower_endpoint_returned_baseline
    @test result.lower_endpoint_direction !==
          result.lower_endpoint_declared_baseline
    @test result.lower_endpoint_returned_baseline !==
          result.lower_endpoint_declared_baseline
    @test reinterpret(UInt64, result.lower_endpoint_direction[1]) ==
          reinterpret(UInt64, -0.0)
    @test reinterpret(UInt64, result.lower_endpoint_direction[2]) ==
          reinterpret(UInt64, 0.0)
    @test result.exact_zero_lower_endpoint_bit_exact

    state_before = copy(case.state)
    llr_before = copy(case.llr)
    derivatives_before = copy(case.derivatives)
    metric_before = copy(case.metric_diagonal)
    evaluate(case)
    @test case.state == state_before
    @test case.llr == llr_before
    @test case.derivatives == derivatives_before
    @test case.metric_diagonal == metric_before
end

@testset "full condition gate is retained per origin" begin
    case = synthetic_case()
    weak_metric = copy(case.metric_diagonal)
    weak_metric[1] = 1.0e-6
    result = evaluate(case; metric_diagonal=weak_metric)
    @test result.candidate_condition.relative_condition_passed
    @test !result.candidate_condition.full_condition_passed
    @test !result.candidate_condition.condition_passed
    @test result.candidate_condition.full_euclidean_condition_bound > 1.0e4
    @test result.candidate.strict_descent_passed
    @test !result.local_candidate_gate_passed
end

@testset "dimension, finite-value, pattern, and coefficient failures" begin
    case = synthetic_case()
    for (code, operation) in (
        (:dimension_mismatch,
         () -> evaluate(case; state=case.state[1:end-1])),
        (:dimension_mismatch,
         () -> evaluate(case; llr=case.llr[1:end-1])),
        (:dimension_mismatch,
         () -> evaluate(case; derivatives=case.derivatives[1:end-1])),
        (:dimension_mismatch,
         () -> evaluate(case;
                        metric_diagonal=case.metric_diagonal[1:end-1])),
        (:dimension_mismatch,
         () -> evaluate(case; teacher=ones(case.edges - 1))),
        (:nonfinite_input,
         () -> evaluate(case; state=[NaN; case.state[2:end]])),
        (:nonfinite_input,
         () -> evaluate(case; llr=[Inf; case.llr[2:end]])),
        (:nonfinite_input,
         () -> evaluate(case;
                        derivatives=[NaN; case.derivatives[2:end]])),
        (:nonfinite_input,
         () -> evaluate(case;
                        metric_diagonal=[Inf; case.metric_diagonal[2:end]])),
        (:nonfinite_input,
         () -> evaluate(case; teacher=[NaN; ones(case.edges - 1)])),
        (:state_out_of_range,
         () -> evaluate(case; state=[1.01; case.state[2:end]])),
        (:invalid_metric,
         () -> evaluate(case;
                        metric_diagonal=[0.0; case.metric_diagonal[2:end]])),
        (:identity_only_coefficients,
         () -> evaluate(case;
                        coefficients=Metric.MetricCoefficients(zeros(5)))),
    )
        error = captured_error(operation)
        @test error isa Kernel.DirectionKernelError
        @test error.code == code
    end

    other_graph = Metric.EdgeGraph([[1, 2], [2, 3], [1, 3, 4]], 4)
    other_pattern = Metric.TwoHopPattern(other_graph)
    pattern_error = captured_error(
        () -> evaluate(case; pattern=other_pattern))
    @test pattern_error isa Kernel.DirectionKernelError
    @test pattern_error.code == :metric_action_failure

    coefficient_error = captured_error(() ->
        Kernel.evaluate_direction_origin(
            Metric, case.graph, case.pattern, case.state, case.llr,
            case.derivatives, case.metric_diagonal, zeros(5),
            ones(case.edges)))
    @test coefficient_error isa Kernel.DirectionKernelError
    @test coefficient_error.code == :invalid_coefficients
end

@testset "teacher direction is diagnostic-only" begin
    case = synthetic_case()
    first = evaluate(case)
    aligned_teacher = copy(first.candidate_direction)
    opposed_teacher = -copy(first.candidate_direction)
    aligned_before = reinterpret(UInt64, copy(aligned_teacher))
    opposed_before = reinterpret(UInt64, copy(opposed_teacher))

    aligned = evaluate(case; teacher=aligned_teacher)
    opposed = evaluate(case; teacher=opposed_teacher)

    @test reinterpret(UInt64, aligned.candidate_direction) ==
          reinterpret(UInt64, opposed.candidate_direction)
    @test reinterpret(UInt64, aligned.lower_endpoint_direction) ==
          reinterpret(UInt64, opposed.lower_endpoint_direction)
    @test aligned.candidate_condition == opposed.candidate_condition
    @test aligned.lower_endpoint_condition == opposed.lower_endpoint_condition
    @test aligned.candidate_family_normalizations ==
          opposed.candidate_family_normalizations
    @test aligned.candidate_family_row_sum_bounds ==
          opposed.candidate_family_row_sum_bounds
    @test aligned.candidate.angle_degrees <= 1.0e-6
    @test opposed.candidate.angle_degrees >= 180.0 - 1.0e-6
    @test aligned.candidate.relative_direction_error == 0.0
    @test opposed.candidate.relative_direction_error ≈ 2.0 atol=2e-15 rtol=0
    @test reinterpret(UInt64, aligned_teacher) == aligned_before
    @test reinterpret(UInt64, opposed_teacher) == opposed_before

    forbidden_outputs = (
        :state, :next_state, :projected_state, :step_length, :readout,
        :hard_decision, :syndrome, :recovery, :ber,
    )
    for name in forbidden_outputs
        @test name ∉ propertynames(aligned)
    end

    source = read(
        joinpath(@__DIR__, "..", "stage_b_direction_kernel.jl"), String)
    for forbidden in (
        "include(", "open(", "read(", "write(", "rand(",
        "calculate_pass(", "generate_awgn", "exact_recurrence",
        "sum_product", "teacher_recurrence", "decoder_update",
        "hard_decision", "readout", "line_search", "projected_step",
    )
        @test !occursin(forbidden, source)
    end
end

