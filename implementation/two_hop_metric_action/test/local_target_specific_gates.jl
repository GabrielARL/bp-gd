#!/usr/bin/env julia

using Test

include(joinpath(@__DIR__, "..", "target_specific_gates.jl"))
const Gates = RQ2StageBTargetSpecificGates

gate_hex64(value::Integer) = lpad(string(value; base=16), 64, '0')

function origin_record(index::Int)
    Dict{String,Any}(
        "record_id" => "synthetic-origin-$(index)",
        "candidate_guaranteed_lambda_min_A" => 0.5,
        "candidate_guaranteed_lambda_max_A" => 1.0,
        "candidate_relative_condition_bound" => 2.0,
        "candidate_metric_condition" => 3.0,
        "candidate_full_euclidean_condition_bound" => 6.0,
        "candidate_relative_condition_passed" => true,
        "candidate_full_condition_passed" => true,
        "candidate_condition_passed" => true,
        "lower_endpoint_direction_sha256" => gate_hex64(3000 + index),
        "lower_endpoint_returned_baseline_sha256" => gate_hex64(3000 + index),
        "lower_endpoint_declared_baseline_sha256" => gate_hex64(3000 + index),
        "exact_zero_lower_endpoint_bit_exact" => true,
        "finite_values_passed" => true,
        "candidate_strict_descent_passed" => true,
        "local_candidate_gate_passed" => true,
    )
end

fixture() = [origin_record(index) for index in 1:3]

function gate_captured_error(operation)
    try
        operation()
    catch error
        return error
    end
    error("expected operation to fail")
end

function gate_require_error(operation, code::Symbol)
    error = gate_captured_error(operation)
    @test error isa Gates.TargetSpecificGateError
    @test error.code == code
    error
end

function fail_full_condition!(record)
    record["candidate_metric_condition"] = 6000.0
    record["candidate_full_euclidean_condition_bound"] = 12000.0
    record["candidate_full_condition_passed"] = false
    record["candidate_condition_passed"] = false
    record["local_candidate_gate_passed"] = false
    record
end

function fail_lower_identity!(record)
    record["lower_endpoint_direction_sha256"] = gate_hex64(900_001)
    record["exact_zero_lower_endpoint_bit_exact"] = false
    record
end

@testset "pure target-specific source boundary" begin
    source = read(joinpath(@__DIR__, "..", "target_specific_gates.jl"), String)
    @test occursin("module RQ2StageBTargetSpecificGates", source)
    @test occursin("evaluate_target_specific_origin", source)
    @test occursin("reduce_target_specific_level", source)
    @test !occursin("using SHA", source)
    @test !occursin("using Random", source)
    @test !occursin("using TOML", source)
    @test !occursin("using Statistics", source)
    for forbidden_call in (
            "open(", "read(", "write(", "ENV[", "run(", "pipeline(",
            "rand(", "randn(", "calculate_pass(", "exact_recurrence(",
            "line_search(", "hard_decision(", "projected_step(",
            "sort(", "sort!(", "unique(")
        @test !occursin(forbidden_call, source)
    end
    @test !occursin("median(", source)
    @test !occursin("quantile(", source)
    @test !occursin("coverage", source)
end

@testset "passing origin and level counts" begin
    records = fixture()
    records_before = deepcopy(records)
    origin = Gates.evaluate_target_specific_origin(records[1])
    @test origin.schema_version == Gates.SCHEMA_VERSION
    @test origin.record_id == "synthetic-origin-1"
    @test origin.finite_values_passed
    @test origin.relative_condition_passed
    @test origin.full_condition_passed
    @test origin.condition_passed
    @test origin.lower_endpoint_bit_identity_passed
    @test origin.local_candidate_gate_passed
    @test origin.target_specific_origin_passed

    level = Gates.reduce_target_specific_level(records)
    @test level.schema_version == Gates.SCHEMA_VERSION
    @test level.target_specific_denominator == 3
    @test level.record_ids == (
        "synthetic-origin-1", "synthetic-origin-2", "synthetic-origin-3")
    for field in (
            :finite_value_pass_count, :finite_value_denominator,
            :relative_condition_pass_count, :relative_condition_denominator,
            :full_condition_pass_count, :full_condition_denominator,
            :condition_pass_count, :condition_denominator,
            :lower_endpoint_bit_identity_pass_count,
            :lower_endpoint_bit_identity_denominator,
            :local_candidate_pass_count, :local_candidate_denominator,
            :target_specific_origin_pass_count,
            :target_specific_origin_denominator)
        @test getproperty(level, field) == 3
    end
    @test level.finite_values_gate_passed
    @test level.relative_condition_gate_passed
    @test level.full_condition_gate_passed
    @test level.condition_gate_passed
    @test level.lower_endpoint_bit_identity_gate_passed
    @test level.local_candidate_gate_passed
    @test level.target_specific_origin_gate_passed
    @test level.level_target_specific_gate_passed
    @test isequal(records, records_before)
