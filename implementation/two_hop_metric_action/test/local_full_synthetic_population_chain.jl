#!/usr/bin/env julia

module FullSyntheticPopulationChainTests

using SHA
using Test

const SOURCE_ROOT = normpath(joinpath(@__DIR__, ".."))
for (module_name, source_name) in (
        (:RQ2TwoHopPositiveMetric001, "two_hop_positive_metric.jl"),
        (:RQ2CompoundObjectiveJC, "compound_objective_jc.jl"),
        (:RQ2JCMetricDirection, "jc_metric_direction.jl"),
        (:RQ2StageBDirectionKernel, "stage_b_direction_kernel.jl"),
        (:RQ2RetainedDirectionPopulationSummary,
         "retained_direction_population_summary.jl"),
        (:RQ2StageBTargetSpecificGates, "target_specific_gates.jl"),
        (:RQ2StageBOriginRowAdapter, "origin_row_adapter.jl"),
    )
    isdefined(Main, module_name) ||
        Base.include(Main, joinpath(SOURCE_ROOT, source_name))
end

const ChainMetric = Main.RQ2TwoHopPositiveMetric001
const ChainObjective = Main.RQ2CompoundObjectiveJC
const ChainComposition = Main.RQ2JCMetricDirection
const ChainKernel = Main.RQ2StageBDirectionKernel
const ChainPopulation = Main.RQ2RetainedDirectionPopulationSummary
const ChainGates = Main.RQ2StageBTargetSpecificGates
const ChainAdapter = Main.RQ2StageBOriginRowAdapter

chain_bits(values) = reinterpret(UInt64, Float64.(values))

function chain_vector_sha256(values)
    words = join((string(word; base=16, pad=16)
                  for word in chain_bits(values)), "\n") * "\n"
    bytes2hex(sha256(Vector{UInt8}(codeunits(words))))
end

function chain_text_sha256(value::AbstractString)
    bytes2hex(sha256(Vector{UInt8}(codeunits(value))))
end

function chain_case()
    graph = ChainMetric.EdgeGraph([[1, 2, 3], [1, 2, 4]], 4)
    pattern = ChainMetric.TwoHopPattern(graph)
    state = [0.62, -0.31, 0.18, -0.47, 0.29, -0.11]
    llr = [2.4, -1.1, 0.7, -2.0]
    coefficients = ChainMetric.MetricCoefficients(
        0.2, [0.04, -0.03, 0.02, -0.01])
    (; graph, pattern, state, llr, coefficients)
end

function chain_thresholds()
    Dict{String,Any}(
        "median_angle_degrees_max" => 60.0,
        "p90_angle_degrees_max" => 85.0,
        "aligned_or_evaluable_coverage_min" => 0.95,
        "one_sided_zero_fraction_max" => 0.05,
        "paired_median_improvement_over_lower_endpoint_degrees_min" => 15.0,
        "median_relative_direction_error_max" => 0.9,
    )
end

function chain_frozen_production_comparison_direction()
    # Frozen from the pure production composition below. It is deliberately
    # already materialized before the diagnostic call, and is synthetic only:
    # it must not be interpreted as an independent BP comparison direction.
    reinterpret(Float64, UInt64[
        0x3fc3c89377cef8fc, 0xbfb0143ac70a9b6e,
        0x3fb9f1dd911b8eed, 0x3fc3ef1ee574ee91,
        0xbfb078420f0fe252, 0xbfcd98bd5078b456,
    ])
end

function chain_frozen_prior_diagnostic_direction()
    # This preserves the exact earlier one-off diagnostic fixture. That
    # fixture supplied its derivatives and diagonal; it did not evaluate J_C.
    reinterpret(Float64, UInt64[
        0xbf7c0cfe7b947a21, 0x3f83845162575205,
        0xbfdea156c3d89ec4, 0x3fda42481ebcbdf0,
        0xbfd7c1d9adeca3f7, 0xbfdeb851eb851eba,
    ])
end

