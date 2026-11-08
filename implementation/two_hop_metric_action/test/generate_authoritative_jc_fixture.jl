#!/usr/bin/env julia

using Random
using SHA

const EXPECTED_JC_SOURCE_SHA256 =
    "000371f8b403e426c4757e691e10a70a0b5222376e879f83577b77b82c838d5c"
const EXPECTED_FIXED_DIAGONAL_SOURCE_SHA256 =
    "f2f92ca7f06264b079785534cf15c1ddf5f1e9985f384879b19244b2368204bb"
const CASE_COUNT = 40
const GENERATOR_SEED = 0x5a17c0de
const PARITY_WEIGHT = 2.0
const BINARY_WEIGHT = 0.2
const LLR_CLIP_MIN = -20.0
const LLR_CLIP_MAX = 20.0

sha256_file(path::AbstractString) = bytes2hex(sha256(read(path)))

function float_bits(value)
    string(reinterpret(UInt64, Float64(value)); base=16, pad=16)
end

float_bit_array(values) = [float_bits(value) for value in values]
toml_string_array(values) = "[" * join(repr.(values), ", ") * "]"

function input_corpus_sha256(graph, cases)
    fields = String[
        "n=$(graph.n)",
        "checks=$(repr(graph.checks))",
        "check_edges=$(repr(collect.(graph.check_edges)))",
        "variable_edges=$(repr(graph.variable_edges))",
        "edge_variable=$(repr(graph.edge_variable))",
        "edge_check=$(repr(graph.edge_check))",
    ]
    for case in cases
        push!(fields, "case=$(case.case_index)")
        push!(fields, "state=$(join(float_bit_array(case.state), ','))")
        push!(fields, "llr=$(join(float_bit_array(case.llr), ','))")
    end
    bytes2hex(sha256(join(fields, '\n')))
end

length(ARGS) == 1 || error(
    "usage: generate_authoritative_jc_fixture.jl STAGE_C_DECODER_SOURCE")
stage_c_source = abspath(ARGS[1])
isfile(stage_c_source) || error("registered Stage-C source is absent")
sha256_file(stage_c_source) == EXPECTED_FIXED_DIAGONAL_SOURCE_SHA256 ||
    error("registered fixed-diagonal source hash differs")

jc_source = normpath(joinpath(
    dirname(stage_c_source), "..", "..", "graph_factorized_energy.jl"))
isfile(jc_source) || error("registered J_C source is absent")
sha256_file(jc_source) == EXPECTED_JC_SOURCE_SHA256 ||
    error("registered J_C source hash differs")

include(stage_c_source)
const StageC = RQ2GraphFactorizedEnergyStageCDecoder
const Energy = StageC.Energy

# Degrees 2 through 6 are all represented. Variable degrees are nonuniform.
checks = [
    [1, 2],
    [1, 3, 4],
    [2, 3, 5, 6],
    [1, 4, 5, 7, 8],
    [2, 3, 4, 6, 7, 8],
    [1, 5, 6, 8],
]
graph = Energy.EdgeGraph(checks, 8)
metric = StageC.fixed_metric_diagonal(graph)
rng = MersenneTwister(GENERATOR_SEED)

cases = NamedTuple[]
for case_index in 1:CASE_COUNT
    state = 1.8 .* rand(rng, Energy.edge_count(graph)) .- 0.9
    if case_index % 5 == 0
        for incident in graph.variable_edges
            fill_value = state[first(incident)]
            for edge in incident
                state[edge] = fill_value
            end
        end
    end
    state_case = case_index % 10
    state_case == 1 && (state[1] = 0.0)
    state_case == 2 && (state[1] = -0.0)
    state_case == 3 && (state[1] = 1.0)
    state_case == 4 && (state[1] = -1.0)

    llr = 50.0 .* rand(rng, graph.n) .- 25.0
    llr_case = case_index % 8
    llr_case == 1 && (llr[1] = LLR_CLIP_MAX)
    llr_case == 2 && (llr[1] = LLR_CLIP_MIN)
    llr_case == 3 && (llr[1] = 25.0)
    llr_case == 4 && (llr[1] = -25.0)
    llr_case == 5 && (llr[1] = 0.0)
    llr_case == 6 && (llr[1] = -0.0)

    objective = Energy.native_compound_objective_gradient(graph, llr, state)
    push!(cases, (; case_index, state, llr, objective))
