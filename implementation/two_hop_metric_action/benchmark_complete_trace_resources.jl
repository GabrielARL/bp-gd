#!/usr/bin/env julia

"""Production-size synthetic resource check for the dormant Stage-C source.

The harness loads only the local decoder and complete-trace checker. It builds
the deterministic synthetic regular degree-(3,6) graph already used by the
retained Stage-A source benchmark, runs literal synthetic LLR vectors, and
writes only scalar resource telemetry. It has no case-provider, comparison
receiver, transmitted-word, population, or scoring interface.
"""

module RQ2TwoHopStageCCompleteTraceResourceBenchmark

using Dates
using LinearAlgebra
using Random
using Serialization
using SHA
using TOML

include(joinpath(@__DIR__, "stage_c_decoder_source.jl"))
include(joinpath(@__DIR__, "stage_c_trace_integrity.jl"))

const Source = RQ2TwoHopStageCDecoderSource
const Integrity = RQ2TwoHopStageCTraceIntegrity
const Metric = Source.Metric

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-c-complete-trace-resource-v1"
const EXPERIMENT_ID = "RQ2-TWO-HOP-POSITIVE-METRIC-001"
const VARIABLES = 10_200
const CHECKS = 5_100
const EDGES = 30_600
const VARIABLE_DEGREE = 3
const CHECK_DEGREE = 6
const RANDOM_SEED = UInt64(0x74776f686f705741)
const EXPECTED_GRAPH_SHA256 =
    "900ead13c4c5972bc1ed5cb99a6abf3a19a8f5d574f2ce4592007a8206c46bf0"
const EXPECTED_LAYER_ATTEMPTS = [1, 5, 53]
const EXPECTED_PATH_COUNT = 306_000
const EXPECTED_GROUP_COUNT = 305_952
const EXPECTED_COSINE_LLR_SHA256 =
    "788f969501419fd533eb507a6ac36e78068b867bc1285857bca9029d4300b80a"
const EXPECTED_ZERO_LLR_SHA256 =
    "6d01559ce98858866c76c40b7f2415cd338142b7a4937f53e9f7094c79a1945e"
const REPETITIONS = 3
const MIB = 1024^2
const UPDATE_CAP_TRACE_LIMIT_BYTES = 96 * MIB
const IMMEDIATE_STALL_TRACE_LIMIT_BYTES = 16 * MIB
const CURRENT_SCHEMA_LIMIT_BYTES = 384 * MIB
const EXPECTED_UPDATE_CAP_RAW_VECTOR_BYTES = 69_768_000
const EXPECTED_IMMEDIATE_STALL_RAW_VECTOR_BYTES = 11_750_400
const EXPECTED_CURRENT_SCHEMA_MAX_RAW_VECTOR_BYTES = 334_152_000
const CELL_NAMES = (
    "candidate__cosine_update_cap",
    "lower_endpoint__cosine_update_cap",
    "candidate__zero_immediate_stall",
    "lower_endpoint__zero_immediate_stall",
)
const BOUND_SOURCE_NAMES = (
    "benchmark_complete_trace_resources.jl",
    "stage_c_decoder_source.jl",
    "stage_c_trace_integrity.jl",
    "two_hop_positive_metric.jl",
    "compound_objective_jc.jl",
)

file_sha256(path::AbstractString) = bytes2hex(open(sha256, path))

function _candidate_coefficients()
    Metric.MetricCoefficients(
        0.0,
        [-0.098969711158939794,
         -0.19129556359240465,
         -0.70584476358886339,
         -0.0036899816577923542],
    )
end

function _control_coefficients()
    Metric.MetricCoefficients(zeros(Float64, Metric.FAMILY_COUNT + 1))
end

function _synthetic_checks()
    rng = Xoshiro(RANDOM_SEED)
    permutations = Vector{Vector{Int}}()
    attempt_counts = Int[]
    for _ in 1:VARIABLE_DEGREE
        attempts = 0
        while true
            attempts += 1
            attempts <= 10_000 || error(
                "synthetic regular-graph construction exceeded its attempt cap")
            candidate = randperm(rng, VARIABLES)
            compatible = true
            for check in 1:CHECKS
                used = Int[]
                for existing in permutations
                    push!(used, existing[2check - 1], existing[2check])
                end
                if candidate[2check - 1] in used ||
                        candidate[2check] in used
                    compatible = false
                    break
                end
            end
            compatible || continue
            push!(permutations, candidate)
            push!(attempt_counts, attempts)
            break
        end
    end
    checks = [Int[
        value
        for layer in 1:VARIABLE_DEGREE
        for value in (
            permutations[layer][2check - 1],
            permutations[layer][2check],
        )
    ] for check in 1:CHECKS]
    checks, attempt_counts
