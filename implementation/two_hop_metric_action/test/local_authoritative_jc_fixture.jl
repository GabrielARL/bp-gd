#!/usr/bin/env julia

using SHA
using Test
using TOML

if !isdefined(Main, :RQ2TwoHopPositiveMetric001)
    include(joinpath(@__DIR__, "..", "two_hop_positive_metric.jl"))
end
if !isdefined(Main, :RQ2CompoundObjectiveJC)
    include(joinpath(@__DIR__, "..", "compound_objective_jc.jl"))
end

const FixtureMetric = RQ2TwoHopPositiveMetric001
const FixtureJC = RQ2CompoundObjectiveJC
const AUTHORITATIVE_JC_SHA256 =
    "000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c"
const AUTHORITATIVE_FIXED_DIAGONAL_SHA256 =
    "f2f92ca7f06264b079785534cf15c1ddf5f1e9985f384879b19244b2368204bb"

fixture_sha256(path::AbstractString) = bytes2hex(sha256(read(path)))
fixture_float(value) = reinterpret(
    Float64, parse(UInt64, String(value); base=16))
fixture_float_vector(values) = fixture_float.(values)
fixture_bits(value) = string(
    reinterpret(UInt64, Float64(value)); base=16, pad=16)
fixture_bit_vector(values) = fixture_bits.(values)
fixture_int_vectors(values) = [Int.(members) for members in values]

function fixture_input_corpus_sha256(fixture)
    graph_n = fixture["graph_n"]
    checks = fixture_int_vectors(fixture["graph_checks"])
    check_edges = fixture_int_vectors(fixture["graph_check_edges"])
    variable_edges = fixture_int_vectors(fixture["graph_variable_edges"])
    edge_variable = Int.(fixture["graph_edge_variable"])
    edge_check = Int.(fixture["graph_edge_check"])
    fields = String[
        "n=$(graph_n)",
        "checks=$(repr(checks))",
        "check_edges=$(repr(check_edges))",
        "variable_edges=$(repr(variable_edges))",
        "edge_variable=$(repr(edge_variable))",
        "edge_check=$(repr(edge_check))",
    ]
    for case in fixture["cases"]
        case_index = case["case_index"]
        state_bits = join(case["state_bits"], ',')
        llr_bits = join(case["llr_bits"], ',')
        push!(fields, "case=$(case_index)")
        push!(fields, "state=$(state_bits)")
        push!(fields, "llr=$(llr_bits)")
    end
    bytes2hex(sha256(join(fields, '\n')))
end

const AUTHORITATIVE_FIXTURE_PATH =
    joinpath(@__DIR__, "authoritative_jc_fixture.toml")
const AUTHORITATIVE_FIXTURE = TOML.parsefile(AUTHORITATIVE_FIXTURE_PATH)

@testset "durable authoritative J_C fixture provenance" begin
    fixture = AUTHORITATIVE_FIXTURE
    sources = fixture["sources"]
    generator_path = joinpath(
        @__DIR__, "generate_authoritative_jc_fixture.jl")
    production_path = joinpath(@__DIR__, "..", "compound_objective_jc.jl")

    @test fixture["schema_version"] ==
          "rq2-two-hop-positive-metric-001/authoritative-jc-fixture-v2"
    @test fixture["classification"] ==
          "deterministic synthetic arithmetic fixture; no scientific input"
    @test fixture["corpus_id"] ==
          "rq2-two-hop-positive-metric-001/portable-jc-corpus-40-v2"
    @test occursin(r"^[0-9a-f]{64}$", fixture["input_corpus_sha256"])
    @test fixture["input_corpus_sha256"] ==
          fixture_input_corpus_sha256(fixture)
    @test fixture["float_encoding"] ==
          "IEEE-754 binary64 bit pattern as 16 lowercase hexadecimal digits"
    @test fixture["case_count"] == 40
    @test length(fixture["cases"]) == fixture["case_count"]
    @test fixture["graph_n"] == 8
    @test fixture["edge_count"] == 24
    @test sort(unique(Int.(fixture["check_degrees"]))) == collect(2:6)
    @test length(unique(Int.(fixture["variable_degrees"]))) > 1
    @test fixture["objective_schema_version"] == FixtureJC.SCHEMA_VERSION
    @test fixture["objective_field_order"] == [
        "schema_version", "value", "partial_derivatives",
        "scalar_partial_derivatives", "mean_state", "terms", "clipped_llr"]
    @test fixture["objective_term_field_order"] ==
          ["channel", "parity", "binary"]
    @test fixture["parity_weight_bits"] ==
          fixture_bits(FixtureJC.PARITY_WEIGHT)
    @test fixture["binary_weight_bits"] ==
          fixture_bits(FixtureJC.BINARY_WEIGHT)
    @test fixture["llr_clip_min_bits"] == fixture_bits(-20.0)
    @test fixture["llr_clip_max_bits"] == fixture_bits(20.0)
    @test sources["generator_source_sha256"] ==
          fixture_sha256(generator_path)
    @test sources["production_jc_source_sha256"] ==
          fixture_sha256(production_path)
    @test sources["registered_jc_source_sha256"] ==
          AUTHORITATIVE_JC_SHA256
    @test sources["registered_fixed_diagonal_source_sha256"] ==
          AUTHORITATIVE_FIXED_DIAGONAL_SHA256
    @test occursin(
        "graph_factorized_energy.jl",
        sources["registered_jc_source_path"])
    @test occursin(
        "stage_c_decoder.jl",
        sources["registered_fixed_diagonal_source_path"])
end

