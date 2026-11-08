#!/usr/bin/env julia

module RQ2ConvexParityDistanceCandidateRunner

using ConvexParityDistance
using LinearAlgebra
using SHA

include(joinpath(@__DIR__, "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-001"
const EXECUTION_SCHEMA = "rq2-convex-parity-distance-001/candidate-execution-v1"
const SCIENCE_SCHEMA = "rq2-convex-parity-distance-001/scientific-trace-v1"
const FRAME_FIRST = 61969
const FRAME_LAST = 62168
const CASE_COUNT = 200
const N = 10200
const M = 5100
const E = 30600
const CHECKPOINTS = (30, 90, 300, 1000, 3000, 6000)
const UPDATE_CAP = 6000
const MAPPING_TOLERANCE = 1.0e-8
const INTEGRALITY_TOLERANCE = 1.0e-8
const REGISTERED_GRAPH_SHA256 =
    "94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d"
const GRAPH_BINARY_SHA256 =
    "18b46e41ee01464498085aeebf98a1ae489058739255a5d4994cd93e4d89246c"
const PACKET_MEMBERS = String[
    "case_index.csv", "checks_i32_6_by_m.bin", "llr_f64_n_by_200.bin",
    "packet_config.csv",
]

const CASE_HEADER = String[
    "case_ordinal", "frame", "llr_sha256", "candidate_initial_b_sha256",
    "first_valid_update", "terminal_update", "stop_reason",
    "terminal_mapping_norm_inf", "terminal_state_sha256",
    "terminal_hard_sha256", "terminal_syndrome_weight",
    "terminal_tie_count", "terminal_parity_valid", "latched_hard_sha256",
    "per_update_scientific_trace_sha256", "core_projection_calls",
    "diagnostic_projection_calls", "core_objective_edge_visits",
    "diagnostic_objective_edge_visits", "readout_edge_visits",
    "checkpoint_evaluations",
]
const TRACE_HEADER = String[
    "case_ordinal", "frame", "update", "row_kind", "llr_sha256",
    "state_sha256", "hard_sha256", "objective", "normalized_objective",
    "signal_term", "normalized_signal_term", "parity_term",
    "normalized_parity_term", "projected_gradient_mapping_inf",
    "syndrome_weight", "tie_count", "parity_valid",
    "squared_distance_sum", "maximum_check_distance",
    "exact_nonzero_distance_checks", "distance_above_1e_10_checks",
    "strict_interior_coordinates", "fractional_1e_8_coordinates",
    "first_valid_update", "core_projection_calls",
    "diagnostic_projection_calls", "core_objective_edge_visits",
    "diagnostic_objective_edge_visits", "readout_edge_visits",
]
const STATE_INDEX_HEADER = String[
    "case_ordinal", "frame", "update", "role", "byte_offset", "byte_count",
    "coordinate_count", "state_sha256",
]
const HARD_INDEX_HEADER = String[
    "case_ordinal", "frame", "update", "role", "byte_offset", "byte_count",
    "bit_count", "hard_sha256", "packed_sha256", "syndrome_weight",
    "tie_count", "parity_valid",
]

struct CandidatePacket
    checks::Vector{Vector{Int}}
    llrs::Matrix{Float64}
    case_rows::Vector{Dict{String,String}}
    packet_ready_sha256::String
    packet_manifest_sha256::String
end

mutable struct Collector
    capture::Bool
    state_io::IOBuffer
    hard_io::IOBuffer
    state_offset::Int
    hard_offset::Int
    state_rows::Vector{Vector{String}}
    hard_rows::Vector{Vector{String}}
end
Collector(capture::Bool) = Collector(capture, IOBuffer(), IOBuffer(), 0, 0,
                                     Vector{Vector{String}}(),
                                     Vector{Vector{String}}())

function graph_identity(checks)
    io = IOBuffer()
    for check in checks
        write(io, htol(Int32(length(check))))
        for bit in check
            write(io, htol(Int32(bit)))
        end
    end
    bytes2hex(sha256(take!(io)))
end

function read_graph(path)
    file_sha256(path) == GRAPH_BINARY_SHA256 || error("packet graph hash differs")
    filesize(path) == sizeof(Int32) * 6 * M ||
        throw(DimensionMismatch("packet graph size differs"))
    raw = Vector{Int32}(undef, 6M)
    open(path, "r") do io
        read!(io, raw)
        eof(io) || error("packet graph has trailing bytes")
    end
    matrix = reshape(raw, 6, M)
    checks = [Int.(matrix[:, check]) for check in 1:M]
    degrees = zeros(Int, N)
    for check in checks, bit in check
        1 <= bit <= N || error("packet graph bit index is out of range")
        degrees[bit] += 1
    end
    all(==(3), degrees) || error("packet graph variable degree differs")
    graph_identity(checks) == REGISTERED_GRAPH_SHA256 ||
        error("packet graph scientific identity differs")
    checks
end

function load_packet(root::String)
    ready_path = joinpath(root, "PACKET_READY.txt")
    ready = read_key_values(ready_path)
    Set(keys(ready)) == Set((
        "schema", "experiment_id", "case_count", "manifest_file",
        "manifest_sha256", "truth_fields_present",
        "comparison_decoder_fields_present")) ||
        error("packet-ready fields differ")
    ready["experiment_id"] == EXPERIMENT_ID || error("packet experiment differs")
    parse(Int, ready["case_count"]) == CASE_COUNT || error("packet count differs")
    ready["truth_fields_present"] == "false" || error("packet has forbidden fields")
    ready["comparison_decoder_fields_present"] == "false" ||
        error("packet has comparison-decoder fields")
    manifest_name = ready["manifest_file"]
    Set(readdir(root)) == Set(vcat(
        PACKET_MEMBERS, ["PACKET_READY.txt", manifest_name])) ||
        error("packet root contains an unregistered file")
    file_sha256(joinpath(root, manifest_name)) == ready["manifest_sha256"] ||
        error("packet manifest hash differs")
    verify_sha_manifest(root, manifest_name; expected_members=PACKET_MEMBERS)

    config_table = read_csv(joinpath(root, "packet_config.csv"))
    config = Dict(row["field"] => row["value"] for row in config_table.rows)
    Set(keys(config)) == Set((
        "schema", "experiment_id", "case_count", "frame_first", "frame_last",
        "n", "m", "edge_count", "check_degree", "variable_degree",
        "graph_binary_sha256", "graph_scientific_sha256", "llr_binary_sha256",
        "llr_encoding", "truth_fields_present",
        "comparison_decoder_fields_present")) ||
        error("packet config fields differ")
    config["experiment_id"] == EXPERIMENT_ID || error("packet config differs")
    parse(Int, config["case_count"]) == CASE_COUNT || error("packet config count differs")
    config["truth_fields_present"] == "false" || error("packet config has forbidden fields")
    config["comparison_decoder_fields_present"] == "false" ||
        error("packet config has comparison fields")

    checks = read_graph(joinpath(root, "checks_i32_6_by_m.bin"))
    llr_path = joinpath(root, "llr_f64_n_by_200.bin")
    file_sha256(llr_path) == config["llr_binary_sha256"] ||
        error("packet LLR binary hash differs")
    filesize(llr_path) == sizeof(Float64) * N * CASE_COUNT ||
        throw(DimensionMismatch("packet LLR binary size differs"))
    raw = Vector{Float64}(undef, N * CASE_COUNT)
    open(llr_path, "r") do io
        read!(io, raw)
        eof(io) || error("packet LLR binary has trailing bytes")
    end
    llrs = reshape(raw, N, CASE_COUNT)
    index = read_csv(joinpath(root, "case_index.csv"))
    Set(index.header) == Set(("case_ordinal", "frame", "graph_sha256",
                             "clipped_llr_sha256", "candidate_initial_b_sha256")) ||
        error("packet case-index fields differ")
    length(index.rows) == CASE_COUNT || error("packet index count differs")
    ordered = sort(index.rows; by=row -> parse(Int, row["case_ordinal"]))
    for (ordinal, row) in enumerate(ordered)
        parse(Int, row["case_ordinal"]) == ordinal || error("packet ordinal differs")
        parse(Int, row["frame"]) == FRAME_FIRST + ordinal - 1 ||
            error("packet frame sequence differs")
        row["graph_sha256"] == REGISTERED_GRAPH_SHA256 ||
            error("packet case graph hash differs")
        llr = view(llrs, :, ordinal)
        vector_sha256(llr) == row["clipped_llr_sha256"] ||
            error("packet per-case LLR hash differs")
        vector_sha256(initialize_state(Problem(checks, llr))) ==
            row["candidate_initial_b_sha256"] ||
            error("packet initial-state hash differs")
    end
    CandidatePacket(checks, llrs, ordered, file_sha256(ready_path),
                    ready["manifest_sha256"])
end

function capture_state!(collector, ordinal, frame, update, role, state)
    bytes = reinterpret(UInt8, state)
    digest = vector_sha256(state)
    collector.capture && write(collector.state_io, bytes)
    push!(collector.state_rows, String[
        string(ordinal), string(frame), string(update), role,
        string(collector.state_offset), string(length(bytes)), string(length(state)),
        digest,
    ])
    collector.state_offset += length(bytes)
    digest
end

function capture_hard!(collector, ordinal, frame, update, role, hard,
                       readout)
    packed = pack_bits(hard)
    hard_hash = vector_sha256(hard)
    collector.capture && write(collector.hard_io, packed)
    push!(collector.hard_rows, String[
        string(ordinal), string(frame), string(update), role,
        string(collector.hard_offset), string(length(packed)), string(length(hard)),
        hard_hash, bytes_sha256(packed), string(readout.syndrome_weight),
        string(readout.tie_count), bool_text(readout.parity_valid),
    ])
    collector.hard_offset += length(packed)
    hard_hash
end

function checkpoint_row(ordinal, frame, update, kind, llr_hash, state_hash,
                        hard_hash, evaluated, readout, state, first_valid,
                        diagnostic_evaluations)
    interior = count(value -> 0.0 < value < 1.0, state)
    fractional = count(value ->
        INTEGRALITY_TOLERANCE < value < 1.0 - INTEGRALITY_TOLERANCE, state)
    core_projections = update * M
    diagnostic_projections = diagnostic_evaluations * M
    String[
        string(ordinal), string(frame), string(update), kind, llr_hash,
        state_hash, hard_hash, f64_text(evaluated.value),
        f64_text(evaluated.normalized_value), f64_text(evaluated.signal),
        f64_text(evaluated.normalized_signal), f64_text(evaluated.parity),
        f64_text(evaluated.normalized_parity), f64_text(evaluated.mapping_norm_inf),
        string(readout.syndrome_weight), string(readout.tie_count),
        bool_text(readout.parity_valid), f64_text(evaluated.squared_distance_sum),
        f64_text(evaluated.maximum_check_distance),
        string(evaluated.infeasible_checks),
        string(evaluated.checks_above_distance_tolerance), string(interior),
        string(fractional), first_valid == 0 ? "" : string(first_valid),
        string(core_projections), string(diagnostic_projections),
        string(core_projections * 6), string(diagnostic_projections * 6),
        string(update * E),
    ]
end

function write_transition!(io, update, summary, readout)
    write(io, UInt8(1), Int64(update), summary.objective_before,
          summary.mapping_norm_inf, Int32(readout.syndrome_weight),
          Int32(readout.tie_count), readout.parity_valid ? UInt8(1) : UInt8(0))
end

function write_checkpoint!(io, update, evaluated, readout, state_hash, hard_hash)
    write(io, UInt8(2), Int64(update), evaluated.value,
          evaluated.normalized_value, evaluated.signal, evaluated.parity,
          evaluated.mapping_norm_inf, Int32(readout.syndrome_weight),
          Int32(readout.tie_count), readout.parity_valid ? UInt8(1) : UInt8(0),
          evaluated.squared_distance_sum, evaluated.maximum_check_distance,
          Int32(evaluated.infeasible_checks),
          Int32(evaluated.checks_above_distance_tolerance),
          codeunits(state_hash), codeunits(hard_hash))
end

function run_case!(packet, collector, trace_rows, ordinal)
    frame = FRAME_FIRST + ordinal - 1
    llr = copy(view(packet.llrs, :, ordinal))
    llr_hash = vector_sha256(llr)
    problem = Problem(packet.checks, llr)
    state = initialize_state(problem)
    initial_hash = vector_sha256(state)
    initial_hash == packet.case_rows[ordinal]["candidate_initial_b_sha256"] ||
        error("candidate initial hash differs from packet")
    workspace = SolverWorkspace(problem)
    science = IOBuffer()
    write(science, codeunits(SCIENCE_SCHEMA), Int32(ordinal), Int32(frame))
    first_valid = 0
    latched_hash = ""
    diagnostic_evaluations = 1

    readout = readout!(workspace, problem, state)
    evaluated = checkpoint_evaluate!(workspace, problem, state; capture_hash=true)
    state_hash = capture_state!(collector, ordinal, frame, 0, "initial", state)
    hard_hash = capture_hard!(collector, ordinal, frame, 0, "initial",
                              copy(workspace.hard), readout)
    push!(trace_rows, checkpoint_row(ordinal, frame, 0, "initial", llr_hash,
                                     state_hash, hard_hash, evaluated, readout,
                                     state, first_valid, diagnostic_evaluations))
    write_checkpoint!(science, 0, evaluated, readout, state_hash, hard_hash)
    previous_objective = evaluated.value
    terminal = nothing

    for update in 1:UPDATE_CAP
        summary = step!(workspace, problem, state)
        summary.objective_before <= previous_objective +
            1.0e-11 * max(1.0, abs(previous_objective)) ||
            error("objective increased at frame $frame update $update")
        previous_objective = summary.objective_before
        readout = readout!(workspace, problem, state)
        write_transition!(science, update, summary, readout)
        if first_valid == 0 && readout.parity_valid
            first_valid = update
            latched_hash = capture_hard!(collector, ordinal, frame, update,
                                         "latched", copy(workspace.hard), readout)
        end
        update in CHECKPOINTS || continue
        diagnostic_evaluations += 1
        evaluated = checkpoint_evaluate!(workspace, problem, state;
                                         capture_hash=true)
        state_hash = evaluated.state_sha256
        hard_hash = vector_sha256(workspace.hard)
        meets_tolerance = evaluated.mapping_norm_inf <= MAPPING_TOLERANCE
        is_terminal = meets_tolerance || update == UPDATE_CAP
        role = is_terminal ? "terminal" : "checkpoint"
        state_hash == capture_state!(collector, ordinal, frame, update, role,
                                     state) || error("state hash differs")
        hard_hash == capture_hard!(collector, ordinal, frame, update, role,
                                   copy(workspace.hard), readout) ||
            error("hard-decision hash differs")
        push!(trace_rows, checkpoint_row(
            ordinal, frame, update,
            is_terminal ? "checkpoint_terminal" : "checkpoint", llr_hash,
            state_hash, hard_hash, evaluated, readout, state, first_valid,
            diagnostic_evaluations))
        write_checkpoint!(science, update, evaluated, readout, state_hash, hard_hash)
        previous_objective = evaluated.value
        if is_terminal
            terminal = (; update, evaluated, readout, state_hash, hard_hash,
                         stop_reason=meets_tolerance ?
                            "numerical_global_optimum" : "optimization_unresolved")
            break
        end
    end
    terminal === nothing && error("case has no terminal record")
    core_projections = terminal.update * M
    diagnostic_projections = diagnostic_evaluations * M
    String[
        string(ordinal), string(frame), llr_hash, initial_hash,
        first_valid == 0 ? "" : string(first_valid), string(terminal.update),
        terminal.stop_reason, f64_text(terminal.evaluated.mapping_norm_inf),
        terminal.state_hash, terminal.hard_hash,
        string(terminal.readout.syndrome_weight),
        string(terminal.readout.tie_count), bool_text(terminal.readout.parity_valid),
        latched_hash, bytes_sha256(take!(science)), string(core_projections),
        string(diagnostic_projections), string(core_projections * 6),
        string(diagnostic_projections * 6), string(terminal.update * E),
        string(diagnostic_evaluations),
    ]
end

function science_digest(case_rows, trace_rows, collector)
    io = IOBuffer()
    write(io, codeunits(SCIENCE_SCHEMA), csv_bytes(CASE_HEADER, case_rows),
          csv_bytes(TRACE_HEADER, trace_rows),
          csv_bytes(STATE_INDEX_HEADER, collector.state_rows),
          csv_bytes(HARD_INDEX_HEADER, collector.hard_rows))
    bytes_sha256(take!(io))
end

function run_pass(packet, label; capture)
    collector = Collector(capture)
    case_rows = Vector{Vector{String}}()
    trace_rows = Vector{Vector{String}}()
    telemetry = Vector{Vector{String}}()
    for ordinal in 1:CASE_COUNT
        timed = @timed run_case!(packet, collector, trace_rows, ordinal)
        push!(case_rows, timed.value)
        maxrss = isdefined(Sys, :maxrss) ? string(Sys.maxrss()) : ""
        push!(telemetry, String[label, string(ordinal),
            string(FRAME_FIRST + ordinal - 1), f64_text(timed.time),
            string(timed.bytes), f64_text(timed.gctime), maxrss])
    end
    digest = science_digest(case_rows, trace_rows, collector)
    states = capture ? take!(collector.state_io) : UInt8[]
    hards = capture ? take!(collector.hard_io) : UInt8[]
    capture && length(states) != collector.state_offset && error("state bytes differ")
    capture && length(hards) != collector.hard_offset && error("hard bytes differ")
    (; case_rows, trace_rows, collector, telemetry, digest, states, hards)
end

function write_results(root, packet, primary, replay, project_root)
    primary.digest == replay.digest || error("scientific replay digest differs")
    primary.case_rows == replay.case_rows || error("case replay differs")
    primary.trace_rows == replay.trace_rows || error("trace replay differs")
    primary.collector.state_rows == replay.collector.state_rows ||
        error("state-index replay differs")
    primary.collector.hard_rows == replay.collector.hard_rows ||
        error("hard-index replay differs")
    write_csv(joinpath(root, "candidate_cases.csv"), CASE_HEADER, primary.case_rows)
    write_csv(joinpath(root, "candidate_trace.csv"), TRACE_HEADER, primary.trace_rows)
    write_csv(joinpath(root, "states_index.csv"), STATE_INDEX_HEADER,
              primary.collector.state_rows)
    write_csv(joinpath(root, "hard_decisions_index.csv"), HARD_INDEX_HEADER,
              primary.collector.hard_rows)
    open(joinpath(root, "states_f64_le.bin"), "w") do io
        write(io, primary.states)
    end
    open(joinpath(root, "hard_decisions_packed.bin"), "w") do io
        write(io, primary.hards)
    end
    telemetry_header = String["pass", "case_ordinal", "frame", "elapsed_seconds",
                              "allocated_bytes", "gc_seconds", "process_maxrss"]
    write_csv(joinpath(root, "telemetry_primary.csv"), telemetry_header,
              primary.telemetry)
    write_csv(joinpath(root, "telemetry_replay.csv"), telemetry_header,
              replay.telemetry)
    write_csv(joinpath(root, "replay_verification.csv"),
              ["field", "primary", "replay", "equal"],
              [["scientific_trace_sha256", primary.digest, replay.digest, "true"]])
    config_rows = Vector{Vector{String}}([
        ["schema", EXECUTION_SCHEMA], ["experiment_id", EXPERIMENT_ID],
        ["case_count", string(CASE_COUNT)], ["frame_first", string(FRAME_FIRST)],
        ["frame_last", string(FRAME_LAST)], ["checkpoints", join(CHECKPOINTS, ';')],
        ["update_cap", string(UPDATE_CAP)],
        ["parity_weight", f64_text(PARITY_WEIGHT)],
        ["step_size", f64_text(STEP_SIZE)],
        ["mapping_tolerance", f64_text(MAPPING_TOLERANCE)],
        ["distance_tolerance", f64_text(DISTANCE_TOLERANCE)],
        ["integrality_tolerance", f64_text(INTEGRALITY_TOLERANCE)],
        ["tie_tolerance", f64_text(TIE_TOLERANCE)],
        ["packet_ready_sha256", packet.packet_ready_sha256],
        ["packet_manifest_sha256", packet.packet_manifest_sha256],
        ["candidate_module_sha256", file_sha256(joinpath(
            project_root, "src", "ConvexParityDistance.jl"))],
        ["candidate_runner_sha256", file_sha256(@__FILE__)],
        ["julia_version", string(VERSION)],
        ["julia_threads", string(Threads.nthreads())],
        ["blas_threads", string(BLAS.get_num_threads())],
        ["truth_used", "false"], ["bp_used", "false"],
    ])
    write_csv(joinpath(root, "candidate_config.csv"), ["field", "value"],
              config_rows)
    members = String[
        "candidate_cases.csv", "candidate_config.csv", "candidate_trace.csv",
        "hard_decisions_index.csv", "hard_decisions_packed.bin",
        "replay_verification.csv", "states_f64_le.bin", "states_index.csv",
        "telemetry_primary.csv", "telemetry_replay.csv",
    ]
    manifest = write_sha_manifest(root, members)
    commit = joinpath(root, "CANDIDATE_COMMITTED.txt")
    write_key_values(commit, Pair{String,String}[
        "schema" => "rq2-convex-parity-distance-001/candidate-commit-v1",
        "experiment_id" => EXPERIMENT_ID, "case_count" => string(CASE_COUNT),
        "manifest_file" => basename(manifest),
        "manifest_sha256" => file_sha256(manifest),
        "packet_ready_sha256" => packet.packet_ready_sha256,
        "packet_manifest_sha256" => packet.packet_manifest_sha256,
        "scientific_trace_sha256" => primary.digest,
        "replay_scientific_trace_sha256" => replay.digest,
        "scientific_replay_equal" => "true",
        "telemetry_excluded_from_scientific_replay" => "true",
        "truth_used" => "false", "bp_used" => "false",
    ])
    (; manifest, commit, digest=primary.digest)
end

function parse_cli(args)
    options = Dict{String,String}()
    index = 1
    while index <= length(args)
        option = args[index]
        option in ("--packet-root", "--output-root") ||
            throw(ArgumentError("unknown option: $option"))
        index < length(args) || throw(ArgumentError("$option needs a value"))
        options[option] = args[index + 1]
        index += 2
    end
    for required in ("--packet-root", "--output-root")
        haskey(options, required) || throw(ArgumentError("$required is required"))
    end
    options
end

function main(args=ARGS)
    options = parse_cli(args)
    Threads.nthreads() == 1 || error("candidate run requires one Julia thread")
    BLAS.set_num_threads(1)
    packet = load_packet(abspath(options["--packet-root"]))
    output = require_empty_directory(options["--output-root"])
    primary = run_pass(packet, "primary"; capture=true)
    replay = run_pass(packet, "replay"; capture=false)
    result = write_results(output, packet, primary, replay,
                           normpath(joinpath(@__DIR__, "..")))
    println("CANDIDATE_COMMITTED manifest_sha256=", file_sha256(result.manifest),
            " scientific_trace_sha256=", result.digest)
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2ConvexParityDistanceCandidateRunner.main()
end