end

println("schema_version = ", repr(
    "rq2-two-hop-positive-metric-001/authoritative-jc-fixture-v2"))
println("classification = ", repr(
    "deterministic synthetic arithmetic fixture; no scientific input"))
println("corpus_id = ", repr(
    "rq2-two-hop-positive-metric-001/portable-jc-corpus-40-v2"))
println("input_corpus_sha256 = ", repr(input_corpus_sha256(graph, cases)))
println("float_encoding = ", repr(
    "IEEE-754 binary64 bit pattern as 16 lowercase hexadecimal digits"))
println("generator_julia_version = ", repr(string(VERSION)))
println("generator_seed = ", Int(GENERATOR_SEED))
println("case_count = ", CASE_COUNT)
println("graph_n = ", graph.n)
println("graph_checks = ", repr(checks))
println("graph_check_edges = ", repr(collect.(graph.check_edges)))
println("graph_variable_edges = ", repr(graph.variable_edges))
println("graph_edge_variable = ", repr(graph.edge_variable))
println("graph_edge_check = ", repr(graph.edge_check))
println("check_degrees = ", repr(length.(graph.checks)))
println("variable_degrees = ", repr(length.(graph.variable_edges)))
println("edge_count = ", Energy.edge_count(graph))
println("objective_schema_version = ", repr(
    "rq2-two-hop-positive-metric-001/compound-objective-jc-v1"))
println("objective_field_order = ", toml_string_array([
    "schema_version", "value", "partial_derivatives",
    "scalar_partial_derivatives", "mean_state", "terms", "clipped_llr"]))
println("objective_term_field_order = ",
        toml_string_array(["channel", "parity", "binary"]))
println("parity_weight_bits = ", repr(float_bits(PARITY_WEIGHT)))
println("binary_weight_bits = ", repr(float_bits(BINARY_WEIGHT)))
println("llr_clip_min_bits = ", repr(float_bits(LLR_CLIP_MIN)))
println("llr_clip_max_bits = ", repr(float_bits(LLR_CLIP_MAX)))
println("metric_diagonal_bits = ",
        toml_string_array(float_bit_array(metric)))

println()
println("[sources]")
println("registered_jc_source_path = ", repr(jc_source))
println("registered_jc_source_sha256 = ", repr(EXPECTED_JC_SOURCE_SHA256))
println("registered_fixed_diagonal_source_path = ", repr(stage_c_source))
println("registered_fixed_diagonal_source_sha256 = ",
        repr(EXPECTED_FIXED_DIAGONAL_SOURCE_SHA256))
println("generator_source_sha256 = ", repr(sha256_file(@__FILE__)))
println("production_jc_source_sha256 = ", repr(sha256_file(joinpath(
    @__DIR__, "..", "compound_objective_jc.jl"))))

for case in cases
    objective = case.objective
    println()
    println("[[cases]]")
    println("case_index = ", case.case_index)
    println("state_bits = ", toml_string_array(float_bit_array(case.state)))
    println("llr_bits = ", toml_string_array(float_bit_array(case.llr)))
    println("objective_value_bits = ", repr(float_bits(objective.value)))
    println("partial_derivative_bits = ",
            toml_string_array(float_bit_array(objective.gradient)))
    println("scalar_partial_derivative_bits = ",
            toml_string_array(float_bit_array(objective.scalar_gradient)))
    println("mean_state_bits = ",
            toml_string_array(float_bit_array(objective.x)))
    println("channel_term_bits = ",
            repr(float_bits(objective.terms.channel)))
    println("parity_term_bits = ",
            repr(float_bits(objective.terms.parity)))
    println("binary_term_bits = ",
            repr(float_bits(objective.terms.binary)))
    println("clipped_llr_bits = ",
            toml_string_array(float_bit_array(objective.clipped_llr)))
end