@testset "portable 40-case authoritative J_C arithmetic" begin
    fixture = AUTHORITATIVE_FIXTURE
    checks = fixture_int_vectors(fixture["graph_checks"])
    graph = FixtureMetric.EdgeGraph(checks, Int(fixture["graph_n"]))
    @test fixture_int_vectors(fixture["graph_check_edges"]) ==
          collect.(graph.check_edges)
    @test fixture_int_vectors(fixture["graph_variable_edges"]) ==
          graph.variable_edges
    @test Int.(fixture["graph_edge_variable"]) == graph.edge_variable
    @test Int.(fixture["graph_edge_check"]) == graph.edge_check
    @test Int.(fixture["check_degrees"]) == length.(graph.checks)
    @test Int.(fixture["variable_degrees"]) == length.(graph.variable_edges)

    metric = FixtureJC.fixed_metric_diagonal(graph)
    @test fixture_bit_vector(metric) == fixture["metric_diagonal_bits"]
    @test length(metric) == fixture["edge_count"]

    clipping_witnessed = false
    positive_clip_boundary_witnessed = false
    negative_clip_boundary_witnessed = false
    positive_outside_clip_witnessed = false
    negative_outside_clip_witnessed = false
    positive_zero_llr_witnessed = false
    negative_zero_llr_witnessed = false
    positive_zero_state_witnessed = false
    negative_zero_state_witnessed = false
    positive_boundary_state_witnessed = false
    negative_boundary_state_witnessed = false
    exact_incident_mean_witnessed = false
    untied_incident_state_witnessed = false
    for (expected_index, case) in enumerate(fixture["cases"])
        state = fixture_float_vector(case["state_bits"])
        llr = fixture_float_vector(case["llr_bits"])
        state_before = copy(state)
        llr_before = copy(llr)
        objective = FixtureJC.evaluate_objective(graph, llr, state)

        @test case["case_index"] == expected_index
        @test collect(String.(propertynames(objective))) ==
              fixture["objective_field_order"]
        @test collect(String.(propertynames(objective.terms))) ==
              fixture["objective_term_field_order"]
        @test objective.schema_version == fixture["objective_schema_version"]
        @test fixture_bits(objective.value) == case["objective_value_bits"]
        @test fixture_bit_vector(objective.partial_derivatives) ==
              case["partial_derivative_bits"]
        @test fixture_bit_vector(objective.scalar_partial_derivatives) ==
              case["scalar_partial_derivative_bits"]
        @test fixture_bit_vector(objective.mean_state) ==
              case["mean_state_bits"]
        @test fixture_bits(objective.terms.channel) ==
              case["channel_term_bits"]
        @test fixture_bits(objective.terms.parity) ==
              case["parity_term_bits"]
        @test fixture_bits(objective.terms.binary) ==
              case["binary_term_bits"]
        @test fixture_bit_vector(objective.clipped_llr) ==
              case["clipped_llr_bits"]
        @test fixture_bit_vector(state) == case["state_bits"]
        @test fixture_bit_vector(llr) == case["llr_bits"]
        @test reinterpret(UInt64, state) == reinterpret(UInt64, state_before)
        @test reinterpret(UInt64, llr) == reinterpret(UInt64, llr_before)

        clipping_witnessed |= any(abs.(llr) .> 20.0)
        positive_clip_boundary_witnessed |= any(==(20.0), llr)
        negative_clip_boundary_witnessed |= any(==(-20.0), llr)
        positive_outside_clip_witnessed |= any(>(20.0), llr)
        negative_outside_clip_witnessed |= any(<(-20.0), llr)
        positive_zero_llr_witnessed |= any(
            ==("0000000000000000"), case["llr_bits"])
        negative_zero_llr_witnessed |= any(
            ==("8000000000000000"), case["llr_bits"])
        positive_zero_state_witnessed |= any(
            ==("0000000000000000"), case["state_bits"])
        negative_zero_state_witnessed |= any(
            ==("8000000000000000"), case["state_bits"])
        positive_boundary_state_witnessed |= any(==(1.0), state)
        negative_boundary_state_witnessed |= any(==(-1.0), state)
        exact_incident_mean_witnessed |= all(variable -> begin
            incident = graph.variable_edges[variable]
            all(edge -> fixture_bits(state[edge]) ==
                        fixture_bits(state[first(incident)]), incident)
        end, 1:graph.n)
        untied_incident_state_witnessed |= any(variable -> begin
            incident = graph.variable_edges[variable]
            any(edge -> fixture_bits(state[edge]) !=
                        fixture_bits(state[first(incident)]), incident)
        end, 1:graph.n)
    end
    @test clipping_witnessed
    @test positive_clip_boundary_witnessed
    @test negative_clip_boundary_witnessed
    @test positive_outside_clip_witnessed
    @test negative_outside_clip_witnessed
    @test positive_zero_llr_witnessed
    @test negative_zero_llr_witnessed
    @test positive_zero_state_witnessed
    @test negative_zero_state_witnessed
    @test positive_boundary_state_witnessed
    @test negative_boundary_state_witnessed
    @test exact_incident_mean_witnessed
    @test untied_incident_state_witnessed
end

@testset "authoritative fixture generator is excluded from inference" begin
    generator = read(joinpath(
        @__DIR__, "generate_authoritative_jc_fixture.jl"), String)
    runner = read(joinpath(@__DIR__, "runtests.jl"), String)
    @test occursin("EXPECTED_JC_SOURCE_SHA256", generator)
    @test occursin("EXPECTED_FIXED_DIAGONAL_SOURCE_SHA256", generator)
    @test occursin("CASE_COUNT = 40", generator)
    @test occursin("no scientific input", generator)
    @test occursin("Degrees 2 through 6", generator)
    @test !occursin("generate_authoritative_jc_fixture", runner)
end
