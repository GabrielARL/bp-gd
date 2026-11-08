#!/usr/bin/env julia

using SHA
using Test

if !isdefined(Main, :RQ2RetainedDirectionPopulationSummary)
    include(joinpath(
        @__DIR__, "..", "retained_direction_population_summary.jl"))
end

const RetainedPopulation = RQ2RetainedDirectionPopulationSummary

population_sha256(path::AbstractString) = bytes2hex(sha256(read(path)))

function population_screen()
    Dict{String,Any}(
        "direction_screen" => Dict{String,Any}(
            "median_angle_degrees_max" => 15.0,
            "p90_angle_degrees_max" => 20.0,
            "aligned_or_evaluable_coverage_min" => 0.6,
            "one_sided_zero_fraction_max" => 0.4,
            "median_improvement_over_native_J_C_degrees_min" => 20.0,
            "median_relative_direction_error_max" => 0.4,
        ),
    )
end

function population_row(; channel="synthetic_level", frame=1,
                        angle_class="defined", angle_degrees=10.0,
                        baseline_angle_class="defined",
                        baseline_angle_degrees=30.0,
                        relative_direction_error=0.2,
                        candidate_nonzero=true, strict_descent=true,
                        finite_values=true)
    (; channel, frame, angle_class, angle_degrees,
       baseline_angle_class, baseline_angle_degrees,
       relative_direction_error, candidate_nonzero,
       strict_descent, finite_values)
end

function population_fixture()
    [
        population_row(),
        population_row(; frame=2, angle_degrees=20.0,
                       baseline_angle_degrees=40.0,
                       relative_direction_error=0.4),
        population_row(; frame=2, angle_class="both_zero",
                       angle_degrees=0.0,
                       baseline_angle_class="both_zero",
                       baseline_angle_degrees=0.0,
                       relative_direction_error=0.0,
                       candidate_nonzero=false),
        population_row(; frame=3, angle_class="candidate_zero_only",
                       angle_degrees=0.0,
                       baseline_angle_degrees=50.0,
                       relative_direction_error=0.0,
                       candidate_nonzero=false),
        population_row(; frame=3, angle_class="teacher_zero_only",
                       angle_degrees=0.0,
                       baseline_angle_class="teacher_zero_only",
                       baseline_angle_degrees=0.0,
                       relative_direction_error=0.0),
    ]
end

function summarize_population(rows=population_fixture();
                              config=population_screen())
    RetainedPopulation.summarize_channel(
        "synthetic_level", rows, config)
end

@testset "retained population arithmetic and exact-zero classes" begin
    rows = population_fixture()
    rows_before = deepcopy(rows)
    summary = summarize_population(rows)

    @test propertynames(summary) == (
        :channel, :frame_count, :state_count, :defined_count,
        :both_zero_count, :candidate_zero_only_count,
        :teacher_zero_only_count, :aligned_or_evaluable_count,
        :aligned_or_evaluable_coverage, :one_sided_zero_count,
        :one_sided_zero_fraction, :candidate_median_angle_defined,
        :candidate_median_angle_degrees, :candidate_p90_angle_defined,
        :candidate_p90_angle_degrees, :baseline_median_angle_defined,
        :baseline_median_angle_degrees, :jointly_defined_angle_count,
        :median_angle_improvement_defined,
        :median_angle_improvement_degrees,
        :relative_error_evaluable_count,
        :median_relative_direction_error_defined,
        :candidate_median_relative_direction_error,
        :nonzero_candidate_direction_count, :strict_descent_count,
        :finite_state_count, :median_angle_gate_passed,
        :p90_angle_gate_passed,
        :aligned_or_evaluable_coverage_gate_passed,
        :one_sided_zero_gate_passed,
        :median_paired_improvement_gate_passed,
        :median_relative_direction_error_gate_passed,
        :strict_descent_gate_passed, :finite_values_gate_passed,
        :direction_screen_passed)
    @test summary.channel == "synthetic_level"
    @test summary.frame_count == 3
    @test summary.state_count == 5
    @test summary.defined_count == 2
    @test summary.both_zero_count == 1
    @test summary.candidate_zero_only_count == 1
    @test summary.teacher_zero_only_count == 1
    @test summary.aligned_or_evaluable_count == 3
    @test summary.aligned_or_evaluable_coverage == 0.6
    @test summary.one_sided_zero_count == 2
    @test summary.one_sided_zero_fraction == 0.4
    @test summary.candidate_median_angle_defined
    @test summary.candidate_median_angle_degrees == 15.0
    @test summary.candidate_p90_angle_defined
    @test summary.candidate_p90_angle_degrees == 20.0
    @test summary.baseline_median_angle_defined
    @test summary.baseline_median_angle_degrees == 40.0
    @test summary.jointly_defined_angle_count == 2
    @test summary.median_angle_improvement_defined
    @test summary.median_angle_improvement_degrees == 20.0
    @test summary.relative_error_evaluable_count == 3
    @test summary.median_relative_direction_error_defined
    @test summary.candidate_median_relative_direction_error == 0.4
    @test summary.nonzero_candidate_direction_count == 3
    @test summary.strict_descent_count == 3
    @test summary.finite_state_count == 5
    @test summary.median_angle_gate_passed
    @test summary.p90_angle_gate_passed
    @test summary.aligned_or_evaluable_coverage_gate_passed
    @test summary.one_sided_zero_gate_passed
    @test summary.median_paired_improvement_gate_passed
    @test summary.median_relative_direction_error_gate_passed
    @test summary.strict_descent_gate_passed
    @test summary.finite_values_gate_passed
    @test summary.direction_screen_passed
    @test isequal(rows, rows_before)
