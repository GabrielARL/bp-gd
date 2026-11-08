#!/usr/bin/env julia

module RQ2ConvexParityDistanceSNRThresholdScorer

using ConvexParityDistance
using SHA
using Statistics
using TOML

include(joinpath(@__DIR__, "..", "..", "convex_parity_distance",
                 "execution", "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO
include(joinpath(@__DIR__, "activation_gate.jl"))
using .RQ2ConvexParityDistanceSNRThresholdActivationGate:
    StageActivation, verify_activation

export score, run_cli, summarize_snr,
       score_with_backend_for_synthetic_test

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001"
const SCORE_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/post-commit-score-v1"
const PACKET_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-packet-v1"
const COMMIT_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-commit-v1"
const SCIENCE_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/scientific-trace-v1"
const ADAPTER_PATH =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments/rq2_native_gap_001/rq2_native_gap_001.jl"
const ADAPTER_CONFIG_PATH =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments/rq2_native_gap_001/config.toml"
const ADAPTER_SHA256 =
    "5ce7ba12efe06b4e9a4d5b31401064128b5b95e12fe38a990e24bf228a368ec8"
const ADAPTER_CONFIG_SHA256 =
    "7730e668a4dc48bbf8afb8a5ed1ba365ae4b4bfb7f5306be86a795eb203286b9"
const RETAINED_SPLIT_CONFIG_PATH =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments/rq2_native_gap_001/results/2026-10-31_profile_v2/source/retained/split_config.toml"
const ARCHIVED_GENERATOR_PATH =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments/rq2_gd_state_use_001/rq2_gd_state_use_001.jl"
const ARCHIVED_GENERATOR_SHA256 =
    "6c09396c7f394ad2c45ae4ee0b22d8b556c384784e2ce21fcea0ce3632009f7d"
const JADE_ROOT =
    "/home/gabiel/Documents/GitHub/JadeJcade-worktrees/awgn-jade-coral-20261012"
const REGISTERED_GRAPH_SHA256 =
    "94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d"
const REGISTERED_N = 10_200
const REGISTERED_M = 5_100
const UPDATE_CAP = 30
const EXECUTION_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-execution-v1"
const OBJECTIVE_SOURCE_SHA256 =
    "5df9ae2489356a8d9e0f38efe5453713fec3130dfb68f8a14119638357b251f3"
const ACCELERATED_SOURCE_SHA256 =
    "3eb0f8b85ba12a418fda9484cd658c43748a5bfc1db1dc92f9cc58b6f1edb5fc"

const PACKET_MEMBERS = String[
    "case_index.csv", "checks_i32_6_by_m.bin", "llr_f64_n_by_case.bin",
    "packet_config.csv", "snr_grid.csv",
]
const CANDIDATE_MEMBERS = String[
    "candidate_cases.csv", "candidate_config.csv", "candidate_telemetry.csv",
    "candidate_trace.csv", "final_states_f64_le.bin",
    "final_states_index.csv", "hard_decisions_index.csv",
    "hard_decisions_packed.bin", "replay_verification.csv",
]
const PACKET_MANIFEST = "PACKET_MANIFEST.sha256"
const CANDIDATE_MANIFEST = "CANDIDATE_MANIFEST.sha256"

const PACKET_MARKER_FIELDS = String[
    "schema", "experiment_id", "stage", "case_count", "manifest_file",
    "manifest_sha256", "activation_sha256", "truth_fields_present",
    "comparison_decoder_fields_present",
]
const CANDIDATE_MARKER_FIELDS = String[
    "schema", "experiment_id", "stage", "case_count", "manifest_file",
    "manifest_sha256", "activation_sha256", "packet_ready_sha256",
    "packet_manifest_sha256",
    "scientific_trace_sha256", "replay_scientific_trace_sha256",
    "scientific_replay_equal", "telemetry_excluded_from_scientific_replay",
    "candidate_outcome_committed", "truth_used", "bp_used",
]

const PACKET_CONFIG_FIELDS = String[
    "schema", "experiment_id", "stage", "activation_sha256", "case_order",
    "case_count", "snr_count", "frame_first", "frame_last", "n", "m",
    "edge_count", "check_degree", "variable_degree", "graph_binary_sha256",
    "graph_scientific_sha256", "llr_binary_sha256", "llr_encoding",
    "adapter_sha256", "archived_generator_sha256", "archived_config_sha256",
    "retained_split_config_sha256", "unit_noise_reused_by_frame_across_snr",
    "truth_fields_present", "comparison_decoder_fields_present",
]
const CANDIDATE_CONFIG_FIELDS = String[
    "schema", "experiment_id", "stage", "case_count", "activation_sha256",
    "update_cap", "parity_weight", "global_curvature", "tie_tolerance",
    "distance_tolerance", "registered_graph_sha256", "graph_binary_sha256",
    "llr_binary_sha256", "packet_ready_sha256", "packet_manifest_sha256",
    "objective_source_sha256", "accelerated_source_sha256",
    "candidate_runner_sha256", "julia_version", "julia_threads",
    "blas_threads", "truth_used", "bp_used", "telemetry_in_scientific_digest",
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

struct Packet
    stage::String
    activation_sha256::String
    n::Int
    m::Int
    checks::Vector{Vector{Int}}
    llrs::Matrix{Float64}
    cases::Vector{Dict{String,String}}
    snrs::Vector{Float64}
    ready_sha256::String
    manifest_sha256::String
    graph_sha256::String
    graph_binary_sha256::String
    llr_binary_sha256::String
    config::Dict{String,String}
end

_parse_bool(text::AbstractString) = text == "true" ? true :
    text == "false" ? false : throw(ArgumentError("invalid Boolean: $text"))

function _required(mapping, keys, label)
    missing = setdiff(Set(String.(keys)), Set(String.(Base.keys(mapping))))
    isempty(missing) || throw(ArgumentError(
        "$label is missing fields: $(join(sort!(collect(missing)), ", "))"))
    mapping
end

function _exact_keys(mapping, expected, label)
    actual = Set(String.(Base.keys(mapping)))
    wanted = Set(String.(expected))
    missing = sort!(collect(setdiff(wanted, actual)))
    extra = sort!(collect(setdiff(actual, wanted)))
    isempty(missing) || throw(ArgumentError(
        "$label is missing fields: $(join(missing, ", "))"))
    isempty(extra) || throw(ArgumentError(
        "$label has unregistered fields: $(join(extra, ", "))"))
    mapping
end

function _manifest_members(path::String)
    members = String[]
    for line in eachline(path)
        isempty(line) && continue
        pieces = split(line, "  "; limit=2)
        length(pieces) == 2 || throw(ArgumentError("malformed SHA manifest"))
        push!(members, pieces[2])
    end
    Set(members)
end

function _validate_directory_members(root::String, scientific_members,
                                     manifest_name::String, marker_name::String,
                                     label::String)
    expected = Set(vcat(scientific_members, [manifest_name, marker_name]))
    actual = Set(readdir(root))
    actual == expected || throw(ArgumentError(
        "$label directory member set differs; missing=$(join(sort!(collect(setdiff(expected, actual))), ',')); extra=$(join(sort!(collect(setdiff(actual, expected))), ','))"))
    true
end

function _read_i32_little_endian(path::String, count::Int)
    filesize(path) == sizeof(Int32) * count ||
        throw(DimensionMismatch("packet graph binary size differs"))
    words = Vector{Int32}(undef, count)
    open(path, "r") do io
        read!(io, words)
        eof(io) || error("packet graph has trailing bytes")
    end
    ltoh.(words)
end

function _read_f64_little_endian(path::String, count::Int; label="binary")
    filesize(path) == sizeof(Float64) * count ||
        throw(DimensionMismatch("$label size differs"))
    words = Vector{UInt64}(undef, count)
    open(path, "r") do io
        read!(io, words)
        eof(io) || error("$label has trailing bytes")
    end
    Float64[reinterpret(Float64, ltoh(word)) for word in words]
end

function _update_file_digest!(context, path::String)
    buffer = Vector{UInt8}(undef, 1 << 20)
    open(path, "r") do io
        while !eof(io)
            count = readbytes!(io, buffer)
            count == 0 && break
            SHA.update!(context, view(buffer, 1:count))
        end
    end
    context
end

"""Recompute the candidate producer's primary scientific digest from the
retained primary artifacts. Telemetry, configuration, and replay timing are
deliberately outside this digest, exactly as in `candidate_runner.jl`."""
function _retained_science_digest(candidate_root::String)
    context = SHA.SHA2_256_CTX()
    SHA.update!(context, codeunits(SCIENCE_SCHEMA))
    for name in ("candidate_cases.csv", "candidate_trace.csv",
                 "final_states_index.csv", "hard_decisions_index.csv",
                 "final_states_f64_le.bin", "hard_decisions_packed.bin")
        _update_file_digest!(context, joinpath(candidate_root, name))
    end
    bytes2hex(SHA.digest!(context))
end

function _graph_identity(checks)
    io = IOBuffer()
    for check in checks
        write(io, htol(Int32(length(check))))
        for bit in check
            write(io, htol(Int32(bit)))
        end
    end
    bytes2hex(sha256(take!(io)))
end

function _read_graph(path::String, n::Int, m::Int)
    raw = _read_i32_little_endian(path, 6m)
    matrix = reshape(raw, 6, m)
    checks = [Int.(matrix[:, check]) for check in 1:m]
    degrees = zeros(Int, n)
    for check in checks
        length(unique(check)) == 6 ||
            error("packet graph repeats a bit within a check")
        for bit in check
            1 <= bit <= n || error("packet graph contains an out-of-range bit")
            degrees[bit] += 1
        end
    end
    all(==(3), degrees) || error("packet graph variable degree differs from three")
    checks
end

function _read_config(path::String)
    table = read_csv(path)
    table.header == ["field", "value"] || error("configuration CSV schema differs")
    result = Dict{String,String}()
    for row in table.rows
        haskey(result, row["field"]) && error("packet config field repeats")
        result[row["field"]] = row["value"]
    end
    result
end

function _activated_grid_equal(stage::String, left, right)
    length(left) == length(right) || return false
    tolerance = stage == "fine" ? 2.0e-12 : 0.0
    all(isapprox(Float64(left[index]), Float64(right[index]);
                 atol=tolerance, rtol=0.0) for index in eachindex(left))
end

function _validate_activated_population(activation::StageActivation, cases,
                                        snrs, n, m, graph_sha256;
                                        enforce_registered::Bool)
    activation.stage in ("coarse", "fine") ||
        error("activation stage must be coarse or fine")
    activation.update_cap == UPDATE_CAP ||
        error("activation update cap differs from thirty")
    _activated_grid_equal(activation.stage, snrs, activation.snrs) ||
        error("packet SNR grid differs from the verified activation")
    expected_frames = collect(activation.frame_first:activation.frame_last)
    isempty(expected_frames) && error("activation frame range is empty")
    length(cases) == length(snrs) * length(expected_frames) ||
        error("activated packet case count differs")
    expected = [(snr, frame) for snr in snrs for frame in expected_frames]
    actual = [(parse(Float64, row["physical_esn0_db"]),
               parse(Int, row["frame"])) for row in cases]
    actual == expected || error("packet SNR/frame order differs from activation")
    if enforce_registered
        n == REGISTERED_N || error("registered packet n differs")
        m == REGISTERED_M || error("registered packet m differs")
        graph_sha256 == REGISTERED_GRAPH_SHA256 ||
            error("registered packet graph identity differs")
        registered_frames = activation.stage == "coarse" ?
            (20_001, 20_024) : (30_001, 30_200)
        (activation.frame_first, activation.frame_last) == registered_frames ||
            error("activation frame range differs from the registered stage")
        if activation.stage == "coarse"
            activation.snrs == collect(1.5:0.5:12.0) ||
                error("coarse SNR grid differs")
        else
            length(activation.snrs) == 11 ||
                error("fine SNR grid must have eleven levels")
            all(isapprox(activation.snrs[index + 1] - activation.snrs[index], 0.1;
                         atol=2.0e-12, rtol=0.0) for index in 1:10) ||
                error("fine SNR spacing differs")
        end
    end
    true
end

function _load_packet(packet_root::String, activation::StageActivation;
                      enforce_registered::Bool)
    ready_path = joinpath(packet_root, "PACKET_READY.txt")
    isfile(ready_path) || error("packet marker is absent")
    ready = read_key_values(ready_path)
    _exact_keys(ready, PACKET_MARKER_FIELDS, "packet marker")
    ready["schema"] == PACKET_SCHEMA || error("packet marker schema differs")
    ready["experiment_id"] == EXPERIMENT_ID || error("packet experiment differs")
    ready["stage"] in ("coarse", "fine") || error("packet stage differs")
    ready["stage"] == activation.stage ||
        error("packet stage differs from the verified activation")
    ready["activation_sha256"] == activation.sha256 ||
        error("packet marker activation hash differs")
    ready["truth_fields_present"] == "false" || error("packet contains truth")
    ready["comparison_decoder_fields_present"] == "false" ||
        error("packet contains comparison-decoder fields")
    ready["manifest_file"] == PACKET_MANIFEST ||
        error("packet manifest filename differs")
    manifest_path = joinpath(packet_root, ready["manifest_file"])
    file_sha256(manifest_path) == ready["manifest_sha256"] ||
        error("packet manifest digest differs")
    verify_sha_manifest(packet_root, ready["manifest_file"];
                        expected_members=PACKET_MEMBERS)
    _validate_directory_members(packet_root, PACKET_MEMBERS,
                                PACKET_MANIFEST, "PACKET_READY.txt", "packet")

    config = _read_config(joinpath(packet_root, "packet_config.csv"))
    _exact_keys(config, PACKET_CONFIG_FIELDS, "packet config")
    config["schema"] == PACKET_SCHEMA || error("packet config schema differs")
    config["experiment_id"] == EXPERIMENT_ID || error("packet config differs")
    config["stage"] == ready["stage"] || error("packet stage bindings differ")
    config["activation_sha256"] == activation.sha256 ||
        error("packet config activation hash differs")
    config["truth_fields_present"] == "false" || error("packet config has truth")
    config["comparison_decoder_fields_present"] == "false" ||
        error("packet config has comparison-decoder fields")
    case_count = parse(Int, ready["case_count"])
    parse(Int, config["case_count"]) == case_count ||
        error("packet case-count bindings differ")
    n = parse(Int, config["n"])
    m = parse(Int, config["m"])
    parse(Int, config["edge_count"]) == 6m || error("packet edge count differs")
    parse(Int, config["check_degree"]) == 6 || error("packet check degree differs")
    parse(Int, config["variable_degree"]) == 3 ||
        error("packet variable degree differs")
    encoding = lowercase(config["llr_encoding"])
    all(token -> occursin(token, encoding), ("float64", "little", "column")) ||
        error("packet LLR encoding differs")
    config["unit_noise_reused_by_frame_across_snr"] == "true" ||
        error("packet unit-noise reuse declaration differs")
    config["case_order"] == "ascending SNR outer, ascending frame inner" ||
        error("packet case order declaration differs")
    (parse(Int, config["frame_first"]), parse(Int, config["frame_last"])) ==
        (activation.frame_first, activation.frame_last) ||
        error("packet frame range differs from the verified activation")

    graph_path = joinpath(packet_root, "checks_i32_6_by_m.bin")
    file_sha256(graph_path) == config["graph_binary_sha256"] ||
        error("packet graph binary digest differs")
    checks = _read_graph(graph_path, n, m)
    graph_sha256 = _graph_identity(checks)
    graph_sha256 == config["graph_scientific_sha256"] ||
        error("packet graph scientific identity differs")

    llr_path = joinpath(packet_root, "llr_f64_n_by_case.bin")
    file_sha256(llr_path) == config["llr_binary_sha256"] ||
        error("packet LLR binary digest differs")
    raw = _read_f64_little_endian(llr_path, n * case_count;
                                  label="packet LLR binary")
    llrs = reshape(raw, n, case_count)

    index = read_csv(joinpath(packet_root, "case_index.csv"))
    index.header == ["case_ordinal", "frame", "physical_esn0_db", "noise_seed",
                     "graph_sha256", "clipped_llr_sha256"] ||
        error("packet case-index schema differs")
    length(index.rows) == case_count || error("packet index row count differs")
    cases = sort(index.rows; by=row -> parse(Int, row["case_ordinal"]))
    for (ordinal, row) in enumerate(cases)
        parse(Int, row["case_ordinal"]) == ordinal || error("packet ordinal differs")
        row["graph_sha256"] == graph_sha256 || error("packet case graph differs")
        vector_sha256(view(llrs, :, ordinal)) == row["clipped_llr_sha256"] ||
            error("packet case LLR digest differs")
    end

    grid = read_csv(joinpath(packet_root, "snr_grid.csv"))
    grid.header == ["snr_ordinal", "physical_esn0_db"] ||
        error("SNR-grid schema differs")
    for (ordinal, row) in enumerate(grid.rows)
        parse(Int, row["snr_ordinal"]) == ordinal || error("SNR-grid ordinal differs")
    end
    snrs = Float64[parse(Float64, row["physical_esn0_db"]) for row in grid.rows]
    issorted(snrs) && length(unique(snrs)) == length(snrs) ||
        error("SNR grid must be strictly increasing")
    Set(parse(Float64, row["physical_esn0_db"]) for row in cases) == Set(snrs) ||
        error("packet cases and SNR grid differ")
    _validate_activated_population(
        activation, cases, snrs, n, m, graph_sha256; enforce_registered)
    parse(Int, config["snr_count"]) == length(snrs) ||
        error("packet SNR count differs")
    Packet(ready["stage"], activation.sha256, n, m, checks, llrs, cases, snrs,
           file_sha256(ready_path), ready["manifest_sha256"], graph_sha256,
           config["graph_binary_sha256"], config["llr_binary_sha256"], config)
end

function _candidate_commit_gate(candidate_root::String, packet::Packet,
                                activation::StageActivation)
    marker_path = joinpath(candidate_root, "CANDIDATE_COMMITTED.txt")
    isfile(marker_path) || error("candidate commit marker is absent")
    commit = read_key_values(marker_path)
    _exact_keys(commit, CANDIDATE_MARKER_FIELDS, "candidate commit")
    commit["schema"] == COMMIT_SCHEMA || error("candidate commit schema differs")
    commit["experiment_id"] == EXPERIMENT_ID || error("candidate experiment differs")
    commit["stage"] == packet.stage || error("candidate stage differs")
    commit["activation_sha256"] == activation.sha256 ||
        error("candidate commit activation hash differs")
    packet.activation_sha256 == activation.sha256 ||
        error("packet activation binding differs before candidate scoring")
    parse(Int, commit["case_count"]) == length(packet.cases) ||
        error("candidate case count differs")
    commit["candidate_outcome_committed"] == "true" ||
        error("candidate outcome is not committed")
    commit["scientific_replay_equal"] == "true" ||
        error("candidate scientific replay differs")
    commit["scientific_trace_sha256"] ==
        commit["replay_scientific_trace_sha256"] ||
        error("candidate scientific trace digests differ")
    commit["telemetry_excluded_from_scientific_replay"] == "true" ||
        error("candidate replay incorrectly includes telemetry")
    commit["truth_used"] == "false" || error("candidate reports truth access")
    commit["bp_used"] == "false" || error("candidate reports BP access")
    commit["packet_ready_sha256"] == packet.ready_sha256 ||
        error("candidate used a different packet marker")
    commit["packet_manifest_sha256"] == packet.manifest_sha256 ||
        error("candidate used a different packet manifest")
    commit["manifest_file"] == CANDIDATE_MANIFEST ||
        error("candidate manifest filename differs")
    manifest_path = joinpath(candidate_root, commit["manifest_file"])
    file_sha256(manifest_path) == commit["manifest_sha256"] ||
        error("candidate manifest digest differs")
    verify_sha_manifest(candidate_root, commit["manifest_file"];
                        expected_members=CANDIDATE_MEMBERS)
    _validate_directory_members(candidate_root, CANDIDATE_MEMBERS,
                                CANDIDATE_MANIFEST, "CANDIDATE_COMMITTED.txt",
                                "candidate")

    replay = read_csv(joinpath(candidate_root, "replay_verification.csv"))
    replay.header == ["field", "primary", "replay", "equal"] ||
        error("candidate replay-verification schema differs")
    length(replay.rows) == 1 || error("candidate replay-verification row differs")
    replay_row = only(replay.rows)
    replay_row["field"] == "scientific_trace_sha256" ||
        error("candidate replay-verification field differs")
    replay_row["primary"] == commit["scientific_trace_sha256"] ||
        error("candidate replay primary digest binding differs")
    replay_row["replay"] == commit["replay_scientific_trace_sha256"] ||
        error("candidate replay digest binding differs")
    replay_row["equal"] == "true" || error("candidate replay equality differs")
    retained_digest = _retained_science_digest(candidate_root)
    retained_digest == commit["scientific_trace_sha256"] ||
        error("retained candidate artifacts differ from the committed scientific digest")

    config = _read_config(joinpath(candidate_root, "candidate_config.csv"))
    _exact_keys(config, CANDIDATE_CONFIG_FIELDS, "candidate config")
    config["schema"] == EXECUTION_SCHEMA || error("candidate execution schema differs")
    config["experiment_id"] == EXPERIMENT_ID || error("candidate config experiment differs")
    config["stage"] == packet.stage || error("candidate config stage differs")
    config["activation_sha256"] == activation.sha256 ||
        error("candidate config activation hash differs")
    parse(Int, config["case_count"]) == length(packet.cases) ||
        error("candidate config case count differs")
    parse(Int, config["update_cap"]) == UPDATE_CAP ||
        error("candidate update cap differs from thirty")
    config["registered_graph_sha256"] == REGISTERED_GRAPH_SHA256 ||
        error("candidate registered graph identity differs")
    config["graph_binary_sha256"] == packet.graph_binary_sha256 ||
        error("candidate graph binary binding differs")
    config["llr_binary_sha256"] == packet.llr_binary_sha256 ||
        error("candidate LLR binary binding differs")
    config["packet_ready_sha256"] == packet.ready_sha256 ||
        error("candidate config packet marker binding differs")
    config["packet_manifest_sha256"] == packet.manifest_sha256 ||
        error("candidate config packet manifest binding differs")
    config["objective_source_sha256"] == OBJECTIVE_SOURCE_SHA256 ||
        error("candidate objective source identity differs")
    config["accelerated_source_sha256"] == ACCELERATED_SOURCE_SHA256 ||
        error("candidate accelerated source identity differs")
    runner_path = joinpath(@__DIR__, "candidate_runner.jl")
    config["candidate_runner_sha256"] == file_sha256(runner_path) ||
        error("candidate runner source identity differs")
    config["truth_used"] == "false" || error("candidate config reports truth access")
    config["bp_used"] == "false" || error("candidate config reports BP access")
    config["telemetry_in_scientific_digest"] == "false" ||
        error("candidate config included telemetry in science digest")
    merge(commit, Dict("retained_scientific_trace_sha256" => retained_digest))
end

function _syndrome_weight(checks, bits::BitVector)
    weight = 0
    @inbounds for check in checks
        parity = false
        for bit in check
            parity = xor(parity, bits[bit])
        end
        weight += parity
    end
    weight
end

_bit_errors(left::BitVector, right::BitVector) =
    count(index -> left[index] != right[index], eachindex(left))

function _read_hard_records(candidate_root::String, packet::Packet)
    table = read_csv(joinpath(candidate_root, "hard_decisions_index.csv"))
    table.header == HARD_INDEX_HEADER || error("hard-decision index schema differs")
    records = Dict{Tuple{Int,String},NamedTuple}()
    binary_path = joinpath(candidate_root, "hard_decisions_packed.bin")
    open(binary_path, "r") do io
        next_offset = 0
        for row in sort(table.rows; by=row -> parse(Int, row["byte_offset"]))
            offset = parse(Int, row["byte_offset"])
            offset == next_offset || error("packed hard-decision records are not contiguous")
            count_bytes = parse(Int, row["byte_count"])
            count_bytes == cld(packet.n, 8) ||
                error("packed hard-decision byte count differs")
            parse(Int, row["bit_count"]) == packet.n ||
                error("hard-decision bit count differs")
            seek(io, offset)
            packed = read(io, count_bytes)
            length(packed) == count_bytes || error("packed hard decision is truncated")
            bytes_sha256(packed) == row["packed_sha256"] ||
                error("packed hard-decision digest differs")
            bits = unpack_bits(packed, packet.n)
            vector_sha256(bits) == row["hard_sha256"] ||
                error("unpacked hard-decision digest differs")
            ordinal = parse(Int, row["case_ordinal"])
            1 <= ordinal <= length(packet.cases) || error("hard-decision ordinal differs")
            case = packet.cases[ordinal]
            row["stage"] == packet.stage || error("hard-decision stage differs")
            parse(Int, row["frame"]) == parse(Int, case["frame"]) ||
                error("hard-decision frame differs")
            parse(Float64, row["snr_db"]) ==
                parse(Float64, case["physical_esn0_db"]) ||
                error("hard-decision SNR differs")
            syndrome = _syndrome_weight(packet.checks, bits)
            syndrome == parse(Int, row["syndrome_weight"]) ||
                error("hard-decision syndrome differs")
            ties = parse(Int, row["tie_count"])
            valid = _parse_bool(row["parity_valid"])
            valid == (syndrome == 0 && ties == 0) ||
                error("hard-decision parity-valid field differs")
            role = row["role"]
            role in ("latched", "terminal") || error("hard-decision role differs")
            key = (ordinal, role)
            haskey(records, key) && error("hard-decision role repeats")
            records[key] = (; bits, update=parse(Int, row["update"]), syndrome,
                            ties, valid, hash=row["hard_sha256"])
            next_offset += count_bytes
        end
        next_offset == filesize(binary_path) ||
            error("hard-decision binary contains unindexed bytes")
    end
    records
end

function _read_state_records(candidate_root::String, packet::Packet)
    table = read_csv(joinpath(candidate_root, "final_states_index.csv"))
    table.header == STATE_INDEX_HEADER || error("final-state index schema differs")
    length(table.rows) == length(packet.cases) ||
        error("final-state index row count differs")
    records = Dict{Int,NamedTuple}()
    binary_path = joinpath(candidate_root, "final_states_f64_le.bin")
    open(binary_path, "r") do io
        next_offset = 0
        for row in sort(table.rows; by=row -> parse(Int, row["byte_offset"]))
            offset = parse(Int, row["byte_offset"])
            offset == next_offset || error("final-state records are not contiguous")
            byte_count = parse(Int, row["byte_count"])
            byte_count == sizeof(Float64) * packet.n ||
                error("final-state byte count differs")
            parse(Int, row["coordinate_count"]) == packet.n ||
                error("final-state coordinate count differs")
            seek(io, offset)
            words = Vector{UInt64}(undef, packet.n)
            read!(io, words)
            values = Float64[reinterpret(Float64, ltoh(word)) for word in words]
            all(value -> isfinite(value) && 0.0 <= value <= 1.0, values) ||
                error("final state is outside the finite box")
            vector_sha256(values) == row["state_sha256"] ||
                error("final-state scientific digest differs")
            ordinal = parse(Int, row["case_ordinal"])
            1 <= ordinal <= length(packet.cases) || error("final-state ordinal differs")
            haskey(records, ordinal) && error("final-state ordinal repeats")
            case = packet.cases[ordinal]
            row["stage"] == packet.stage || error("final-state stage differs")
            parse(Int, row["frame"]) == parse(Int, case["frame"]) ||
                error("final-state frame differs")
            parse(Float64, row["snr_db"]) ==
                parse(Float64, case["physical_esn0_db"]) ||
                error("final-state SNR differs")
            row["role"] == "terminal" || error("final-state role differs")
            parse(Int, row["update"]) == UPDATE_CAP ||
                error("final-state update differs")
            records[ordinal] = (; hash=row["state_sha256"], values)
            next_offset += byte_count
        end
        next_offset == filesize(binary_path) ||
            error("final-state binary contains unindexed bytes")
    end
    records
end

function _unique_row(rows, predicate, label)
    selected = filter(predicate, rows)
    length(selected) == 1 ||
        throw(ArgumentError("$label expected one row, found $(length(selected))"))
    only(selected)
end

function _load_candidate(candidate_root::String, packet::Packet)
    cases_table = read_csv(joinpath(candidate_root, "candidate_cases.csv"))
    trace_table = read_csv(joinpath(candidate_root, "candidate_trace.csv"))
    telemetry_table = read_csv(joinpath(candidate_root, "candidate_telemetry.csv"))
    cases_table.header == CASE_HEADER || error("candidate-case schema differs")
    trace_table.header == TRACE_HEADER || error("candidate-trace schema differs")
    telemetry_table.header == String[
        "case_ordinal", "stage", "snr_db", "frame", "primary_runtime_ns",
        "replay_runtime_ns", "primary_allocated_bytes", "replay_allocated_bytes",
        "primary_gc_runtime_ns", "replay_gc_runtime_ns",
        "primary_process_maxrss", "replay_process_maxrss",
    ] || error("candidate telemetry schema differs")
    length(cases_table.rows) == length(packet.cases) ||
        error("candidate case row count differs")
    length(trace_table.rows) == UPDATE_CAP * length(packet.cases) ||
        error("candidate trace must contain exactly thirty rows per case")
    length(telemetry_table.rows) == length(packet.cases) ||
        error("candidate telemetry row count differs")
    hard = _read_hard_records(candidate_root, packet)
    states = _read_state_records(candidate_root, packet)
    results = NamedTuple[]
    for ordinal in eachindex(packet.cases)
        packet_case = packet.cases[ordinal]
        frame = parse(Int, packet_case["frame"])
        snr = parse(Float64, packet_case["physical_esn0_db"])
        row = _unique_row(cases_table.rows,
            item -> parse(Int, item["case_ordinal"]) == ordinal,
            "candidate case $ordinal")
        _required(row, ["stage", "snr_db", "frame", "noise_seed", "llr_sha256",
                        "first_valid_update", "latched_hard_sha256",
                        "terminal_update", "terminal_state_sha256",
                        "terminal_hard_sha256", "terminal_syndrome_weight",
                        "terminal_tie_count", "terminal_parity_valid",
                        "terminal_objective", "terminal_normalized_objective",
                        "terminal_signal_term", "terminal_normalized_signal_term",
                        "terminal_parity_term", "terminal_normalized_parity_term",
                        "terminal_squared_distance_sum",
                        "terminal_maximum_check_distance",
                        "terminal_nonzero_distance_checks",
                        "terminal_distance_above_1e_10_checks",
                        "terminal_mapping_norm_inf"], "candidate case")
        row["stage"] == packet.stage || error("candidate case stage differs")
        parse(Int, row["frame"]) == frame || error("candidate case frame differs")
        parse(Float64, row["snr_db"]) == snr || error("candidate case SNR differs")
        parse(Int, row["noise_seed"]) == parse(Int, packet_case["noise_seed"]) ||
            error("candidate case noise seed differs")
        row["llr_sha256"] == packet_case["clipped_llr_sha256"] ||
            error("candidate case LLR digest differs")
        parse(Int, row["terminal_update"]) == UPDATE_CAP ||
            error("candidate terminal update differs from thirty")

        traces = sort(filter(item -> parse(Int, item["case_ordinal"]) == ordinal,
                             trace_table.rows);
                      by=item -> parse(Int, item["update"]))
        length(traces) == UPDATE_CAP || error("candidate trace count differs")
        first_valid = 0
        trace_tie_coordinates = 0
        for (update, trace) in enumerate(traces)
            parse(Int, trace["update"]) == update || error("candidate trace update differs")
            parse(Int, trace["case_ordinal"]) == ordinal ||
                error("candidate trace ordinal differs")
            trace["stage"] == packet.stage || error("candidate trace stage differs")
            parse(Int, trace["frame"]) == frame || error("candidate trace frame differs")
            parse(Float64, trace["snr_db"]) == snr || error("candidate trace SNR differs")
            syndrome = parse(Int, trace["syndrome_weight"])
            ties = parse(Int, trace["tie_count"])
            valid = _parse_bool(trace["parity_valid"])
            valid == (syndrome == 0 && ties == 0) ||
                error("candidate trace parity-valid field differs")
            first_valid == 0 && valid && (first_valid = update)
            trace_tie_coordinates += ties
        end
        declared_first = isempty(row["first_valid_update"]) ? 0 :
            parse(Int, row["first_valid_update"])
        first_valid == declared_first || error("candidate first-valid latch differs")
        local_rows = [[trace[field] for field in TRACE_HEADER] for trace in traces]
        bytes_sha256(csv_bytes(TRACE_HEADER, local_rows)) ==
            row["per_update_scientific_trace_sha256"] ||
            error("candidate per-case scientific trace digest differs")

        state = get(states, ordinal, nothing)
        state === nothing && error("candidate terminal state is absent")
        row["terminal_state_sha256"] == traces[end]["state_sha256"] ||
            error("candidate terminal state and update-30 trace differ")
        state.hash == row["terminal_state_sha256"] ||
            error("candidate terminal-state artifact binding differs")

        terminal = get(hard, (ordinal, "terminal"), nothing)
        terminal === nothing && error("candidate terminal hard decision is absent")
        terminal.update == UPDATE_CAP || error("terminal hard-decision update differs")
        terminal.hash == row["terminal_hard_sha256"] ||
            error("terminal hard-decision hash differs")
        terminal.hash == traces[end]["hard_sha256"] ||
            error("terminal hard decision and trace differ")
        terminal.syndrome == parse(Int, row["terminal_syndrome_weight"]) ||
            error("terminal syndrome bindings differ")
        terminal.ties == parse(Int, row["terminal_tie_count"]) ||
            error("terminal tie bindings differ")
        terminal.valid == _parse_bool(row["terminal_parity_valid"]) ||
            error("terminal parity-valid bindings differ")

        latched = get(hard, (ordinal, "latched"), nothing)
        if first_valid == 0
            latched === nothing || error("candidate has a latch without a valid readout")
            isempty(row["latched_hard_sha256"]) || error("candidate latch hash should be empty")
        else
            latched === nothing && error("candidate valid readout was not latched")
            latched.update == first_valid || error("candidate latch update differs")
            latched.valid && latched.ties == 0 || error("candidate latch is not tie-free valid")
            latched.hash == row["latched_hard_sha256"] || error("candidate latch hash differs")
            latched.hash == traces[first_valid]["hard_sha256"] ||
                error("candidate latch and trace differ")
        end
        push!(results, (; ordinal, frame, snr, row, traces, terminal, latched,
                         trace_tie_coordinates))
    end
    (; cases=results, telemetry=telemetry_table.rows)
end

"""Compute pass and stable-suffix fields without reading candidate artifacts."""
function summarize_snr(rows::Vector{<:NamedTuple}, stage::String)
    snrs = sort!(unique(Float64[row.snr for row in rows]))
    margin = stage == "coarse" ? 4 : stage == "fine" ? 30 :
        throw(ArgumentError("stage must be coarse or fine"))
    summaries = NamedTuple[]
    for snr in snrs
        selected = filter(row -> row.snr == snr, rows)
        candidate = count(row -> row.candidate_recovered, selected)
        bp = count(row -> row.bp_recovered, selected)
        count_pass = candidate >= bp - margin
        wrong_valid_gate_pass = !any(
            row -> hasproperty(row, :candidate_wrong_valid) &&
                   row.candidate_wrong_valid, selected)
        tie_gate_pass = !any(
            row -> hasproperty(row, :trace_tie_coordinates) &&
                   row.trace_tie_coordinates > 0, selected)
        passed = count_pass && wrong_valid_gate_pass && tie_gate_pass
        push!(summaries, (; snr, case_count=length(selected), candidate, bp,
                           deficit=candidate - bp, margin, count_pass,
                           wrong_valid_gate_pass, tie_gate_pass, passed,
                           stable_suffix_pass=false, selected))
    end
    suffix = true
    reversed = NamedTuple[]
    for summary in Iterators.reverse(summaries)
        suffix &= summary.passed
        push!(reversed, merge(summary, (; stable_suffix_pass=suffix)))
    end
    reverse!(reversed)
end

function _threshold_crossings(summaries, stage::String)
    stage in ("coarse", "fine") || throw(ArgumentError("stage must be coarse or fine"))
    passing = Float64[summary.snr for summary in summaries if summary.passed]
    provisional = stage == "coarse" ? passing : Float64[]
    stable = stage == "fine" ?
        Float64[summary.snr for summary in summaries if summary.stable_suffix_pass] :
        Float64[]
    (; lowest_target=isempty(passing) ? "" : f64_text(first(passing)),
       provisional_coarse=isempty(provisional) ? "" : f64_text(first(provisional)),
       stable_working=isempty(stable) ? "" : f64_text(first(stable)))
end

function _production_backend_loader()
    # This function is called only after the packet and immutable candidate
    # commit have passed all scorer-side hash gates.
    file_sha256(ADAPTER_PATH) == ADAPTER_SHA256 || error("immutable adapter hash differs")
    file_sha256(ADAPTER_CONFIG_PATH) == ADAPTER_CONFIG_SHA256 ||
        error("immutable adapter config hash differs")
    pushfirst!(LOAD_PATH, JADE_ROOT)
    try
        Base.include(@__MODULE__, ADAPTER_PATH)
    finally
        first(LOAD_PATH) == JADE_ROOT && popfirst!(LOAD_PATH)
    end
    # The immutable adapter is included at runtime, so every binding and call
    # originating in that newer Julia world must cross through invokelatest.
    Adapter = Base.invokelatest(getfield, @__MODULE__, :RQ2NativeGap001)
    adapter_binding(name::Symbol) = Base.invokelatest(getfield, Adapter, name)
    adapter_call(name::Symbol, arguments...) =
        Base.invokelatest(adapter_binding(name), arguments...)
    Split = adapter_binding(:Split)
    split_binding(name::Symbol) = Base.invokelatest(getfield, Split, name)
    Legacy = adapter_binding(:Legacy)
    legacy_binding(name::Symbol) = Base.invokelatest(getfield, Legacy, name)
    legacy_call(name::Symbol, arguments...) =
        Base.invokelatest(legacy_binding(name), arguments...)

    config = adapter_call(:load_config, ADAPTER_CONFIG_PATH)
    protocol = config["protocol"]
    split_runner_path = String(adapter_binding(:SPLIT_RUNNER_PATH))
    legacy_runner_path = String(split_binding(:LEGACY_RUNNER_PATH))
    file_sha256(RETAINED_SPLIT_CONFIG_PATH) ==
        String(protocol["split_config_sha256"]) ||
        error("retained split configuration hash differs")
    file_sha256(split_runner_path) ==
        String(protocol["split_runner_sha256"]) ||
        error("retained split runner hash differs")
    file_sha256(ARCHIVED_GENERATOR_PATH) == ARCHIVED_GENERATOR_SHA256 ||
        error("archived generator hash differs")
    file_sha256(legacy_runner_path) ==
        String(protocol["legacy_runner_sha256"]) ||
        error("adapter-bound generator hash differs")
    realpath(legacy_runner_path) == realpath(ARCHIVED_GENERATOR_PATH) ||
        error("adapter did not bind the archived generator")
    split = TOML.parsefile(RETAINED_SPLIT_CONFIG_PATH)
    gate = legacy_call(:source_gate, split)
    Bool(gate["passed"]) || error("immutable archived-source gate failed")
    legacy_call(:enforce_thread_environment, split)
    native = legacy_call(:load_native, split)
    generated = adapter_call(:make_bp_code, config, split)
    regenerate = function (snr::Float64, frame::Int)
        channel = adapter_call(:channel_config, split, snr)
        input = legacy_call(:generate_input, channel, native, generated.code, frame)
        (; llr=Float64.(input.clipped_llr), noise_seed=Int(input.noise_seed),
           graph_sha256=String(input.identities.graph_sha256),
           transmitted_bits=BitVector(input.transmitted_bits),
           clipped_llr_sha256=String(input.identities.clipped_llr_sha256))
    end
    decode_bp = llr -> adapter_call(:decode_bp, generated.modem, generated.code, llr)
    jade_module = adapter_binding(:JadeJcade)
    jade_source_path = String(pathof(jade_module))
    jade_commit = try
        readchomp(Cmd(["git", "-C", JADE_ROOT, "rev-parse", "HEAD"]))
    catch
        ""
    end
    receipt = (;
        adapter_path=ADAPTER_PATH,
        adapter_sha256=file_sha256(ADAPTER_PATH),
        config_path=ADAPTER_CONFIG_PATH,
        config_sha256=file_sha256(ADAPTER_CONFIG_PATH),
        retained_split_config_path=RETAINED_SPLIT_CONFIG_PATH,
        retained_split_config_sha256=file_sha256(RETAINED_SPLIT_CONFIG_PATH),
        retained_split_runner_path=split_runner_path,
        retained_split_runner_sha256=file_sha256(split_runner_path),
        archived_generator_path=ARCHIVED_GENERATOR_PATH,
        archived_generator_sha256=file_sha256(ARCHIVED_GENERATOR_PATH),
        adapter_bound_generator_path=legacy_runner_path,
        adapter_bound_generator_sha256=file_sha256(legacy_runner_path),
        jade_root=JADE_ROOT,
        jade_git_commit=jade_commit,
        jade_project_sha256=file_sha256(joinpath(JADE_ROOT, "Project.toml")),
        jade_manifest_sha256=file_sha256(joinpath(JADE_ROOT, "Manifest.toml")),
        jade_package_source_path=jade_source_path,
        jade_package_source_sha256=file_sha256(jade_source_path),
        jade_package_id=string(Base.PkgId(jade_module)),
        source_gate_passed=true,
        bp_rule="exact flooding sum-product; first zero syndrome or 80 iterations")
    (; regenerate, decode_bp, receipt)
end

function _receipt_value(receipt, field::Symbol)
    hasproperty(receipt, field) ? String(getproperty(receipt, field)) : ""
end

function _median_text(values)
    isempty(values) ? "" : f64_text(Float64(median(values)))
end

function _score_impl(activation::StageActivation, packet_root::String,
                     candidate_root::String, score_root::String,
                     backend_loader::Function;
                     enforce_registered::Bool)
    # Ordering is deliberate: no generator, truth object, or BP implementation
    # is loaded until both immutable artifact gates and candidate consistency
    # checks have passed.
    packet = _load_packet(abspath(packet_root), activation; enforce_registered)
    commit = _candidate_commit_gate(abspath(candidate_root), packet, activation)
    candidate = _load_candidate(abspath(candidate_root), packet)
    backend = backend_loader()
    if enforce_registered
        packet.config["adapter_sha256"] ==
            _receipt_value(backend.receipt, :adapter_sha256) ||
            error("scorer adapter identity differs from packet preparation")
        packet.config["archived_config_sha256"] ==
            _receipt_value(backend.receipt, :config_sha256) ||
            error("scorer configuration identity differs from packet preparation")
        packet.config["retained_split_config_sha256"] ==
            _receipt_value(backend.receipt, :retained_split_config_sha256) ||
            error("scorer split configuration differs from packet preparation")
        packet.config["archived_generator_sha256"] ==
            _receipt_value(backend.receipt, :archived_generator_sha256) ||
            error("scorer generator identity differs from packet preparation")
    end

    scored = NamedTuple[]
    for case in candidate.cases
        packet_case = packet.cases[case.ordinal]
        regenerated = backend.regenerate(case.snr, case.frame)
        regenerated.noise_seed == parse(Int, packet_case["noise_seed"]) ||
            error("regenerated noise seed differs")
        regenerated.graph_sha256 == packet.graph_sha256 ||
            error("regenerated graph identity differs")
        regenerated.clipped_llr_sha256 == packet_case["clipped_llr_sha256"] ||
            error("regenerated LLR identity differs")
        packet_llr = Vector{Float64}(view(packet.llrs, :, case.ordinal))
        regenerated.llr == packet_llr || error("regenerated LLR values differ")
        length(regenerated.transmitted_bits) == packet.n ||
            error("regenerated transmitted-word length differs")

        truth = regenerated.transmitted_bits
        terminal_errors = _bit_errors(case.terminal.bits, truth)
        terminal_recovered = terminal_errors == 0
        terminal_wrong_valid = case.terminal.valid && !terminal_recovered
        if case.latched === nothing
            latched_errors = missing
            candidate_recovered = false
            candidate_wrong_valid = false
        else
            latched_errors = _bit_errors(case.latched.bits, truth)
            candidate_recovered = latched_errors == 0
            candidate_wrong_valid = !candidate_recovered
        end

        bp = backend.decode_bp(packet_llr)
        bp_hard = BitVector(bp.hard)
        length(bp_hard) == packet.n || error("BP hard-decision length differs")
        bp_syndrome = _syndrome_weight(packet.checks, bp_hard)
        bp_syndrome == Int(bp.syndrome_weight) || error("BP syndrome differs")
        bp_valid = bp_syndrome == 0
        bp_valid == Bool(bp.parity_valid) || error("BP parity-valid field differs")
        bp_errors = _bit_errors(bp_hard, truth)
        bp_recovered = bp_errors == 0
        Int(bp.iterations) <= 80 || error("BP exceeded eighty iterations")
        push!(scored, (; case..., candidate_recovered, candidate_wrong_valid,
                        latched_errors, terminal_errors, terminal_recovered,
                        terminal_wrong_valid, bp_recovered, bp_errors,
                        bp_valid, bp_syndrome, bp_iterations=Int(bp.iterations)))
    end

    summaries = summarize_snr(scored, packet.stage)
    output = require_empty_directory(score_root)
    case_header = String[
        "case_ordinal", "stage", "snr_db", "frame", "noise_seed",
        "llr_sha256", "candidate_first_valid_update", "candidate_recovered",
        "candidate_wrong_valid_word", "candidate_latched_coded_bit_errors",
        "candidate_terminal_coded_bit_errors", "candidate_terminal_recovered",
        "candidate_terminal_wrong_valid_word", "candidate_terminal_syndrome_weight",
        "candidate_terminal_tie_count", "candidate_terminal_parity_valid",
        "candidate_trace_tie_coordinates", "bp_recovered", "bp_coded_bit_errors",
        "bp_parity_valid", "bp_syndrome_weight", "bp_iterations",
        "terminal_objective", "terminal_normalized_objective",
        "terminal_signal_term", "terminal_normalized_signal_term",
        "terminal_parity_term", "terminal_normalized_parity_term",
        "terminal_squared_distance_sum", "terminal_maximum_check_distance",
        "terminal_nonzero_distance_checks",
        "terminal_distance_above_1e_10_checks", "terminal_mapping_norm_inf",
    ]
    case_rows = Vector{Vector{String}}()
    for item in scored
        row = item.row
        push!(case_rows, String[
            string(item.ordinal), packet.stage, f64_text(item.snr), string(item.frame),
            row["noise_seed"], row["llr_sha256"], row["first_valid_update"],
            bool_text(item.candidate_recovered), bool_text(item.candidate_wrong_valid),
            ismissing(item.latched_errors) ? "" : string(item.latched_errors),
            string(item.terminal_errors), bool_text(item.terminal_recovered),
            bool_text(item.terminal_wrong_valid), string(item.terminal.syndrome),
            string(item.terminal.ties), bool_text(item.terminal.valid),
            string(item.trace_tie_coordinates), bool_text(item.bp_recovered),
            string(item.bp_errors), bool_text(item.bp_valid), string(item.bp_syndrome),
            string(item.bp_iterations), row["terminal_objective"],
            row["terminal_normalized_objective"], row["terminal_signal_term"],
            row["terminal_normalized_signal_term"], row["terminal_parity_term"],
            row["terminal_normalized_parity_term"],
            row["terminal_squared_distance_sum"],
            row["terminal_maximum_check_distance"],
            row["terminal_nonzero_distance_checks"],
            row["terminal_distance_above_1e_10_checks"],
            row["terminal_mapping_norm_inf"],
        ])
    end
    write_csv(joinpath(output, "scored_cases.csv"), case_header, case_rows)

    summary_header = String[
        "stage", "snr_db", "case_count", "candidate_recoveries",
        "bp_recoveries", "candidate_minus_bp", "allowed_bp_deficit",
        "count_pass", "wrong_valid_gate_pass", "tie_gate_pass", "target_pass",
        "stable_suffix_pass", "candidate_at_least_190_count",
        "candidate_wrong_valid_words", "candidate_terminal_wrong_valid_words",
        "candidate_terminal_tie_cases", "candidate_trace_tie_cases",
        "candidate_trace_tie_coordinates", "first_valid_update_min",
        "first_valid_update_median", "first_valid_update_max",
        "update30_bit_errors_sum", "update30_bit_errors_median",
        "update30_bit_errors_max", "update30_syndrome_sum",
        "update30_syndrome_median", "update30_syndrome_max",
        "terminal_objective_median", "terminal_mapping_norm_inf_median",
        "bp_iterations_median", "bp_iterations_max",
    ]
    summary_rows = Vector{Vector{String}}()
    for summary in summaries
        selected = summary.selected
        firsts = Int[item.latched.update for item in selected if item.latched !== nothing]
        terminal_errors = Int[item.terminal_errors for item in selected]
        terminal_syndromes = Int[item.terminal.syndrome for item in selected]
        objectives = Float64[parse(Float64, item.row["terminal_objective"])
                             for item in selected]
        mappings = Float64[parse(Float64, item.row["terminal_mapping_norm_inf"])
                           for item in selected]
        bp_iterations = Int[item.bp_iterations for item in selected]
        push!(summary_rows, String[
            packet.stage, f64_text(summary.snr), string(summary.case_count),
            string(summary.candidate), string(summary.bp), string(summary.deficit),
            string(summary.margin), bool_text(summary.count_pass),
            bool_text(summary.wrong_valid_gate_pass),
            bool_text(summary.tie_gate_pass), bool_text(summary.passed),
            bool_text(summary.stable_suffix_pass),
            bool_text(summary.candidate >= 190),
            string(count(item -> item.candidate_wrong_valid, selected)),
            string(count(item -> item.terminal_wrong_valid, selected)),
            string(count(item -> item.terminal.ties > 0, selected)),
            string(count(item -> item.trace_tie_coordinates > 0, selected)),
            string(sum(item.trace_tie_coordinates for item in selected)),
            isempty(firsts) ? "" : string(minimum(firsts)), _median_text(firsts),
            isempty(firsts) ? "" : string(maximum(firsts)),
            string(sum(terminal_errors)), _median_text(terminal_errors),
            string(maximum(terminal_errors)), string(sum(terminal_syndromes)),
            _median_text(terminal_syndromes), string(maximum(terminal_syndromes)),
            _median_text(objectives), _median_text(mappings),
            _median_text(bp_iterations), string(maximum(bp_iterations)),
        ])
    end
    write_csv(joinpath(output, "snr_summary.csv"), summary_header, summary_rows)

    crossings = _threshold_crossings(summaries, packet.stage)
    write_key_values(joinpath(output, "threshold_summary.txt"), Pair{String,String}[
        "schema" => SCORE_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "stage" => packet.stage,
        "activation_sha256" => activation.sha256,
        "case_count" => string(length(scored)),
        "tested_snr_count" => string(length(packet.snrs)),
        "lowest_target_pass_snr_db" => crossings.lowest_target,
        "provisional_coarse_crossing_snr_db" => crossings.provisional_coarse,
        "stable_working_threshold_snr_db" => crossings.stable_working,
        "threshold_scope" => "exposed_development_only",
        "candidate_rerun_by_scorer" => "false",
        "candidate_manifest_sha256" => commit["manifest_sha256"],
        "packet_manifest_sha256" => packet.manifest_sha256,
        "truth_opened_after_candidate_commit" => "true",
        "bp_opened_after_candidate_commit" => "true",
    ])
    receipt = backend.receipt
    receipt_fields = Symbol[
        :adapter_path, :adapter_sha256, :config_path, :config_sha256,
        :retained_split_config_path, :retained_split_config_sha256,
        :retained_split_runner_path, :retained_split_runner_sha256,
        :archived_generator_path, :archived_generator_sha256,
        :adapter_bound_generator_path, :adapter_bound_generator_sha256,
        :jade_root, :jade_git_commit, :jade_project_sha256,
        :jade_manifest_sha256, :jade_package_source_path,
        :jade_package_source_sha256, :jade_package_id,
    ]
    receipt_rows = Vector{Vector{String}}(
        [[String(field), _receipt_value(receipt, field)] for field in receipt_fields])
    append!(receipt_rows, Vector{Vector{String}}([
        ["source_gate_passed", bool_text(Bool(receipt.source_gate_passed))],
        ["bp_rule", String(receipt.bp_rule)],
        ["activation_sha256", activation.sha256],
        ["graph_scientific_sha256", packet.graph_sha256],
        ["packet_adapter_sha256", packet.config["adapter_sha256"]],
        ["packet_archived_config_sha256", packet.config["archived_config_sha256"]],
        ["packet_retained_split_config_sha256",
         packet.config["retained_split_config_sha256"]],
        ["packet_archived_generator_sha256",
         packet.config["archived_generator_sha256"]],
        ["candidate_manifest_sha256", commit["manifest_sha256"]],
        ["candidate_scientific_trace_sha256",
         commit["retained_scientific_trace_sha256"]],
        ["scorer_source_sha256", file_sha256(@__FILE__)],
    ]))
    write_csv(joinpath(output, "scorer_source_receipt.csv"), ["field", "value"],
              receipt_rows)
    members = String["scored_cases.csv", "snr_summary.csv",
                     "threshold_summary.txt", "scorer_source_receipt.csv"]
    manifest = write_sha_manifest(output, members; filename="SCORE_MANIFEST.sha256")
    write_key_values(joinpath(output, "SCORE_COMMITTED.txt"), Pair{String,String}[
        "schema" => SCORE_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "stage" => packet.stage,
        "activation_sha256" => activation.sha256,
        "manifest_file" => basename(manifest),
        "manifest_sha256" => file_sha256(manifest),
        "candidate_rerun" => "false",
        "complete" => "true",
    ])
    (; scored, summaries, output)
end

function score(activation_path::String, packet_root::String,
               candidate_root::String, score_root::String)
    # The prospective activation and every bound source are verified before
    # the scorer reads a packet, candidate artifact, truth source, or BP code.
    activation = verify_activation(abspath(activation_path))
    _score_impl(activation, packet_root, candidate_root, score_root,
                _production_backend_loader; enforce_registered=true)
end

function score_with_backend_for_synthetic_test(activation::StageActivation,
                                               packet_root::String,
                                               candidate_root::String,
                                               score_root::String,
                                               backend_loader::Function,
                                               ::Val{:synthetic_test_only})
    _score_impl(activation, packet_root, candidate_root, score_root, backend_loader;
                enforce_registered=false)
end

function run_cli(arguments=ARGS)
    length(arguments) == 4 || error(
        "usage: score_candidate.jl ACTIVATION PACKET_ROOT CANDIDATE_ROOT SCORE_ROOT")
    score(arguments[1], arguments[2], arguments[3], arguments[4])
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    using .RQ2ConvexParityDistanceSNRThresholdScorer
    RQ2ConvexParityDistanceSNRThresholdScorer.run_cli()
end