end

function _checks_sha256(checks)
    io = IOBuffer()
    print(io, '[')
    for (check_index, members) in enumerate(checks)
        check_index == 1 || print(io, ',')
        print(io, '[')
        for (member_index, variable) in enumerate(members)
            member_index == 1 || print(io, ',')
            print(io, variable)
        end
        print(io, ']')
    end
    print(io, ']')
    bytes2hex(sha256(take!(io)))
end

function _production_graph()
    started = time_ns()
    checks, attempt_counts = _synthetic_checks()
    graph = Metric.EdgeGraph(checks, VARIABLES)
    pattern = Metric.TwoHopPattern(graph)
    seconds = (time_ns() - started) / 1.0e9
    graph_sha256 = _checks_sha256(checks)

    attempt_counts == EXPECTED_LAYER_ATTEMPTS || error(
        "synthetic graph layer-attempt counts changed")
    graph_sha256 == EXPECTED_GRAPH_SHA256 || error(
        "synthetic graph identity changed")
    graph.n == VARIABLES || error("synthetic variable count changed")
    length(graph.checks) == CHECKS || error("synthetic check count changed")
    Metric.edge_count(graph) == EDGES || error("synthetic edge count changed")
    all(length(check) == CHECK_DEGREE for check in graph.checks) || error(
        "synthetic check degree changed")
    all(length(star) == VARIABLE_DEGREE for star in graph.variable_edges) ||
        error("synthetic variable degree changed")
    Metric.path_count(pattern) == EXPECTED_PATH_COUNT || error(
        "synthetic two-hop path count changed")
    length(pattern.groups) == EXPECTED_GROUP_COUNT || error(
        "synthetic grouped-support count changed")

    (; graph, attempt_counts, graph_sha256, seconds,
       path_count=Metric.path_count(pattern),
       group_count=length(pattern.groups))
end

function _fixture(cell::AbstractString)
    cell in CELL_NAMES || error("unknown benchmark cell: $cell")
    candidate = startswith(cell, "candidate__")
    cosine = occursin("cosine_update_cap", cell)
    llr = cosine ?
        [2.0 * cos(0.001 * variable) for variable in 1:VARIABLES] :
        zeros(Float64, VARIABLES)
    llr_sha256 = Source.vector_sha256(llr)
    expected_sha256 = cosine ?
        EXPECTED_COSINE_LLR_SHA256 : EXPECTED_ZERO_LLR_SHA256
    llr_sha256 == expected_sha256 || error("synthetic LLR identity changed")
    (;
        arm=candidate ? "candidate" : "exact_zero_lower_endpoint",
        fixture=cosine ? "cosine_update_cap" : "zero_immediate_stall",
        llr,
        llr_sha256,
        coefficients=candidate ?
            _candidate_coefficients() : _control_coefficients(),
        expected_status=cosine ?
            "update_cap_reached" : "line_search_stalled",
        expected_attempted=cosine ? 30 : 1,
        expected_accepted=cosine ? 30 : 0,
        expected_trials=cosine ? 30 : 13,
        expected_states=cosine ? 31 : 1,
        expected_raw_vector_bytes=cosine ?
            EXPECTED_UPDATE_CAP_RAW_VECTOR_BYTES :
            EXPECTED_IMMEDIATE_STALL_RAW_VECTOR_BYTES,
        trace_limit_bytes=cosine ?
            UPDATE_CAP_TRACE_LIMIT_BYTES : IMMEDIATE_STALL_TRACE_LIMIT_BYTES,
    )
end

function _run_decoder(graph, fixture)
    if fixture.arm == "candidate"
        Source.run_candidate_decoder(
            graph, fixture.llr, fixture.coefficients;
            capture_vectors=true)
    else
        Source.run_lower_endpoint_decoder(
            graph, fixture.llr; capture_vectors=true)
    end
end

function _warm_sources()
    graph = Metric.EdgeGraph([[1, 2, 3], [1, 2, 3]], 3)
    candidate = _candidate_coefficients()
    cases = (
        (arm="candidate", llr=[1.3, -0.8, -0.6], coefficients=candidate),
        (arm="candidate", llr=zeros(3), coefficients=candidate),
        (arm="control", llr=[1.3, -0.8, -0.6],
         coefficients=_control_coefficients()),
        (arm="control", llr=zeros(3),
         coefficients=_control_coefficients()),
    )
    for case in cases
        trace = case.arm == "candidate" ?
            Source.run_candidate_decoder(
                graph, case.llr, case.coefficients; capture_vectors=true) :
            Source.run_lower_endpoint_decoder(
                graph, case.llr; capture_vectors=true)
        Integrity.validate_complete_decoder_trace(
            graph, case.llr, case.coefficients, trace)
        io = IOBuffer()
        serialize(io, trace)
        take!(io)
    end
    nothing