function chain_kernel_result(case, production, teacher)
    ChainKernel.evaluate_direction_origin(
        ChainMetric, case.graph, case.pattern, case.state,
        production.clipped_llr, production.partial_derivatives,
        production.metric_diagonal, case.coefficients, teacher)
end

function chain_prepare_origin(index, case, production, kernel_result,
                              teacher, thresholds)
    lower_hash = chain_vector_sha256(kernel_result.lower_endpoint_direction)
    coefficient_values = [case.coefficients.theta0;
                          collect(case.coefficients.beta)]
    ChainAdapter.prepare_origin_row(
        (;
            record_id="full-synthetic-repeat-$(index)",
            channel="full_synthetic_level",
            snr_db=2.0,
            frame=201,
            frame_rank=1,
            origin_update=index - 1,
        ),
        (; input_identity_sha256=chain_text_sha256(
            "one-repeated-full-synthetic-input")),
        (;
            state_sha256=chain_vector_sha256(case.state),
            teacher_direction_sha256=chain_vector_sha256(teacher),
            candidate_direction_sha256=
                chain_vector_sha256(kernel_result.candidate_direction),
            lower_endpoint_direction_sha256=lower_hash,
            lower_endpoint_returned_baseline_sha256=
                chain_vector_sha256(
                    kernel_result.lower_endpoint_returned_baseline),
            lower_endpoint_declared_baseline_sha256=
                chain_vector_sha256(
                    kernel_result.lower_endpoint_declared_baseline),
            metric_sha256=chain_vector_sha256(production.metric_diagonal),
            coefficient_sha256=chain_vector_sha256(coefficient_values),
        ),
        kernel_result, thresholds)
end

@testset "earlier supplied-arithmetic diagnostic remains distinct" begin
    case = chain_case()
    supplied_derivatives = [0.0, -0.0, 0.35, -0.44, 0.21, 0.56]
    supplied_diagonal = [0.8, 1.1, 0.9, 1.3, 0.7, 1.4]
    teacher = chain_frozen_prior_diagnostic_direction()
    result = ChainKernel.evaluate_direction_origin(
        ChainMetric, case.graph, case.pattern, case.state, case.llr,
        supplied_derivatives, supplied_diagonal, case.coefficients, teacher)

    @test chain_bits(result.candidate_direction) == chain_bits(teacher)
    @test result.candidate.angle_class == :defined
    @test result.candidate.relative_direction_error == 0.0
    @test result.candidate.angle_degrees ≈
          8.537736462515939e-7 atol=1.0e-18 rtol=0.0
    @test result.paired_angle_improvement_degrees ≈
          0.9935439809818444 atol=1.0e-15 rtol=0.0
    @test result.paired_angle_improvement_degrees < 15.0
    @test result.local_candidate_gate_passed
end

