#!/usr/bin/env julia

using Test

include(joinpath(@__DIR__, "..", "origin_row_adapter.jl"))
if !isdefined(Main, :RQ2StageBTargetSpecificGates)
    include(joinpath(@__DIR__, "..", "target_specific_gates.jl"))
end
if !isdefined(Main, :RQ2RetainedDirectionPopulationSummary)
    include(joinpath(
        @__DIR__, "..", "retained_direction_population_summary.jl"))
end

const Adapter = RQ2StageBOriginRowAdapter
const AdapterGates = RQ2StageBTargetSpecificGates
const PopulationSummary = RQ2RetainedDirectionPopulationSummary

adapter_hex64(value::Integer) = lpad(string(value; base=16), 64, '0')

function target_thresholds(; median_max=60.0)
    Dict{String,Any}(
        "median_angle_degrees_max" => median_max,
        "p90_angle_degrees_max" => 85.0,
        "aligned_or_evaluable_coverage_min" => 0.95,
        "one_sided_zero_fraction_max" => 0.05,
        "paired_median_improvement_over_lower_endpoint_degrees_min" => 15.0,
        "median_relative_direction_error_max" => 0.9,
    )
end

function kernel_result(index::Int; target_gate=true)
    angle = 10.0 + index
    relative = target_gate ? 2.0 : 20000.0
    metric = target_gate ? 3.0 : 1.0
    full = relative * metric
    (;
        schema_version=
            "rq2-two-hop-positive-metric-001/stage-b-direction-origin-v2",
        candidate=(;
            angle_class=:defined,
            angle_degrees=angle,
            relative_direction_error=0.2,
            strict_descent_applicable=true,
            strict_descent_passed=true,
        ),
        lower_endpoint=(;
            angle_class=:defined,
            angle_degrees=angle + 20.0,
            relative_direction_error=0.6,
            strict_descent_applicable=true,
            strict_descent_passed=true,
        ),
        candidate_condition=(;
            guaranteed_lambda_min_A=0.5,
            guaranteed_lambda_max_A=0.5 * relative,
            relative_condition_bound=relative,
            metric_condition=metric,
            full_euclidean_condition_bound=full,
            relative_condition_passed=target_gate,
            full_condition_passed=target_gate,
            condition_passed=target_gate,
        ),
        exact_zero_lower_endpoint_bit_exact=true,
        local_candidate_gate_passed=target_gate,
    )
end

function prepared_origin(index::Int;
                         thresholds=target_thresholds(), target_gate=true,
                         record_id="synthetic-origin-$(index)")
    lower_hash = adapter_hex64(4000 + index)
    Adapter.prepare_origin_row(
        (;
            record_id,
            channel="synthetic_level",
            snr_db=2.0,
            frame=100 + index,
            frame_rank=index,
            origin_update=index - 1,
        ),
        (; input_identity_sha256=adapter_hex64(1000 + index)),
        (;
            state_sha256=adapter_hex64(2000 + index),
            teacher_direction_sha256=adapter_hex64(3000 + index),
            candidate_direction_sha256=adapter_hex64(3500 + index),
            lower_endpoint_direction_sha256=lower_hash,
            lower_endpoint_returned_baseline_sha256=lower_hash,
            lower_endpoint_declared_baseline_sha256=lower_hash,
            metric_sha256=adapter_hex64(5000),
            coefficient_sha256=adapter_hex64(6000),
        ),
        kernel_result(index; target_gate), thresholds)
end

function prepare_kernel_for_adapter_test(result)
    Adapter.prepare_origin_row(
        (; record_id="validation-origin", channel="synthetic_level",
           snr_db=2.0, frame=1, frame_rank=1, origin_update=0),
        (; input_identity_sha256=adapter_hex64(101)),
        (; state_sha256=adapter_hex64(102),
           teacher_direction_sha256=adapter_hex64(103),
           candidate_direction_sha256=adapter_hex64(104),
           lower_endpoint_direction_sha256=adapter_hex64(105),
           lower_endpoint_returned_baseline_sha256=adapter_hex64(105),
           lower_endpoint_declared_baseline_sha256=adapter_hex64(105),
           metric_sha256=adapter_hex64(106),
           coefficient_sha256=adapter_hex64(107)),
        result, target_thresholds())
end

function reduce_actual(rows)
    Adapter.reduce_prepared_level(
        "synthetic_level", rows;
        summarize_channel=PopulationSummary.summarize_channel,
        reduce_target_specific_level=AdapterGates.reduce_target_specific_level)
end

function adapter_captured_error(operation)
    try
        operation()
    catch error
        return error
    end
    error("expected operation to fail")
end

function adapter_require_error(operation, code::Symbol)
    error = adapter_captured_error(operation)
    @test error isa Adapter.OriginRowAdapterError
    @test error.code == code
    error
end

@testset "pure target row and explicit interface views" begin
    prepared = prepared_origin(1)
    row = prepared.target_row
    @test row.schema_version == Adapter.SCHEMA_VERSION
    @test row.channel == "synthetic_level"
    @test row.origin_update == 0
    @test row.candidate_angle_class == "defined"
    @test row.lower_endpoint_angle_class == "defined"
    @test row.lower_endpoint_angle_degrees == 31.0
    @test row.exact_zero_lower_endpoint_bit_exact

    retained = prepared.retained_summary_view
    @test retained.angle_class == row.candidate_angle_class
    @test retained.angle_degrees == row.candidate_angle_degrees
    @test retained.baseline_angle_class == row.lower_endpoint_angle_class
    @test retained.baseline_angle_degrees ==
          row.lower_endpoint_angle_degrees
    @test retained.candidate_nonzero
    @test retained.strict_descent

    gate = prepared.target_gate_view
    @test gate.record_id == row.record_id
    @test gate.lower_endpoint_direction_sha256 ==
          row.lower_endpoint_direction_sha256
    @test gate.candidate_condition_passed

    projection = prepared.threshold_projection
    @test projection.paired_median_improvement_over_lower_endpoint_degrees_min ==
          15.0
    @test projection.retained_improvement_field ==
          :median_improvement_over_native_J_C_degrees_min
    @test projection.retained_direction_screen[
        "median_improvement_over_native_J_C_degrees_min"] == 15.0