end

function _raw_vector_payload_bytes(trace::Source.DecoderTrace)
    state_dimension = length(trace.initial_state)
    bit_dimension = length(trace.initial_diagnostics.readout)
    float_count =
        2state_dimension + 2bit_dimension +
        length(trace.state_rows) * (2state_dimension + bit_dimension) +
        length(trace.iteration_rows) * 4state_dimension +
        length(trace.trial_rows) * 3state_dimension
    8 * float_count
end

function _require_trace_shape(trace, fixture)
    trace.status == fixture.expected_status || error(
        "synthetic terminal status changed")
    trace.attempted_updates == fixture.expected_attempted || error(
        "synthetic attempted-update count changed")
    trace.accepted_updates == fixture.expected_accepted || error(
        "synthetic accepted-update count changed")
    length(trace.trial_rows) == fixture.expected_trials || error(
        "synthetic trial-row count changed")
    length(trace.state_rows) == fixture.expected_states || error(
        "synthetic state-row count changed")
    true
end

function _timing_fields(measured)
    Dict{String,Any}(
        "seconds" => measured.time,
        "allocated_bytes" => measured.bytes,
        "gc_seconds" => measured.gctime,
        "compile_seconds" => measured.compile_time,
        "recompile_seconds" => measured.recompile_time,
        "lock_conflicts" => measured.lock_conflicts,
    )
end

function _measure_repetition(graph, fixture, repetition::Int)
    GC.gc()
    decoded = @timed _run_decoder(graph, fixture)
    trace = decoded.value
    _require_trace_shape(trace, fixture)

    trace_summary_bytes = Base.summarysize(trace)
    raw_vector_payload_bytes = _raw_vector_payload_bytes(trace)
    raw_vector_payload_bytes == fixture.expected_raw_vector_bytes || error(
        "synthetic raw-vector payload changed")
    trace_summary_bytes <= fixture.trace_limit_bytes || error(
        "synthetic trace exceeds its fixture-specific resource limit")

    GC.gc()
    checked = @timed Integrity.validate_complete_decoder_trace(
        graph, fixture.llr, fixture.coefficients, trace)
    checked.value.update_trial_state_correspondence_verified || error(
        "complete-trace checker did not close update/trial/state links")

    GC.gc()
    serialized = @timed begin
        io = IOBuffer()
        serialize(io, trace)
        take!(io)
    end
    serialized_bytes = serialized.value
    length(serialized_bytes) <= fixture.trace_limit_bytes || error(
        "synthetic serialized trace exceeds its fixture-specific limit")
    serialization_sha256 = bytes2hex(sha256(serialized_bytes))

    record = Dict{String,Any}(
        "repetition" => repetition,
        "status" => trace.status,
        "attempted_updates" => trace.attempted_updates,
        "accepted_updates" => trace.accepted_updates,
        "trial_record_count" => length(trace.trial_rows),
        "state_record_count" => length(trace.state_rows),
        "first_parity_valid_update" =>
            something(trace.first_parity_valid_update, -1),
        "terminal_state_sha256" =>
            Source.vector_sha256(trace.terminal_state),
        "trace_summary_bytes" => trace_summary_bytes,
        "raw_vector_payload_bytes" => raw_vector_payload_bytes,
        "serialized_bytes" => length(serialized_bytes),
        "serialization_sha256" => serialization_sha256,
        "decode" => _timing_fields(decoded),
        "complete_trace_check" => _timing_fields(checked),
        "serialization" => _timing_fields(serialized),
    )
    trace = nothing
    serialized_bytes = nothing
    GC.gc()
    record
end

function _source_hashes()
    paths = Dict(
        "benchmark_complete_trace_resources.jl" => @__FILE__,
        "stage_c_decoder_source.jl" =>
            joinpath(@__DIR__, "stage_c_decoder_source.jl"),
        "stage_c_trace_integrity.jl" =>
            joinpath(@__DIR__, "stage_c_trace_integrity.jl"),
        "two_hop_positive_metric.jl" => Source.METRIC_SOURCE_PATH,
        "compound_objective_jc.jl" => Source.OBJECTIVE_SOURCE_PATH,
    )
    Set(keys(paths)) == Set(BOUND_SOURCE_NAMES) || error(
        "benchmark source-hash closure changed")
    Dict(name => file_sha256(path) for (name, path) in paths)
