#!/usr/bin/env julia

module RQ2ConvexParityDistancePacketPreparation

using ConvexParityDistance

include(joinpath(@__DIR__, "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-001"
const PACKET_SCHEMA = "rq2-convex-parity-distance-001/candidate-packet-v1"
const RECEIPT_SCHEMA = "rq2-convex-parity-distance-001/trusted-preflight-v1"
const FRAME_FIRST = 61969
const FRAME_LAST = 62168
const CASE_COUNT = 200
const N = 10200
const M = 5100
const CACHE_COLUMNS = 400
const CACHE_COLUMN_FIRST = 201
const SOURCE_STAGE = "one_point_five_db_transfer"
const SOURCE_CHANNEL = "second_snr"
const REGISTERED_GRAPH_SHA256 =
    "94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d"
const SEALED_TABLE_SHA256 =
    "22baeb48556df1eebd36f1b4ea33e0cd213b0bfa192eebcc9e361e4defca4c19"
const CACHE_LLR_SHA256 =
    "1ca690bf3f4ed7ae2f92a21ceb68abdabad2144c7101ea0388fec4d5b33d4116"
const CACHE_GRAPH_BINARY_SHA256 =
    "18b46e41ee01464498085aeebf98a1ae489058739255a5d4994cd93e4d89246c"
const CACHE_INDEX_SHA256 =
    "03c4f58ff1cff8bef91634a6dad4bb4717d858365ff2e919b07d9c8bd5e2b16f"
const IDENTITY_FIELDS = (
    "graph_sha256", "transmitted_word_sha256",
    "transmitted_symbols_sha256", "unit_noise_sha256", "received_sha256",
    "raw_llr_sha256", "clipped_llr_sha256", "initial_state_sha256",
)
const DEFAULT_ADAPTER =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments/rq2_jc_projected_stationarity_001/trusted_budget90_adapter.jl"
const DEFAULT_BUDGET90_ROOT =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-common-coordinate-state-update-20261104/experiments/rq2_common_coordinate_budget_90_001"
const DEFAULT_CACHE_ROOT =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-claude-controls-20261031/experiments/_claude_stationarity_indicative_20261107"
const SEALED_RELATIVE_PATH = joinpath(
    "freeze", "2026-11-04_v1", "source",
    "rq2_common_coordinate_target_001", "inputs", "2026-11-03_v1",
    "fresh_input_freeze.csv")
const INPUT_MANIFEST_RELATIVE_PATH = joinpath(
    "freeze", "2026-11-04_v1", "source",
    "rq2_common_coordinate_target_001", "inputs", "2026-11-03_v1",
    "INPUT_MANIFEST.sha256")

# This is a trusted-side executable, so load the hash-recorded adapter while
# the module itself is defined. Loading it later inside `prepare` creates a
# Julia world-age boundary before the first adapter call.
Base.include(@__MODULE__, DEFAULT_ADAPTER)
const TrustedAdapter =
    RQ2JCProjectedStationarityBudget90Adapter

function _unique_row(rows, predicate, label)
    matches = filter(predicate, rows)
    length(matches) == 1 ||
        throw(ArgumentError("$label expected one row and found $(length(matches))"))
    only(matches)
end

function _read_graph(path)
    filesize(path) == sizeof(Int32) * 6 * M ||
        throw(DimensionMismatch("cached graph binary size differs"))
    values = Vector{Int32}(undef, 6 * M)
    open(path, "r") do io
        read!(io, values)
        eof(io) || error("cached graph binary has trailing bytes")
    end
    matrix = reshape(values, 6, M)
    [Int.(matrix[:, check]) for check in 1:M]
end

function _read_llrs(path)
    filesize(path) == sizeof(Float64) * N * CACHE_COLUMNS ||
        throw(DimensionMismatch("cached LLR binary size differs"))
    values = Vector{Float64}(undef, N * CACHE_COLUMNS)
    open(path, "r") do io
        read!(io, values)
        eof(io) || error("cached LLR binary has trailing bytes")
    end
    reshape(values, N, CACHE_COLUMNS)
end

function _write_target_llrs(path, llrs::Matrix{Float64})
    Base.ENDIAN_BOM == 0x04030201 ||
        error("packet Float64 encoding requires a little-endian host")
    open(path, "w") do io
        write(io, reinterpret(UInt8, vec(llrs)))
    end
end

function _load_adapter(path)
    isfile(path) || throw(ArgumentError("adapter is missing: $path"))
    realpath(path) == realpath(DEFAULT_ADAPTER) || throw(ArgumentError(
        "the trusted adapter path must be the frozen default: $DEFAULT_ADAPTER"))
    TrustedAdapter
end

function prepare(adapter_path::String, budget90_root::String, cache_root::String,
                 packet_root::String, receipt_root::String)
    Base.ENDIAN_BOM == 0x04030201 ||
        error("registered hashes require a little-endian host")
    packet = abspath(packet_root)
    receipt = abspath(receipt_root)
    packet == receipt && error("candidate packet and trusted receipt coincide")
    separator = string(Base.Filesystem.path_separator)
    (startswith(packet, receipt * separator) ||
     startswith(receipt, packet * separator)) &&
        error("candidate packet and trusted receipt must not be nested")
    require_empty_directory(packet)
    require_empty_directory(receipt)

    Adapter = _load_adapter(adapter_path)
    Adapter.registered_population_gate()
    source_pins = Dict(key => value for (key, value) in
        Adapter.Prep.BUDGET90_EVIDENCE_PINS if !startswith(key, "results/"))
    Adapter.Prep.verify_evidence_pins(budget90_root, source_pins)
    input_manifest = joinpath(budget90_root, INPUT_MANIFEST_RELATIVE_PATH)
    Adapter.Prep.verify_sha_manifest(input_manifest)
    sealed_path = joinpath(budget90_root, SEALED_RELATIVE_PATH)
    file_sha256(sealed_path) == SEALED_TABLE_SHA256 ||
        error("sealed Budget-90 table digest differs")
    sealed = read_csv(sealed_path)

    graph_source = joinpath(cache_root, "checks_i32_6_by_m.bin")
    llr_source = joinpath(cache_root, "llr_f64_n_by_400.bin")
    index_source = joinpath(cache_root, "index.csv")
    file_sha256(graph_source) == CACHE_GRAPH_BINARY_SHA256 ||
        error("cached graph binary digest differs")
    file_sha256(llr_source) == CACHE_LLR_SHA256 ||
        error("cached LLR binary digest differs")
    file_sha256(index_source) == CACHE_INDEX_SHA256 ||
        error("cached index digest differs")

    checks = _read_graph(graph_source)
    degrees = zeros(Int, N)
    for check in checks, bit in check
        1 <= bit <= N || error("graph contains an out-of-range bit")
        degrees[bit] += 1
    end
    all(==(3), degrees) || error("graph variable degree differs")
    all(length(check) == 6 for check in checks) ||
        error("graph check degree differs")
    graph_scientific_sha256 = Adapter.Prep.graph_identity(N, checks)
    graph_scientific_sha256 == REGISTERED_GRAPH_SHA256 ||
        error("graph scientific identity differs")

    full_llrs = _read_llrs(llr_source)
    cache_index = read_csv(index_source)
    target_llrs = Matrix{Float64}(undef, N, CASE_COUNT)
    allowed_header = String[
        "case_ordinal", "frame", "graph_sha256", "clipped_llr_sha256",
        "candidate_initial_b_sha256",
    ]
    allowed_rows = Vector{Vector{String}}()
    trusted_header = String[
        "case_ordinal", "frame", "source_stage", "source_channel",
        "cache_column", "cache_llr_sha256", "candidate_initial_b_sha256",
        "cache_llr_matches_sealed", "cache_llr_matches_regenerated",
    ]
    for field in IDENTITY_FIELDS
        append!(trusted_header,
                [field * "_sealed", field * "_regenerated", field * "_match"])
    end
    push!(trusted_header, "all_eight_identity_matches")
    trusted_rows = Vector{Vector{String}}()

    population = Adapter.PopulationSpec(
        "one_point_five_db", "one_point_five_db_transfer", "second_snr",
        "one_point_five_db", FRAME_FIRST, FRAME_LAST)
    tracker = Adapter.RegenerationTracker((population,))
    for (case_ordinal, frame) in enumerate(FRAME_FIRST:FRAME_LAST)
        column = CACHE_COLUMN_FIRST + case_ordinal - 1
        index_row = _unique_row(cache_index.rows,
            row -> parse(Int, row["column"]) == column,
            "cache index column $column")
        index_row["channel"] == SOURCE_CHANNEL ||
            error("cache channel differs at frame $frame")
        parse(Int, index_row["frame"]) == frame ||
            error("cache frame differs at column $column")
        index_row["sealed_match"] == "true" ||
            error("cache index sealed-match field differs at frame $frame")
        sealed_row = _unique_row(sealed.rows,
            row -> row["stage"] == SOURCE_STAGE &&
                   row["channel"] == SOURCE_CHANNEL &&
                   parse(Int, row["frame"]) == frame,
            "sealed identity $frame")
        cache_llr = view(full_llrs, :, column)
        cache_llr_hash = vector_sha256(cache_llr)
        cache_llr_hash == index_row["clipped_llr_sha256"] ||
            error("cache LLR hash differs from cache index at frame $frame")
        cache_llr_hash == sealed_row["clipped_llr_sha256"] ||
            error("cache LLR hash differs from sealed table at frame $frame")
        generated = Adapter.regenerate_case!(
            tracker, graph_scientific_sha256, SOURCE_STAGE, SOURCE_CHANNEL,
            frame; n=N)
        generated.llr == cache_llr ||
            error("regenerated LLR differs from cache at frame $frame")
        copyto!(view(target_llrs, :, case_ordinal), cache_llr)
        initial_hash = vector_sha256(initialize_state(Problem(checks, cache_llr)))
        push!(allowed_rows, String[
            string(case_ordinal), string(frame), graph_scientific_sha256,
            cache_llr_hash, initial_hash,
        ])
        trusted_row = String[
            string(case_ordinal), string(frame), SOURCE_STAGE, SOURCE_CHANNEL,
            string(column), cache_llr_hash, initial_hash, "true", "true",
        ]
        all_match = true
        for field in IDENTITY_FIELDS
            expected = sealed_row[field]
            actual = generated.identity[field]
            matched = expected == actual
            all_match &= matched
            append!(trusted_row, [expected, actual, bool_text(matched)])
        end
        all_match || error("eight-field identity gate failed at frame $frame")
        push!(trusted_row, "true")
        push!(trusted_rows, trusted_row)
    end
    Adapter.assert_complete_regeneration(tracker)

    graph_target = joinpath(packet, "checks_i32_6_by_m.bin")
    open(graph_target, "w") do io
        write(io, read(graph_source))
    end
    file_sha256(graph_target) == CACHE_GRAPH_BINARY_SHA256 ||
        error("packet graph copy digest differs")
    llr_target = joinpath(packet, "llr_f64_n_by_200.bin")
    _write_target_llrs(llr_target, target_llrs)
    write_csv(joinpath(packet, "case_index.csv"), allowed_header, allowed_rows)
    packet_config_rows = Vector{Vector{String}}([
        ["schema", PACKET_SCHEMA], ["experiment_id", EXPERIMENT_ID],
        ["case_count", string(CASE_COUNT)], ["frame_first", string(FRAME_FIRST)],
        ["frame_last", string(FRAME_LAST)], ["n", string(N)], ["m", string(M)],
        ["edge_count", "30600"], ["check_degree", "6"],
        ["variable_degree", "3"],
        ["graph_binary_sha256", file_sha256(graph_target)],
        ["graph_scientific_sha256", graph_scientific_sha256],
        ["llr_binary_sha256", file_sha256(llr_target)],
        ["llr_encoding", "Float64 little-endian n-by-case column-major"],
        ["truth_fields_present", "false"], ["comparison_decoder_fields_present", "false"],
    ])
    write_csv(joinpath(packet, "packet_config.csv"), ["field", "value"],
              packet_config_rows)
    packet_members = String[
        "case_index.csv", "checks_i32_6_by_m.bin", "llr_f64_n_by_200.bin",
        "packet_config.csv",
    ]
    packet_manifest = write_sha_manifest(packet, packet_members;
                                         filename="PACKET_MANIFEST.sha256")
    packet_ready = joinpath(packet, "PACKET_READY.txt")
    write_key_values(packet_ready, Pair{String,String}[
        "schema" => PACKET_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "case_count" => string(CASE_COUNT),
        "manifest_file" => basename(packet_manifest),
        "manifest_sha256" => file_sha256(packet_manifest),
        "truth_fields_present" => "false",
        "comparison_decoder_fields_present" => "false",
    ])

    write_csv(joinpath(receipt, "trusted_identity_receipt.csv"),
              trusted_header, trusted_rows)
    source_rows = Vector{Vector{String}}([
        ["schema", RECEIPT_SCHEMA], ["experiment_id", EXPERIMENT_ID],
        ["sealed_table_sha256", file_sha256(sealed_path)],
        ["input_manifest_sha256", file_sha256(input_manifest)],
        ["source_graph_binary_sha256", file_sha256(graph_source)],
        ["source_graph_scientific_sha256", graph_scientific_sha256],
        ["source_llr_cache_sha256", file_sha256(llr_source)],
        ["source_index_sha256", file_sha256(index_source)],
        ["adapter_sha256", file_sha256(adapter_path)],
        ["trusted_preparation_sha256", file_sha256(joinpath(
            dirname(adapter_path), "trusted_preparation.jl"))],
        ["packet_preparer_sha256", file_sha256(@__FILE__)],
        ["source_closure_commit", Adapter.SOURCE_CLOSURE_COMMIT],
        ["identity_case_count", string(length(trusted_rows))],
        ["all_eight_identity_matches", "true"],
        ["graph_degree_match", "true"],
        ["packet_manifest_sha256", file_sha256(packet_manifest)],
        ["outcome_files_opened", "false"],
    ])
    write_csv(joinpath(receipt, "trusted_source_receipt.csv"),
              ["field", "value"], source_rows)
    receipt_manifest = write_sha_manifest(receipt, String[
        "trusted_identity_receipt.csv", "trusted_source_receipt.csv",
    ]; filename="TRUSTED_RECEIPT_MANIFEST.sha256")
    receipt_ready = joinpath(receipt, "SOURCE_PREFLIGHT_COMPLETE.txt")
    write_key_values(receipt_ready, Pair{String,String}[
        "schema" => RECEIPT_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "case_count" => string(CASE_COUNT),
        "receipt_manifest_file" => basename(receipt_manifest),
        "receipt_manifest_sha256" => file_sha256(receipt_manifest),
        "packet_ready_sha256" => file_sha256(packet_ready),
        "packet_manifest_sha256" => file_sha256(packet_manifest),
        "all_eight_identity_matches" => "true",
        "outcome_files_opened" => "false",
    ])
    (; packet_ready, receipt_ready)
end

function parse_cli(args)
    options = Dict(
        "--adapter" => DEFAULT_ADAPTER,
        "--budget90-root" => DEFAULT_BUDGET90_ROOT,
        "--cache-root" => DEFAULT_CACHE_ROOT,
    )
    index = 1
    while index <= length(args)
        option = args[index]
        option in ("--adapter", "--budget90-root", "--cache-root",
                   "--packet-root", "--receipt-root") ||
            throw(ArgumentError("unknown option: $option"))
        index < length(args) || throw(ArgumentError("$option needs a value"))
        options[option] = args[index + 1]
        index += 2
    end
    for required in ("--packet-root", "--receipt-root")
        haskey(options, required) || throw(ArgumentError("$required is required"))
    end
    options
end

function main(args=ARGS)
    options = parse_cli(args)
    result = prepare(abspath(options["--adapter"]),
                     abspath(options["--budget90-root"]),
                     abspath(options["--cache-root"]),
                     abspath(options["--packet-root"]),
                     abspath(options["--receipt-root"]))
    println("PACKET_READY packet_ready_sha256=", file_sha256(result.packet_ready),
            " receipt_ready_sha256=", file_sha256(result.receipt_ready))
    nothing
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2ConvexParityDistancePacketPreparation.main()
end