end

@testset "one condition failure has an exact denominator" begin
    records = fixture()
    fail_full_condition!(records[1])
    origin = Gates.evaluate_target_specific_origin(records[1])
    @test origin.relative_condition_passed
    @test !origin.full_condition_passed
    @test !origin.condition_passed
    @test !origin.local_candidate_gate_passed
    @test !origin.target_specific_origin_passed

    level = Gates.reduce_target_specific_level(records)
    @test level.target_specific_denominator == 3
    @test level.relative_condition_pass_count == 3
    @test level.full_condition_pass_count == 2
    @test level.condition_pass_count == 2
    @test level.local_candidate_pass_count == 2
    @test level.target_specific_origin_pass_count == 2
    @test level.relative_condition_gate_passed
    @test !level.full_condition_gate_passed
    @test !level.condition_gate_passed
    @test !level.local_candidate_gate_passed
    @test !level.target_specific_origin_gate_passed
    @test !level.level_target_specific_gate_passed
end

@testset "one exact-zero bit-identity failure has an exact denominator" begin
    records = fixture()
    fail_lower_identity!(records[2])
    origin = Gates.evaluate_target_specific_origin(records[2])
    @test !origin.lower_endpoint_bit_identity_passed
    @test !origin.target_specific_origin_passed

    level = Gates.reduce_target_specific_level(records)
    @test level.lower_endpoint_bit_identity_pass_count == 2
    @test level.lower_endpoint_bit_identity_denominator == 3
    @test !level.lower_endpoint_bit_identity_gate_passed
    @test level.condition_gate_passed
    @test level.local_candidate_gate_passed
    @test !level.target_specific_origin_gate_passed
    @test !level.level_target_specific_gate_passed
end

@testset "opaque identifiers and exact hashes are validated locally" begin
    missing = origin_record(1)
    delete!(missing, "record_id")
    gate_require_error(:missing_field) do
        Gates.evaluate_target_specific_origin(missing)
    end

    malformed = origin_record(1)
    malformed["lower_endpoint_direction_sha256"] = "not-a-canonical-hash"
    gate_require_error(:invalid_hash) do
        Gates.evaluate_target_specific_origin(malformed)
    end

    altered = origin_record(1)
    altered["lower_endpoint_direction_sha256"] = gate_hex64(777_777)
    altered["exact_zero_lower_endpoint_bit_exact"] = false
    result = Gates.evaluate_target_specific_origin(altered)
    @test !result.lower_endpoint_bit_identity_passed

    duplicate = origin_record(1)
    level = Gates.reduce_target_specific_level([duplicate, deepcopy(duplicate)])
    @test level.record_ids == ("synthetic-origin-1", "synthetic-origin-1")
    @test level.level_target_specific_gate_passed
end

@testset "declared flags cannot disagree with diagnostics" begin
    local_gate = origin_record(1)
    local_gate["local_candidate_gate_passed"] = false
    gate_require_error(:local_gate_mismatch) do
        Gates.evaluate_target_specific_origin(local_gate)
    end

    condition = origin_record(1)
    condition["candidate_full_condition_passed"] = false
    gate_require_error(:condition_flag_mismatch) do
        Gates.evaluate_target_specific_origin(condition)
    end

    identity = origin_record(1)
    identity["exact_zero_lower_endpoint_bit_exact"] = false
    gate_require_error(:lower_endpoint_identity_flag_mismatch) do
        Gates.evaluate_target_specific_origin(identity)
    end

    finite = origin_record(1)
    finite["finite_values_passed"] = false
    gate_require_error(:finite_flag_mismatch) do
        Gates.evaluate_target_specific_origin(finite)
    end
end

@testset "nonfinite and inconsistent condition diagnostics fail closed" begin
    nonfinite = origin_record(1)
    nonfinite["candidate_relative_condition_bound"] = NaN
    gate_require_error(:nonfinite_diagnostic) do
        Gates.evaluate_target_specific_origin(nonfinite)
    end

    inconsistent = origin_record(1)
    inconsistent["candidate_full_euclidean_condition_bound"] = 6.5
    gate_require_error(:condition_diagnostic_mismatch) do
        Gates.evaluate_target_specific_origin(inconsistent)
    end

    gate_require_error(:empty_population) do
        Gates.reduce_target_specific_level(Any[])
    end
end

@testset "order is caller-owned while gate values are deterministic" begin
    records = fixture()
    forward = Gates.reduce_target_specific_level(records)
    reverse_order = Gates.reduce_target_specific_level(reverse(records))
    @test reverse(forward.record_ids) == reverse_order.record_ids
    @test forward.target_specific_denominator ==
          reverse_order.target_specific_denominator
    @test forward.target_specific_origin_pass_count ==
          reverse_order.target_specific_origin_pass_count
    @test forward.level_target_specific_gate_passed ==
          reverse_order.level_target_specific_gate_passed
end