end

function _benchmark_cell(cell::AbstractString)
    Threads.nthreads() == 1 || error("benchmark requires one Julia thread")
    LinearAlgebra.BLAS.get_num_threads() == 1 || error(
        "benchmark requires one BLAS thread")
    get(ENV, "OMP_NUM_THREADS", "") == "1" || error(
        "benchmark requires OMP_NUM_THREADS=1")

    _warm_sources()
    GC.gc()
    built = _production_graph()
    fixture = _fixture(cell)
    GC.gc()

    repetitions = Dict{String,Any}[]
    for repetition in 1:REPETITIONS
        push!(repetitions,
              _measure_repetition(built.graph, fixture, repetition))
    end
    terminal_hashes = unique(
        row["terminal_state_sha256"] for row in repetitions)
    length(terminal_hashes) == 1 || error(
        "terminal state changed across resource repetitions")
    statuses = unique(row["status"] for row in repetitions)
    length(statuses) == 1 || error(
        "terminal status changed across resource repetitions")
    raw_sizes = unique(row["raw_vector_payload_bytes"] for row in repetitions)
    raw_sizes == [fixture.expected_raw_vector_bytes] || error(
        "raw-vector payload changed across resource repetitions")

    Dict{String,Any}(
        "cell" => String(cell),
        "arm" => fixture.arm,
        "fixture" => fixture.fixture,
        "llr_sha256" => fixture.llr_sha256,
        "coefficient_role" => fixture.arm == "candidate" ?
            "literal retained Stage-A provenance transcription; not a governance seal" :
            "exact-zero registered lower endpoint",
        "trace_limit_bytes" => fixture.trace_limit_bytes,
        "expected_status" => fixture.expected_status,
        "expected_attempted_updates" => fixture.expected_attempted,
        "expected_accepted_updates" => fixture.expected_accepted,
        "expected_trial_record_count" => fixture.expected_trials,
        "expected_state_record_count" => fixture.expected_states,
        "expected_raw_vector_payload_bytes" =>
            fixture.expected_raw_vector_bytes,
        "repetition_count" => REPETITIONS,
        "repetitions" => repetitions,
        "child_peak_rss_bytes" => Int(Sys.maxrss()),
        "graph_build_seconds" => built.seconds,
        "graph_sha256" => built.graph_sha256,
        "graph_layer_attempt_counts" => built.attempt_counts,
        "path_count" => built.path_count,
        "group_count" => built.group_count,
        "source_sha256" => _source_hashes(),
        "decoder_schema_version" => Source.SCHEMA_VERSION,
        "checker_schema_version" => Integrity.SCHEMA_VERSION,
        "registered_frames_opened" => false,
        "retained_or_fresh_data_opened" => false,
        "comparison_receiver_loaded" => false,
        "truth_or_performance_scoring" => false,
    )
end