end

@testset "actual retained and target reducers combine only after pairing proof" begin
    rows = [prepared_origin(index) for index in 1:3]
    level = reduce_actual(rows)
    @test level.pairing_keys_unique
    @test level.pairing_key_count == 3
    @test level.record_ids_unique
    @test level.record_id_count == 3
    @test level.generic_denominator == 3
    @test level.target_specific_denominator == 3
    @test level.generic_summary.direction_screen_passed
    @test level.target_specific_summary.level_target_specific_gate_passed
    @test level.generic_direction_screen_passed
    @test level.target_specific_level_passed
    @test level.level_combined_gate_passed
end

@testset "the two gate families remain separately visible" begin
    target_failure = [
        prepared_origin(1),
        prepared_origin(2; target_gate=false),
        prepared_origin(3),
    ]
    target_level = reduce_actual(target_failure)
    @test target_level.generic_direction_screen_passed
    @test !target_level.target_specific_level_passed
    @test !target_level.level_combined_gate_passed

    strict_thresholds = target_thresholds(; median_max=5.0)
    generic_failure = [prepared_origin(index; thresholds=strict_thresholds)
                       for index in 1:3]
    generic_level = reduce_actual(generic_failure)
    @test !generic_level.generic_direction_screen_passed
    @test generic_level.target_specific_level_passed
    @test !generic_level.level_combined_gate_passed
end

@testset "duplicate upstream pairing fails before either reducer" begin
    first = prepared_origin(1)
    duplicate = prepared_origin(1; record_id="different-record-label")
    summarizer_called = Ref(false)
    target_called = Ref(false)
    summarizer(args...) = (summarizer_called[] = true; error("not expected"))
    target_reducer(args...) = (target_called[] = true; error("not expected"))

    adapter_require_error(:duplicate_pairing_key) do
        Adapter.reduce_prepared_level(
            "synthetic_level", [first, duplicate];
            summarize_channel=summarizer,
            reduce_target_specific_level=target_reducer)
    end
    @test !summarizer_called[]
    @test !target_called[]
end

@testset "threshold and denominator mismatches fail closed" begin
    mixed = [
        prepared_origin(1),
        prepared_origin(2; thresholds=target_thresholds(; median_max=55.0)),
    ]
    adapter_require_error(:threshold_projection_mismatch) do
        reduce_actual(mixed)
    end

    rows = [prepared_origin(index) for index in 1:2]
    function wrong_denominator(records)
        actual = AdapterGates.reduce_target_specific_level(records)
        merge(actual, (; target_specific_denominator=length(records) + 1))
    end
    adapter_require_error(:denominator_mismatch) do
        Adapter.reduce_prepared_level(
            "synthetic_level", rows;
            summarize_channel=PopulationSummary.summarize_channel,
            reduce_target_specific_level=wrong_denominator)
    end
end

@testset "malformed injected boundaries fail closed" begin
    bad_hashes = (;
        state_sha256="not-a-hash",
        teacher_direction_sha256=adapter_hex64(1),
        candidate_direction_sha256=adapter_hex64(2),
        lower_endpoint_direction_sha256=adapter_hex64(3),
        lower_endpoint_returned_baseline_sha256=adapter_hex64(3),
        lower_endpoint_declared_baseline_sha256=adapter_hex64(3),
        metric_sha256=adapter_hex64(4),
        coefficient_sha256=adapter_hex64(5),
    )
    adapter_require_error(:invalid_hash) do
        Adapter.prepare_origin_row(
            (; record_id="bad", channel="synthetic_level", snr_db=2.0,
               frame=1, frame_rank=1, origin_update=0),
            (; input_identity_sha256=adapter_hex64(6)), bad_hashes,
            kernel_result(1), target_thresholds())
    end

    wrong_schema = merge(
        kernel_result(1), (; schema_version="synthetic-wrong-schema"))
    adapter_require_error(:kernel_schema_mismatch) do
        Adapter.prepare_origin_row(
            (; record_id="bad", channel="synthetic_level", snr_db=2.0,
               frame=1, frame_rank=1, origin_update=0),
            (; input_identity_sha256=adapter_hex64(6)),
            (; state_sha256=adapter_hex64(7),
               teacher_direction_sha256=adapter_hex64(8),
               candidate_direction_sha256=adapter_hex64(9),
               lower_endpoint_direction_sha256=adapter_hex64(10),
               lower_endpoint_returned_baseline_sha256=adapter_hex64(10),
               lower_endpoint_declared_baseline_sha256=adapter_hex64(10),
               metric_sha256=adapter_hex64(11),
               coefficient_sha256=adapter_hex64(12)),
            wrong_schema, target_thresholds())
    end

    invalid_class = merge(kernel_result(1), (;
        candidate=merge(
            kernel_result(1).candidate, (; angle_class=:unregistered))))
    adapter_require_error(:invalid_angle_class) do
        prepare_kernel_for_adapter_test(invalid_class)
    end

    nonfinite_angle = merge(kernel_result(1), (;
        candidate=merge(
            kernel_result(1).candidate, (; angle_degrees=NaN))))
    adapter_require_error(:nonfinite_number) do
        prepare_kernel_for_adapter_test(nonfinite_angle)
    end
end