end

@testset "each population gate remains separately observable" begin
    threshold_cases = (
        ("median_angle_degrees_max", 14.9, :median_angle_gate_passed),
        ("p90_angle_degrees_max", 19.9, :p90_angle_gate_passed),
        ("aligned_or_evaluable_coverage_min", 0.61,
         :aligned_or_evaluable_coverage_gate_passed),
        ("one_sided_zero_fraction_max", 0.39,
         :one_sided_zero_gate_passed),
        ("median_improvement_over_native_J_C_degrees_min", 20.1,
         :median_paired_improvement_gate_passed),
        ("median_relative_direction_error_max", 0.39,
         :median_relative_direction_error_gate_passed),
    )
    for (key, value, field) in threshold_cases
        config = population_screen()
        config["direction_screen"][key] = value
        summary = summarize_population(; config)
        @test !getproperty(summary, field)
        @test !summary.direction_screen_passed
    end

    descent_rows = population_fixture()
    descent_rows[1] = merge(descent_rows[1], (; strict_descent=false))
    descent = summarize_population(descent_rows)
    @test descent.strict_descent_count == 2
    @test !descent.strict_descent_gate_passed
    @test !descent.direction_screen_passed

    nonfinite_rows = population_fixture()
    nonfinite_rows[1] = merge(
        nonfinite_rows[1], (; angle_degrees=NaN, finite_values=false))
    nonfinite = summarize_population(nonfinite_rows)
    @test nonfinite.finite_state_count == 4
    @test !nonfinite.finite_values_gate_passed
    @test !nonfinite.direction_screen_passed
end

@testset "undefined angle statistics fail closed" begin
    rows = [population_row(
        ; frame=index, angle_class="both_zero", angle_degrees=0.0,
        baseline_angle_class="both_zero", baseline_angle_degrees=0.0,
        relative_direction_error=0.0, candidate_nonzero=false)
        for index in 1:3]
    summary = summarize_population(rows)
    @test summary.state_count == 3
    @test summary.aligned_or_evaluable_coverage == 1.0
    @test summary.one_sided_zero_fraction == 0.0
    @test !summary.candidate_median_angle_defined
    @test !summary.candidate_p90_angle_defined
    @test !summary.baseline_median_angle_defined
    @test !summary.median_angle_improvement_defined
    @test !summary.median_relative_direction_error_defined
    @test summary.strict_descent_gate_passed
    @test !summary.finite_values_gate_passed
    @test !summary.direction_screen_passed
end

@testset "selection, order, and empty populations" begin
    rows = population_fixture()
    forward = summarize_population(rows)
    @test summarize_population(reverse(rows)) == forward
    ignored = population_row(
        ; channel="other_level", angle_degrees=NaN, finite_values=false)
    @test summarize_population([rows; ignored]) == forward
    @test_throws ErrorException RetainedPopulation.summarize_channel(
        "absent_level", rows, population_screen())
end

@testset "population seam source identity and capability boundary" begin
    base = normpath(joinpath(@__DIR__, ".."))
    summary_path = joinpath(base, "retained_direction_population_summary.jl")
    target_path = joinpath(base, "target_specific_gates.jl")
    adapter_path = joinpath(base, "origin_row_adapter.jl")
    @test population_sha256(summary_path) ==
          "80c048a4b861bf373923d454b716398830965b4bfbd85dabad68be448d14b0c4"
    @test population_sha256(target_path) ==
          "80b6dbdf3b21d08d3c3dba6c72ccf671416ee52eaad56db9f3f04615b44ee330"
    @test population_sha256(adapter_path) ==
          "ab46889d59faa04c69563d7f8d834215ea738d670026543b8afcfcdeb1bc8068"
    @test RetainedPopulation.RETAINED_CONTRACT_SHA256 ==
          "a96aa44aadf183d48b8db8aa5a9250b0f25552dcd61b37e6aaadd438f9be3f86"
    @test RetainedPopulation.RETAINED_SLICE_SHA256 ==
          "951be06490d6c215e05c0e7ac698ffa5b1cdb806c27207dfcde34d658c283b1f"
    @test RetainedPopulation.SCHEMA_VERSION ==
          "rq2-two-hop-positive-metric-001/retained-direction-population-summary-v1"

    summary_source = read(summary_path, String)
    target_source = read(target_path, String)
    adapter_source = read(adapter_path, String)
    @test occursin("using Statistics", summary_source)
    @test occursin("already-materialized", summary_source)
    @test occursin("prepare_origin_row", adapter_source)
    @test !occursin("using Random", summary_source)
    @test !occursin("using SHA", summary_source)
    combined = lowercase(summary_source * target_source * adapter_source)
    for forbidden_call in (
            "include(", "open(", "read(", "write(", "run(",
            "pipeline(", "rand(", "randn(", "exact_recurrence(",
            "sum_product(", "projected_step(", "line_search(",
            "hard_decision(", "readout(", "decoder_update(")
        @test !occursin(forbidden_call, combined)
    end
    @test !occursin("native_compound_objective_gradient", combined)
    @test !occursin("frame_provider", combined)
    @test !occursin("recovery_score", combined)
end
