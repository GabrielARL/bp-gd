#!/usr/bin/env julia

module RQ2ConvexParityDistanceSNRThresholdCandidate

import ConvexParityDistance
import ConvexParityDistanceAccelerated
using LinearAlgebra

const CPD = ConvexParityDistance
const Accelerated = ConvexParityDistanceAccelerated

include(joinpath(@__DIR__, "..", "..", "convex_parity_distance",
                 "execution", "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO
include(joinpath(@__DIR__, "activation_gate.jl"))
using .RQ2ConvexParityDistanceSNRThresholdActivationGate

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001"
const PACKET_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-packet-v1"
const EXECUTION_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-execution-v1"
const SCIENCE_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/scientific-trace-v1"
const COMMIT_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-commit-v1"
const REGISTERED_GRAPH_SHA256 =
    "94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d"
const OBJECTIVE_SOURCE_SHA256 =
    "5df9ae2489356a8d9e0f38efe5453713fec3130dfb68f8a14119638357b251f3"
const ACCELERATED_SOURCE_SHA256 =
    "3eb0f8b85ba12a418fda9484cd658c43748a5bfc1db1dc92f9cc58b6f1edb5fc"
const UPDATE_CAP = 30
const N = 10_200
const M = 5_100
const E = 30_600

const PACKET_MEMBERS = String[
    "case_index.csv",
    "checks_i32_6_by_m.bin",
    "llr_f64_n_by_case.bin",
    "packet_config.csv",
    "snr_grid.csv",
]

const CASE_HEADER = String[
    "case_ordinal", "stage", "snr_db", "frame", "noise_seed",
    "llr_sha256", "initial_state_sha256", "first_valid_update",
    "latched_hard_sha256", "terminal_update", "terminal_state_sha256",
    "terminal_hard_sha256", "terminal_syndrome_weight",
    "terminal_tie_count", "terminal_parity_valid", "terminal_objective",
    "terminal_normalized_objective", "terminal_signal_term",
    "terminal_normalized_signal_term", "terminal_parity_term",
    "terminal_normalized_parity_term", "terminal_squared_distance_sum",
    "terminal_maximum_check_distance", "terminal_nonzero_distance_checks",
    "terminal_distance_above_1e_10_checks", "terminal_mapping_norm_inf",
    "per_update_scientific_trace_sha256",
]

const TRACE_HEADER = String[
    "case_ordinal", "stage", "snr_db", "frame", "update",
    "objective", "normalized_objective", "query_mapping_norm_inf",
    "gradient_weight", "coupling_weight", "output_displacement_inf",
    "query_minimum", "query_maximum", "output_minimum", "output_maximum",
    "mirror_minimum", "mirror_maximum", "state_sha256", "hard_sha256",
    "syndrome_weight", "tie_count", "parity_valid", "latch_event",
    "first_valid_update",
]

const STATE_INDEX_HEADER = String[
    "case_ordinal", "stage", "snr_db", "frame", "role", "update",
    "byte_offset", "byte_count", "coordinate_count", "state_sha256",
]

const HARD_INDEX_HEADER = String[
    "case_ordinal", "stage", "snr_db", "frame", "role", "update",
    "byte_offset", "byte_count", "bit_count", "hard_sha256",
    "packed_sha256", "syndrome_weight", "tie_count", "parity_valid",
]

struct CandidatePacket
    stage::String
    activation_sha256::String
    checks::Vector{Vector{Int}}
    llrs::Matrix{Float64}
    case_rows::Vector{Dict{String,String}}
    packet_ready_sha256::String
    packet_manifest_sha256::String
    graph_binary_sha256::String
    llr_binary_sha256::String
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

Collector(capture::Bool) = Collector(
    capture, IOBuffer(), IOBuffer(), 0, 0,
    Vector{Vector{String}}(), Vector{Vector{String}}())

function _required_subset(values, required, label)
    missing = setdiff(Set(required), Set(keys(values)))
    isempty(missing) || error("$label is missing fields: $(join(sort!(collect(missing)), ','))")
end

function _reject_sensitive_extra_fields(values, allowed, label)
    for key in setdiff(Set(keys(values)), Set(allowed))
        lowered = lowercase(key)
        any(token -> occursin(token, lowered),
            ("truth", "transmitted", "comparison_decoder", "bp_")) &&
            error("$label contains a forbidden candidate field: $key")
    end
end

function graph_identity(checks)
    io = IOBuffer()
    for check in checks
        write(io, htol(Int32(length(check))))
        for bit in check
            write(io, htol(Int32(bit)))
        end
    end
    bytes_sha256(take!(io))
end

function _read_i32_little_endian(path, count)
    filesize(path) == sizeof(Int32) * count ||
        throw(DimensionMismatch("graph binary byte count differs"))
    raw = Vector{Int32}(undef, count)
    open(path, "r") do io
        read!(io, raw)
        eof(io) || error("graph binary has trailing bytes")
    end
    ltoh.(raw)
end

function _read_f64_little_endian(path, count)
    filesize(path) == sizeof(Float64) * count ||
        throw(DimensionMismatch("LLR binary byte count differs"))
    raw = Vector{UInt64}(undef, count)
    open(path, "r") do io
        read!(io, raw)
        eof(io) || error("LLR binary has trailing bytes")
    end
    [reinterpret(Float64, ltoh(bits)) for bits in raw]
end

function _float64_little_endian_bytes(values)
    io = IOBuffer()
    for value in values
        write(io, htol(reinterpret(UInt64, Float64(value))))
    end
    take!(io)
end

function _read_graph(path, expected_binary_sha256)
    file_sha256(path) == expected_binary_sha256 ||
        error("packet graph binary hash differs")
    raw = _read_i32_little_endian(path, CPD.CHECK_DEGREE * M)
    matrix = reshape(raw, CPD.CHECK_DEGREE, M)
    checks = [Int.(matrix[:, check]) for check in 1:M]
    degrees = zeros(Int, N)
    for check in checks
        length(unique(check)) == CPD.CHECK_DEGREE ||
            error("packet graph repeats a bit within one check")
        for bit in check
            1 <= bit <= N || error("packet graph bit index is out of range")
            degrees[bit] += 1
        end
    end
    all(==(CPD.VARIABLE_DEGREE), degrees) ||
        error("packet graph variable degree differs")
    graph_identity(checks) == REGISTERED_GRAPH_SHA256 ||
        error("packet graph scientific identity differs")
    checks
end

function _validate_snr_grid(path, cases, activation::StageActivation)
    grid = read_csv(path)
    grid.header == ["snr_ordinal", "physical_esn0_db"] ||
        error("SNR-grid header differs")
    isempty(grid.rows) && error("SNR grid is empty")
    levels = Float64[]
    for (ordinal, row) in enumerate(grid.rows)
        parse(Int, row["snr_ordinal"]) == ordinal ||
            error("SNR-grid ordinal differs")
        value = parse(Float64, row["physical_esn0_db"])
        isfinite(value) || error("SNR-grid value is not finite")
        push!(levels, value)
    end
    issorted(levels) && allunique(levels) ||
        error("SNR grid must be strictly increasing")
    seen = unique(parse(Float64, row["physical_esn0_db"]) for row in cases)
    seen == levels || error("case-index SNR levels differ from SNR grid")
    tolerance = activation.stage == "fine" ? 2.0e-12 : 0.0
    length(levels) == length(activation.snrs) && all(
        isapprox(levels[index], activation.snrs[index]; atol=tolerance, rtol=0.0)
        for index in eachindex(levels)) ||
        error("packet SNR grid differs from the stage activation")
    levels
end

function load_packet(root::String, activation::StageActivation)
    ready_path = joinpath(root, "PACKET_READY.txt")
    isfile(ready_path) || error("candidate packet is not ready")
    ready = read_key_values(ready_path)
    required_ready = String[
        "schema", "experiment_id", "stage", "case_count", "manifest_file",
        "manifest_sha256", "activation_sha256", "truth_fields_present",
        "comparison_decoder_fields_present",
    ]
    _required_subset(ready, required_ready, "packet-ready record")
    _reject_sensitive_extra_fields(ready, required_ready, "packet-ready record")
    ready["schema"] == PACKET_SCHEMA || error("packet schema differs")
    ready["experiment_id"] == EXPERIMENT_ID || error("packet experiment differs")
    stage = ready["stage"]
    stage in ("coarse", "fine") || error("packet stage differs")
    stage == activation.stage || error("packet stage differs from activation")
    ready["activation_sha256"] == activation.sha256 ||
        error("packet activation hash differs")
    ready["truth_fields_present"] == "false" ||
        error("candidate packet exposes prohibited fields")
    ready["comparison_decoder_fields_present"] == "false" ||
        error("candidate packet exposes prohibited comparator fields")
    manifest_name = ready["manifest_file"]
    normpath(manifest_name) == manifest_name && !isabspath(manifest_name) ||
        error("packet manifest name is not canonical")
    manifest_path = joinpath(root, manifest_name)
    file_sha256(manifest_path) == ready["manifest_sha256"] ||
        error("packet manifest hash differs")
    verify_sha_manifest(root, manifest_name; expected_members=PACKET_MEMBERS)
    Set(readdir(root)) == Set(vcat(PACKET_MEMBERS,
                                   [manifest_name, "PACKET_READY.txt"])) ||
        error("packet directory contains an unregistered member")

    config_table = read_csv(joinpath(root, "packet_config.csv"))
    config_table.header == ["field", "value"] ||
        error("packet-config header differs")
    config = Dict(row["field"] => row["value"] for row in config_table.rows)
    required_config = String[
        "schema", "experiment_id", "stage", "case_count", "frame_first",
        "frame_last", "n", "m", "edge_count", "check_degree",
        "variable_degree", "graph_binary_sha256", "graph_scientific_sha256",
        "llr_binary_sha256", "llr_encoding", "snr_count",
        "activation_sha256",
        "truth_fields_present", "comparison_decoder_fields_present",
    ]
    _required_subset(config, required_config, "packet config")
    _reject_sensitive_extra_fields(config, required_config, "packet config")
    config["schema"] == PACKET_SCHEMA || error("packet-config schema differs")
    config["experiment_id"] == EXPERIMENT_ID ||
        error("packet-config experiment differs")
    config["stage"] == stage || error("packet stages disagree")
    config["activation_sha256"] == activation.sha256 ||
        error("packet-config activation hash differs")
    config["truth_fields_present"] == "false" ||
        error("packet config exposes prohibited fields")
    config["comparison_decoder_fields_present"] == "false" ||
        error("packet config exposes prohibited comparator fields")
    parse(Int, config["n"]) == N || error("packet block length differs")
    parse(Int, config["m"]) == M || error("packet check count differs")
    parse(Int, config["edge_count"]) == E || error("packet edge count differs")
    parse(Int, config["check_degree"]) == CPD.CHECK_DEGREE ||
        error("packet check degree differs")
    parse(Int, config["variable_degree"]) == CPD.VARIABLE_DEGREE ||
        error("packet variable degree differs")
    config["graph_scientific_sha256"] == REGISTERED_GRAPH_SHA256 ||
        error("packet registered graph hash differs")
    encoding = lowercase(config["llr_encoding"])
    all(token -> occursin(token, encoding), ("float64", "little", "column")) ||
        error("packet LLR encoding differs")

    case_count = parse(Int, ready["case_count"])
    case_count == parse(Int, config["case_count"]) ||
        error("packet case counts disagree")
    case_count > 0 || error("packet has no cases")
    frame_first = parse(Int, config["frame_first"])
    frame_last = parse(Int, config["frame_last"])
    expected_frames = (activation.frame_first, activation.frame_last)
    (frame_first, frame_last) == expected_frames ||
        error("packet frame range differs from the registered stage")
    frame_count = frame_last - frame_first + 1
    case_count == frame_count * length(activation.snrs) ||
        error("packet does not contain every activated SNR/frame case")
    parse(Int, config["snr_count"]) == length(activation.snrs) ||
        error("packet SNR count differs")

    checks = _read_graph(joinpath(root, "checks_i32_6_by_m.bin"),
                         config["graph_binary_sha256"])
    llr_path = joinpath(root, "llr_f64_n_by_case.bin")
    file_sha256(llr_path) == config["llr_binary_sha256"] ||
        error("packet LLR binary hash differs")
    llrs = reshape(_read_f64_little_endian(llr_path, N * case_count),
                   N, case_count)

    index = read_csv(joinpath(root, "case_index.csv"))
    index.header == ["case_ordinal", "frame", "physical_esn0_db",
                     "noise_seed", "graph_sha256", "clipped_llr_sha256"] ||
        error("case-index header differs")
    length(index.rows) == case_count || error("case-index count differs")
    cases = sort(index.rows; by=row -> parse(Int, row["case_ordinal"]))
    levels = _validate_snr_grid(joinpath(root, "snr_grid.csv"), cases, activation)
    expected_cases = [(snr, frame) for snr in levels
                      for frame in frame_first:frame_last]
    for (ordinal, row) in enumerate(cases)
        parse(Int, row["case_ordinal"]) == ordinal ||
            error("case ordinal differs")
        expected_frame = frame_first + (ordinal - 1) % frame_count
        parse(Int, row["frame"]) == expected_frame ||
            error("case frame ordering differs")
        parse(Int, row["noise_seed"]) == 20_261_012 + expected_frame ||
            error("case noise seed differs")
        row["graph_sha256"] == REGISTERED_GRAPH_SHA256 ||
            error("case graph hash differs")
        llr = view(llrs, :, ordinal)
        all(value -> isfinite(value) && -20.0 <= value <= 20.0, llr) ||
            error("case LLR vector is invalid")
        CPD.vector_sha256(llr) == row["clipped_llr_sha256"] ||
            error("case LLR hash differs")
        actual_pair = (parse(Float64, row["physical_esn0_db"]),
                       parse(Int, row["frame"]))
        actual_pair == expected_cases[ordinal] ||
            error("case SNR/frame blocks differ from the activation")
    end

    CandidatePacket(stage, activation.sha256, checks, llrs, cases,
                    file_sha256(ready_path),
                    ready["manifest_sha256"], config["graph_binary_sha256"],
                    config["llr_binary_sha256"])
end

function _validate_box_state!(values, label, ordinal, update)
    for value in values
        isfinite(value) || error("$label is nonfinite at case $ordinal update $update")
        0.0 <= value <= 1.0 ||
            error("$label left the box at case $ordinal update $update")
    end
    nothing
end

function _validate_accelerated_state!(workspace, state, summary, ordinal, update)
    summary.iteration == update || error("accelerated iteration differs")
    workspace.iteration == update || error("accelerated workspace iteration differs")
    for value in (summary.objective_at_query,
                  summary.normalized_objective_at_query,
                  summary.gradient_weight, summary.coupling_weight,
                  summary.query_mapping_inf, summary.output_displacement_inf,
                  summary.query_minimum, summary.query_maximum,
                  summary.output_minimum, summary.output_maximum,
                  summary.mirror_minimum, summary.mirror_maximum)
        isfinite(value) || error("accelerated diagnostic is nonfinite")
    end
    _validate_box_state!(state, "candidate output", ordinal, update)
    _validate_box_state!(workspace.query, "candidate query", ordinal, update)
    _validate_box_state!(workspace.output, "candidate output history", ordinal, update)
    _validate_box_state!(workspace.mirror, "candidate mirror", ordinal, update)
    nothing
end

function _capture_state!(collector, ordinal, stage, snr, frame, update, state)
    bytes = _float64_little_endian_bytes(state)
    digest = CPD.vector_sha256(state)
    collector.capture && write(collector.state_io, bytes)
    push!(collector.state_rows, String[
        string(ordinal), stage, snr, string(frame), "terminal", string(update),
        string(collector.state_offset), string(length(bytes)), string(length(state)),
        digest,
    ])
    collector.state_offset += length(bytes)
    digest
end

function _capture_hard!(collector, ordinal, stage, snr, frame, role, update,
                        hard, readout)
    packed = pack_bits(hard)
    digest = CPD.vector_sha256(hard)
    collector.capture && write(collector.hard_io, packed)
    push!(collector.hard_rows, String[
        string(ordinal), stage, snr, string(frame), role, string(update),
        string(collector.hard_offset), string(length(packed)), string(length(hard)),
        digest, bytes_sha256(packed), string(readout.syndrome_weight),
        string(readout.tie_count), bool_text(readout.parity_valid),
    ])
    collector.hard_offset += length(packed)
    digest
end

function _trace_row(ordinal, stage, snr, frame, update, summary, state_hash,
                    hard_hash, readout, latch_event, first_valid)
    String[
        string(ordinal), stage, snr, string(frame), string(update),
        f64_text(summary.objective_at_query),
        f64_text(summary.normalized_objective_at_query),
        f64_text(summary.query_mapping_inf), f64_text(summary.gradient_weight),
        f64_text(summary.coupling_weight),
        f64_text(summary.output_displacement_inf),
        f64_text(summary.query_minimum), f64_text(summary.query_maximum),
        f64_text(summary.output_minimum), f64_text(summary.output_maximum),
        f64_text(summary.mirror_minimum), f64_text(summary.mirror_maximum),
        state_hash, hard_hash, string(readout.syndrome_weight),
        string(readout.tie_count), bool_text(readout.parity_valid),
        bool_text(latch_event), first_valid == 0 ? "" : string(first_valid),
    ]
end

function run_case!(packet::CandidatePacket, collector::Collector,
                   trace_rows::Vector{Vector{String}}, ordinal::Int)
    metadata = packet.case_rows[ordinal]
    stage = packet.stage
    snr = f64_text(parse(Float64, metadata["physical_esn0_db"]))
    frame = parse(Int, metadata["frame"])
    noise_seed = parse(Int, metadata["noise_seed"])
    llr = copy(view(packet.llrs, :, ordinal))
    llr_hash = CPD.vector_sha256(llr)
    llr_hash == metadata["clipped_llr_sha256"] ||
        error("candidate LLR hash differs from packet")
    problem = CPD.Problem(packet.checks, llr)
    state = Accelerated.initialize_state(problem)
    _validate_box_state!(state, "candidate initialization", ordinal, 0)
    initial_hash = CPD.vector_sha256(state)
    workspace = Accelerated.AcceleratedWorkspace(problem)
    first_valid = 0
    latched_hash = ""
    local_trace = Vector{Vector{String}}()

    for update in 1:UPDATE_CAP
        summary = Accelerated.accelerated_step!(workspace, problem, state)
        _validate_accelerated_state!(workspace, state, summary, ordinal, update)
        readout = Accelerated.readout!(workspace, problem, state)
        hard = copy(workspace.checkpoint.hard)
        state_hash = CPD.vector_sha256(state)
        hard_hash = CPD.vector_sha256(hard)
        latch_event = false
        if first_valid == 0 && readout.parity_valid
            readout.tie_count == 0 || error("parity-valid latch contains a tie")
            first_valid = update
            latch_event = true
            latched_hash = _capture_hard!(
                collector, ordinal, stage, snr, frame, "latched", update,
                hard, readout)
            latched_hash == hard_hash || error("latched hard hash differs")
        end
        row = _trace_row(ordinal, stage, snr, frame, update, summary,
                         state_hash, hard_hash, readout, latch_event, first_valid)
        push!(local_trace, row)
        push!(trace_rows, row)
    end

    workspace.iteration == UPDATE_CAP || error("candidate did not execute 30 updates")
    terminal_readout = Accelerated.readout!(workspace, problem, state)
    terminal_hard = copy(workspace.checkpoint.hard)
    terminal = Accelerated.checkpoint_evaluate!(
        workspace, problem, state; capture_hash=true)
    all(value -> isfinite(value),
        (terminal.value, terminal.normalized_value, terminal.signal,
         terminal.normalized_signal, terminal.parity, terminal.normalized_parity,
         terminal.squared_distance_sum, terminal.maximum_check_distance,
         terminal.mapping_norm_inf)) || error("terminal diagnostic is nonfinite")
    terminal_state_hash = _capture_state!(
        collector, ordinal, stage, snr, frame, UPDATE_CAP, state)
    terminal_state_hash == terminal.state_sha256 ||
        error("terminal state hash differs")
    terminal_hard_hash = _capture_hard!(
        collector, ordinal, stage, snr, frame, "terminal", UPDATE_CAP,
        terminal_hard, terminal_readout)
    local_digest = bytes_sha256(csv_bytes(TRACE_HEADER, local_trace))

    String[
        string(ordinal), stage, snr, string(frame), string(noise_seed), llr_hash,
        initial_hash, first_valid == 0 ? "" : string(first_valid), latched_hash,
        string(UPDATE_CAP), terminal_state_hash, terminal_hard_hash,
        string(terminal_readout.syndrome_weight),
        string(terminal_readout.tie_count),
        bool_text(terminal_readout.parity_valid), f64_text(terminal.value),
        f64_text(terminal.normalized_value), f64_text(terminal.signal),
        f64_text(terminal.normalized_signal), f64_text(terminal.parity),
        f64_text(terminal.normalized_parity),
        f64_text(terminal.squared_distance_sum),
        f64_text(terminal.maximum_check_distance),
        string(terminal.infeasible_checks),
        string(terminal.checks_above_distance_tolerance),
        f64_text(terminal.mapping_norm_inf), local_digest,
    ]
end

function science_digest(case_rows, trace_rows, collector, states, hards)
    io = IOBuffer()
    write(io, codeunits(SCIENCE_SCHEMA),
          csv_bytes(CASE_HEADER, case_rows),
          csv_bytes(TRACE_HEADER, trace_rows),
          csv_bytes(STATE_INDEX_HEADER, collector.state_rows),
          csv_bytes(HARD_INDEX_HEADER, collector.hard_rows), states, hards)
    bytes_sha256(take!(io))
end

function _verify_activation_binding(packet::CandidatePacket,
                                    activation::StageActivation)
    packet.stage == activation.stage || error(
        "candidate packet stage differs from the verified activation")
    packet.activation_sha256 == activation.sha256 || error(
        "candidate packet hash differs from the verified activation")
    activation.update_cap == UPDATE_CAP || error(
        "candidate activation update cap differs")
    true
end

function run_pass(packet::CandidatePacket, activation::StageActivation,
                  label::String; capture::Bool)
    _verify_activation_binding(packet, activation)
    collector = Collector(capture)
    case_rows = Vector{Vector{String}}()
    trace_rows = Vector{Vector{String}}()
    telemetry = Vector{NamedTuple}()
    for ordinal in eachindex(packet.case_rows)
        timed = @timed run_case!(packet, collector, trace_rows, ordinal)
        push!(case_rows, timed.value)
        maxrss = isdefined(Sys, :maxrss) ? Int(Sys.maxrss()) : -1
        push!(telemetry, (;
            label, ordinal,
            runtime_ns=round(Int, timed.time * 1.0e9),
            allocated_bytes=Int(timed.bytes),
            gc_runtime_ns=round(Int, timed.gctime * 1.0e9),
            process_maxrss=maxrss))
    end
    states = capture ? take!(collector.state_io) : UInt8[]
    hards = capture ? take!(collector.hard_io) : UInt8[]
    capture && length(states) != collector.state_offset &&
        error("captured state byte count differs")
    capture && length(hards) != collector.hard_offset &&
        error("captured hard-decision byte count differs")
    digest = science_digest(case_rows, trace_rows, collector, states, hards)
    (; case_rows, trace_rows, collector, telemetry, digest, states, hards)
end

function _telemetry_rows(packet, primary, replay)
    length(primary.telemetry) == length(replay.telemetry) ||
        error("telemetry case counts differ")
    rows = Vector{Vector{String}}()
    for ordinal in eachindex(primary.telemetry)
        first = primary.telemetry[ordinal]
        second = replay.telemetry[ordinal]
        metadata = packet.case_rows[ordinal]
        push!(rows, String[
            string(ordinal), packet.stage,
            f64_text(parse(Float64, metadata["physical_esn0_db"])),
            metadata["frame"], string(first.runtime_ns),
            string(second.runtime_ns), string(first.allocated_bytes),
            string(second.allocated_bytes), string(first.gc_runtime_ns),
            string(second.gc_runtime_ns), string(first.process_maxrss),
            string(second.process_maxrss),
        ])
    end
    rows
end

function _verify_replay(primary, replay)
    primary.digest == replay.digest || error("scientific replay digest differs")
    primary.case_rows == replay.case_rows || error("candidate-case replay differs")
    primary.trace_rows == replay.trace_rows || error("candidate-trace replay differs")
    primary.collector.state_rows == replay.collector.state_rows ||
        error("terminal-state replay differs")
    primary.collector.hard_rows == replay.collector.hard_rows ||
        error("hard-decision replay differs")
    primary.states == replay.states || error("terminal-state bytes replay differs")
    primary.hards == replay.hards || error("hard-decision bytes replay differs")
    true
end

function write_results(root, packet, primary, replay)
    _verify_replay(primary, replay)
    write_csv(joinpath(root, "candidate_cases.csv"), CASE_HEADER,
              primary.case_rows)
    write_csv(joinpath(root, "candidate_trace.csv"), TRACE_HEADER,
              primary.trace_rows)
    write_csv(joinpath(root, "final_states_index.csv"), STATE_INDEX_HEADER,
              primary.collector.state_rows)
    open(joinpath(root, "final_states_f64_le.bin"), "w") do io
        write(io, primary.states)
    end
    write_csv(joinpath(root, "hard_decisions_index.csv"), HARD_INDEX_HEADER,
              primary.collector.hard_rows)
    open(joinpath(root, "hard_decisions_packed.bin"), "w") do io
        write(io, primary.hards)
    end
    write_csv(joinpath(root, "candidate_telemetry.csv"), String[
        "case_ordinal", "stage", "snr_db", "frame", "primary_runtime_ns",
        "replay_runtime_ns", "primary_allocated_bytes",
        "replay_allocated_bytes", "primary_gc_runtime_ns",
        "replay_gc_runtime_ns", "primary_process_maxrss",
        "replay_process_maxrss",
    ], _telemetry_rows(packet, primary, replay))
    write_csv(joinpath(root, "replay_verification.csv"),
              ["field", "primary", "replay", "equal"],
              [["scientific_trace_sha256", primary.digest, replay.digest,
                "true"]])
    objective_source = pathof(CPD)
    accelerated_source = pathof(Accelerated)
    file_sha256(objective_source) == OBJECTIVE_SOURCE_SHA256 ||
        error("frozen objective source hash differs")
    file_sha256(accelerated_source) == ACCELERATED_SOURCE_SHA256 ||
        error("frozen accelerated source hash differs")
    config_rows = Vector{Vector{String}}([
        ["schema", EXECUTION_SCHEMA], ["experiment_id", EXPERIMENT_ID],
        ["stage", packet.stage], ["case_count", string(length(packet.case_rows))],
        ["activation_sha256", packet.activation_sha256],
        ["update_cap", string(UPDATE_CAP)],
        ["parity_weight", f64_text(CPD.PARITY_WEIGHT)],
        ["global_curvature", f64_text(Accelerated.GLOBAL_CURVATURE)],
        ["tie_tolerance", f64_text(CPD.TIE_TOLERANCE)],
        ["distance_tolerance", f64_text(CPD.DISTANCE_TOLERANCE)],
        ["registered_graph_sha256", REGISTERED_GRAPH_SHA256],
        ["graph_binary_sha256", packet.graph_binary_sha256],
        ["llr_binary_sha256", packet.llr_binary_sha256],
        ["packet_ready_sha256", packet.packet_ready_sha256],
        ["packet_manifest_sha256", packet.packet_manifest_sha256],
        ["objective_source_sha256", file_sha256(objective_source)],
        ["accelerated_source_sha256", file_sha256(accelerated_source)],
        ["candidate_runner_sha256", file_sha256(@__FILE__)],
        ["julia_version", string(VERSION)],
        ["julia_threads", string(Threads.nthreads())],
        ["blas_threads", string(BLAS.get_num_threads())],
        ["truth_used", "false"], ["bp_used", "false"],
        ["telemetry_in_scientific_digest", "false"],
    ])
    write_csv(joinpath(root, "candidate_config.csv"), ["field", "value"],
              config_rows)

    members = String[
        "candidate_cases.csv", "candidate_config.csv", "candidate_telemetry.csv",
        "candidate_trace.csv", "final_states_f64_le.bin",
        "final_states_index.csv", "hard_decisions_index.csv",
        "hard_decisions_packed.bin", "replay_verification.csv",
    ]
    manifest = write_sha_manifest(root, members)
    commit = joinpath(root, "CANDIDATE_COMMITTED.txt")
    write_key_values(commit, Pair{String,String}[
        "schema" => COMMIT_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "stage" => packet.stage,
        "activation_sha256" => packet.activation_sha256,
        "case_count" => string(length(packet.case_rows)),
        "manifest_file" => basename(manifest),
        "manifest_sha256" => file_sha256(manifest),
        "packet_ready_sha256" => packet.packet_ready_sha256,
        "packet_manifest_sha256" => packet.packet_manifest_sha256,
        "scientific_trace_sha256" => primary.digest,
        "replay_scientific_trace_sha256" => replay.digest,
        "scientific_replay_equal" => "true",
        "telemetry_excluded_from_scientific_replay" => "true",
        "candidate_outcome_committed" => "true",
        "truth_used" => "false",
        "bp_used" => "false",
    ])
    (; manifest, commit, digest=primary.digest)
end

function parse_cli(args)
    options = Dict{String,String}()
    index = 1
    while index <= length(args)
        option = args[index]
        option in ("--activation", "--packet-root", "--output-root") ||
            throw(ArgumentError("unknown option: $option"))
        index < length(args) || throw(ArgumentError("$option needs a value"))
        haskey(options, option) && throw(ArgumentError("option is repeated: $option"))
        options[option] = args[index + 1]
        index += 2
    end
    for required in ("--activation", "--packet-root", "--output-root")
        haskey(options, required) || throw(ArgumentError("$required is required"))
    end
    options
end

function execute_candidate(activation_path::String, packet_root::String,
                           output_root::String;
        _activation_sources::ActivationSourcePaths=default_source_paths(),
        _packet_loader::Function=load_packet,
        _pass_runner::Function=run_pass)
    activation = verify_activation(
        activation_path; sources=_activation_sources)
    packet = _packet_loader(packet_root, activation)
    output = require_empty_directory(output_root)
    primary = _pass_runner(packet, activation, "primary"; capture=true)
    replay = _pass_runner(packet, activation, "replay"; capture=true)
    write_results(output, packet, primary, replay)
end

function main(args=ARGS)
    options = parse_cli(args)
    Threads.nthreads() == 1 || error("candidate execution requires one Julia thread")
    BLAS.set_num_threads(1)
    result = execute_candidate(
        abspath(options["--activation"]), abspath(options["--packet-root"]),
        abspath(options["--output-root"]))
    println("CANDIDATE_COMMITTED manifest_sha256=",
            file_sha256(result.manifest), " scientific_trace_sha256=",
            result.digest)
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2ConvexParityDistanceSNRThresholdCandidate.main()
end