function _child_command(cell::AbstractString)
    project = Base.active_project()
    project === nothing && error("benchmark requires an active Julia project")
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(project)) $(@__FILE__) --child $cell`
    setenv(command, merge(copy(ENV), Dict(
        "JULIA_NUM_THREADS" => "1",
        "OPENBLAS_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "MKL_NUM_THREADS" => "1",
    )))
end

function _exclusive_write_toml(path::AbstractString, record)
    absolute = abspath(path)
    normpath(absolute) == absolute || error(
        "resource-measurement output must be normalized")
    ispath(absolute) && error(
        "refusing to overwrite resource measurement: $absolute")
    isdir(dirname(absolute)) || error(
        "resource-measurement output parent is missing")
    flags = Base.Filesystem.JL_O_WRONLY | Base.Filesystem.JL_O_CREAT |
        Base.Filesystem.JL_O_EXCL
    io = Base.Filesystem.open(absolute, flags, 0o600)
    try
        TOML.print(io, record; sorted=true)
        write(io, '\n')
        flush(io)
        ccall(:fsync, Cint, (Cint,), fd(io)) == 0 || error(
            "resource-measurement fsync failed")
    finally
        close(io)
    end
    absolute
end

function benchmark(output::AbstractString)
    EXPECTED_CURRENT_SCHEMA_MAX_RAW_VECTOR_BYTES <=
        CURRENT_SCHEMA_LIMIT_BYTES || error(
            "calculated current-schema payload exceeds its engineering limit")
    cells = Dict{String,Any}[]
    for cell in CELL_NAMES
        started = time_ns()
        child_text = read(_child_command(cell), String)
        record = TOML.parse(child_text)
        record["cell"] == cell || error("child returned the wrong cell")
        record["registered_frames_opened"] === false || error(
            "child claims registered-frame access")
        record["retained_or_fresh_data_opened"] === false || error(
            "child claims non-synthetic data access")
        record["comparison_receiver_loaded"] === false || error(
            "child claims a comparison receiver")
        record["truth_or_performance_scoring"] === false || error(
            "child claims truth or performance scoring")
        record["child_process_seconds"] =
            (time_ns() - started) / 1.0e9
        push!(cells, record)
    end

    source_hashes = _source_hashes()
    all(cell -> cell["source_sha256"] == source_hashes, cells) || error(
        "child source identities differ from the parent")
    record = Dict{String,Any}(
        "schema_version" => SCHEMA_VERSION,
        "experiment_id" => EXPERIMENT_ID,
        "created_utc" => string(now(UTC)),
        "classification" =>
            "synthetic complete-trace resource measurement; not scientific evidence or a registered wall budget",
        "synthetic_only" => true,
        "stage_c_activated" => false,
        "registered_frames_opened" => false,
        "retained_or_fresh_data_opened" => false,
        "case_provider_imported" => false,
        "comparison_receiver_loaded" => false,
        "truth_or_performance_scoring" => false,
        "capsule_or_service_created" => false,
        "scientific_result" => false,
        "approaches_bp_result" => false,
        "julia_version" => string(VERSION),
        "kernel" => string(Sys.KERNEL),
        "architecture" => string(Sys.ARCH),
        "cpu_name" => Sys.CPU_NAME,
        "julia_threads_per_child" => 1,
        "blas_threads_per_child" => 1,
        "omp_threads_per_child" => 1,
        "variables" => VARIABLES,
        "checks" => CHECKS,
        "edges" => EDGES,
        "variable_degree" => VARIABLE_DEGREE,
        "check_degree" => CHECK_DEGREE,
        "random_seed_uint64" => string(RANDOM_SEED),
        "graph_sha256" => EXPECTED_GRAPH_SHA256,
        "graph_layer_attempt_counts" => EXPECTED_LAYER_ATTEMPTS,
        "path_count" => EXPECTED_PATH_COUNT,
        "group_count" => EXPECTED_GROUP_COUNT,
        "cosine_llr_sha256" => EXPECTED_COSINE_LLR_SHA256,
        "zero_llr_sha256" => EXPECTED_ZERO_LLR_SHA256,
        "repetition_count_per_cell" => REPETITIONS,
        "cell_count" => length(CELL_NAMES),
        "cells" => cells,
        "source_sha256" => source_hashes,
        "candidate_coefficients" => Dict(
            "theta_0" => _candidate_coefficients().theta0,
            "beta" => collect(_candidate_coefficients().beta),
            "role" =>
                "literal retained Stage-A provenance transcription; not a governance seal",
        ),
        "resource_limits" => Dict(
            "cosine_update_cap_trace_bytes" =>
                UPDATE_CAP_TRACE_LIMIT_BYTES,
            "zero_immediate_stall_trace_bytes" =>
                IMMEDIATE_STALL_TRACE_LIMIT_BYTES,
            "current_schema_engineering_bytes" =>
                CURRENT_SCHEMA_LIMIT_BYTES,
            "current_schema_max_raw_vector_payload_bytes" =>
                EXPECTED_CURRENT_SCHEMA_MAX_RAW_VECTOR_BYTES,
            "boundary" =>
                "trace and serialization engineering limits only; not peak-RSS, allocation, scientific-run, or late-stall caps",
        ),
    )
    written = _exclusive_write_toml(output, record)
    println("synthetic_only=true")
    println("registered_frames_opened=false")
    println("scientific_result=false")
    println("cell_count=$(length(cells))")
    println("output=$written")
    record
end

function main(arguments=ARGS)
    if length(arguments) == 2 && arguments[1] == "--child"
        record = _benchmark_cell(arguments[2])
        TOML.print(stdout, record; sorted=true)
        write(stdout, '\n')
        return nothing
    end
    length(arguments) == 1 || error(
        "usage: benchmark_complete_trace_resources.jl OUTPUT.toml")
    benchmark(arguments[1])
    nothing
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2TwoHopStageCCompleteTraceResourceBenchmark.main()
end