@testset "unchanged J_C through the fail-closed population gate" begin
    case = chain_case()
    state_before = chain_bits(case.state)
    llr_before = chain_bits(case.llr)
    coefficient_before = (case.coefficients.theta0, case.coefficients.beta)
    teacher = chain_frozen_production_comparison_direction()
    teacher_before = chain_bits(teacher)
    thresholds = chain_thresholds()
    thresholds_before = deepcopy(thresholds)

    production = ChainComposition.evaluate_jc_metric_direction(
        ChainMetric, ChainObjective, case.graph, case.pattern,
        case.state, case.llr, case.coefficients)
    diagnostic = chain_kernel_result(case, production, teacher)

    @test chain_bits(production.candidate_direction) == chain_bits(teacher)
    @test chain_bits(production.candidate_direction) ==
          chain_bits(diagnostic.candidate_direction)
    @test chain_bits(production.lower_endpoint_direction) ==
          chain_bits(diagnostic.lower_endpoint_direction)
    @test chain_bits(production.lower_endpoint_direction) ==
          chain_bits(diagnostic.lower_endpoint_returned_baseline)
    @test chain_bits(production.lower_endpoint_direction) ==
          chain_bits(diagnostic.lower_endpoint_declared_baseline)
    for field in propertynames(production.candidate_condition)
        @test getproperty(production.candidate_condition, field) ==
              getproperty(diagnostic.candidate_condition, field)
    end
    @test production.relative_condition_passed ==
          diagnostic.candidate_condition.relative_condition_passed
    @test production.full_condition_passed ==
          diagnostic.candidate_condition.full_condition_passed
    @test production.local_candidate_gate_passed ==
          (diagnostic.candidate.strict_descent_passed &&
           diagnostic.candidate_condition.condition_passed)
    @test production.candidate_family_normalizations ==
          diagnostic.candidate_family_normalizations
    @test production.candidate_family_row_sum_bounds ==
          diagnostic.candidate_family_row_sum_bounds
    @test production.local_candidate_gate_passed
    @test diagnostic.local_candidate_gate_passed
    @test diagnostic.candidate.angle_degrees == 0.0
    @test diagnostic.candidate.relative_direction_error == 0.0
    @test diagnostic.paired_angle_improvement_degrees ≈
          0.6852959854888271 atol=1.0e-15 rtol=0.0

    rows = [chain_prepare_origin(
                index, case, production, diagnostic, teacher, thresholds)
            for index in 1:3]
    level = ChainAdapter.reduce_prepared_level(
        "full_synthetic_level", rows;
        summarize_channel=ChainPopulation.summarize_channel,
        reduce_target_specific_level=
            ChainGates.reduce_target_specific_level)

    @test level.pairing_keys_unique
    @test level.pairing_key_count == 3
    @test level.record_ids_unique
    @test level.record_id_count == 3
    @test level.generic_denominator == 3
    @test level.target_specific_denominator == 3
    @test (level.generic_summary.state_count,
           level.generic_summary.frame_count) == (3, 1)
    @test level.target_specific_summary.target_specific_denominator == 3
    @test level.target_specific_summary.target_specific_origin_pass_count == 3
    @test level.target_specific_level_passed
    @test !level.generic_summary.median_paired_improvement_gate_passed
    @test level.generic_summary.median_angle_gate_passed
    @test level.generic_summary.p90_angle_gate_passed
    @test level.generic_summary.aligned_or_evaluable_coverage_gate_passed
    @test level.generic_summary.one_sided_zero_gate_passed
    @test level.generic_summary.median_relative_direction_error_gate_passed
    @test level.generic_summary.strict_descent_gate_passed
    @test level.generic_summary.finite_values_gate_passed
    @test level.generic_summary.median_angle_improvement_degrees ≈
          0.6852959854888271 atol=1.0e-15 rtol=0.0
    @test level.generic_summary.median_angle_improvement_degrees <
          thresholds[
              "paired_median_improvement_over_lower_endpoint_degrees_min"]
    @test !level.generic_direction_screen_passed
    @test !level.level_combined_gate_passed
    @test level.threshold_projection.
          paired_median_improvement_over_lower_endpoint_degrees_min == 15.0
    @test thresholds == thresholds_before

    for forbidden in (
            :teacher_direction, :reference_direction, :next_state,
            :projected_state, :step_length, :readout, :hard_decision,
            :syndrome, :recovery, :ber, :fer)
        @test forbidden ∉ propertynames(production)
    end
    for forbidden in (
            :next_state, :projected_state, :step_length, :readout,
            :hard_decision, :syndrome, :recovery, :ber, :fer)
        @test forbidden ∉ propertynames(diagnostic)
    end

    production_source = lowercase(read(
        joinpath(SOURCE_ROOT, "jc_metric_direction.jl"), String))
    @test !occursin("teacher_direction", production_source)
    for forbidden_call in (
            "exact_recurrence(", "sum_product(", "decoder_update(",
            "projected_step(", "line_search(", "hard_decision(",
            "readout(", "recovery_score(")
        @test !occursin(forbidden_call, production_source)
    end

    @test chain_bits(case.state) == state_before
    @test chain_bits(case.llr) == llr_before
    @test chain_bits(teacher) == teacher_before
    @test (case.coefficients.theta0, case.coefficients.beta) ==
          coefficient_before
end

end # module
