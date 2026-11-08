#!/usr/bin/env julia

module RQ2ConvexParityDistanceScorer

using ConvexParityDistance

include(joinpath(@__DIR__, "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-001"
const SCORE_SCHEMA = "rq2-convex-parity-distance-001/post-commit-score-v1"
const CASE_COUNT = 200
const FRAME_FIRST = 61969
const FRAME_LAST = 62168
const N = 10200
const M = 5100
const CHECKPOINTS = (30, 90, 300, 1000, 3000, 6000)
const DISTANCE_TOLERANCE = 1.0e-10
const INTEGRALITY_TOLERANCE = 1.0e-8
const CACHE_GRAPH_BINARY_SHA256 =
    "18b46e41ee01464498085aeebf98a1ae489058739255a5d4994cd93e4d89246c"

function _unique_row(rows, predicate, label::String)
    matches = filter(predicate, rows)
    length(matches) == 1 ||
        throw(ArgumentError("$label expected one row and found $(length(matches))"))
    only(matches)
end

function _read_graph(path::String)
    file_sha256(path) == CACHE_GRAPH_BINARY_SHA256 ||
        error("scorer graph binary digest differs")
    filesize(path) == sizeof(Int32) * 6 * M ||
        throw(DimensionMismatch("scorer graph binary size differs"))
    values = Vector{Int32}(undef, 6 * M)
    open(path, "r") do io
        read!(io, values)
        eof(io) || error("scorer graph has trailing bytes")
    end
    matrix = reshape(values, 6, M)
    checks = [Int.(matrix[:, check]) for check in 1:M]
    degrees = zeros(Int, N)
    for check in checks, bit in check
        1 <= bit <= N || error("scorer graph bit index is out of range")
        degrees[bit] += 1
    end
    all(==(3), degrees) || error("scorer graph variable degree differs")
    checks
end

function _candidate_commit_gate(candidate_root::String)
    commit_path = joinpath(candidate_root, "CANDIDATE_COMMITTED.txt")
    isfile(commit_path) || error("candidate commit marker is absent")
    commit = read_key_values(commit_path)
    commit["experiment_id"] == EXPERIMENT_ID ||
        error("candidate experiment ID differs")
    parse(Int, commit["case_count"]) == CASE_COUNT ||
        error("candidate case count differs")
    commit["scientific_replay_equal"] == "true" ||
        error("candidate scientific replay did not match")
    commit["telemetry_excluded_from_scientific_replay"] == "true" ||
        error("candidate replay included telemetry")
    commit["truth_used"] == "false" ||
        error("candidate claims truth was used")
    commit["bp_used"] == "false" ||
        error("candidate claims BP was used")
    manifest_name = commit["manifest_file"]
    file_sha256(joinpath(candidate_root, manifest_name)) ==
        commit["manifest_sha256"] || error("candidate manifest digest differs")
    verify_sha_manifest(candidate_root, manifest_name)
    commit
end

function _read_packed_record(io::IO, row)
    offset = parse(Int, row["byte_offset"])
    byte_count = parse(Int, row["byte_count"])
    bit_count = parse(Int, row["bit_count"])
    bit_count == N || error("hard-decision bit count differs")
    seek(io, offset)
    packed = read(io, byte_count)
    length(packed) == byte_count || error("hard-decision record is truncated")
    bytes_sha256(packed) == row["packed_sha256"] ||
        error("packed hard-decision digest differs")
    bits = unpack_bits(packed, bit_count)
    vector_sha256(bits) == row["hard_sha256"] ||
        error("unpacked hard-decision digest differs")
    bits
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

function _terminal_classification(case_row, trace_row, terminal_truth_equal::Bool,
                                  terminal_wrong_valid::Bool)
    case_row["stop_reason"] == "optimization_unresolved" &&
        return "optimization_unresolved"
    case_row["stop_reason"] == "numerical_global_optimum" ||
        return "unrecognized_stop_reason"
    maximum_distance = parse(Float64, trace_row["maximum_check_distance"])
    fractional = parse(Int, trace_row["fractional_1e_8_coordinates"])
    maximum_distance > DISTANCE_TOLERANCE &&
        return "finite_quadratic_penalty_limitation"
    fractional > 0 && return "fundamental_polytope_fractional_solution"
    terminal_truth_equal && return "transmitted_word_recovery"
    terminal_wrong_valid && return "linear_signal_selected_wrong_codeword"
    "tolerance_qualified_unclassified"
end

function _trusted_receipt_gate(receipt_root::String, packet_root::String,
                               candidate_commit)
    ready_path = joinpath(receipt_root, "SOURCE_PREFLIGHT_COMPLETE.txt")
    ready = read_key_values(ready_path)
    ready["experiment_id"] == EXPERIMENT_ID ||
        error("trusted receipt experiment ID differs")
    parse(Int, ready["case_count"]) == CASE_COUNT ||
        error("trusted receipt case count differs")
    ready["all_eight_identity_matches"] == "true" ||
        error("trusted receipt did not pass all identities")
    ready["outcome_files_opened"] == "false" ||
        error("trusted preparation opened outcome files")
    manifest = ready["receipt_manifest_file"]
    file_sha256(joinpath(receipt_root, manifest)) ==
        ready["receipt_manifest_sha256"] ||
        error("trusted receipt manifest digest differs")
    verify_sha_manifest(receipt_root, manifest; expected_members=String[
        "trusted_identity_receipt.csv", "trusted_source_receipt.csv",
    ])
    packet_ready = joinpath(packet_root, "PACKET_READY.txt")
    file_sha256(packet_ready) == ready["packet_ready_sha256"] ||
        error("trusted receipt packet-ready binding differs")
    packet_marker = read_key_values(packet_ready)
    packet_marker["manifest_sha256"] == ready["packet_manifest_sha256"] ||
        error("trusted receipt packet-manifest binding differs")
    candidate_commit["packet_ready_sha256"] == ready["packet_ready_sha256"] ||
        error("candidate used a different packet-ready marker")
    candidate_commit["packet_manifest_sha256"] ==
        ready["packet_manifest_sha256"] ||
        error("candidate used a different packet manifest")
    verify_sha_manifest(packet_root, packet_marker["manifest_file"])
    ready
end

function score(candidate_root::String, score_root::String, packet_root::String,
               receipt_root::String)
    # No truth object is constructed until the immutable candidate commit and
    # every candidate-manifest member have passed the gate above.
    commit = _candidate_commit_gate(candidate_root)
    receipt = _trusted_receipt_gate(receipt_root, packet_root, commit)
    output_root = require_empty_directory(score_root)
    checks = _read_graph(joinpath(packet_root, "checks_i32_6_by_m.bin"))

    case_table = read_csv(joinpath(candidate_root, "candidate_cases.csv"))
    trace_table = read_csv(joinpath(candidate_root, "candidate_trace.csv"))
    hard_table = read_csv(joinpath(candidate_root, "hard_decisions_index.csv"))
    preflight_table = read_csv(joinpath(receipt_root,
                                        "trusted_identity_receipt.csv"))
    length(case_table.rows) == CASE_COUNT || error("candidate case rows differ")
    length(preflight_table.rows) == CASE_COUNT ||
        error("candidate preflight row count differs")

    transmitted_word = falses(N)
    transmitted_word_sha256 = vector_sha256(transmitted_word)
    for row in preflight_table.rows
        row["transmitted_word_sha256_sealed"] == transmitted_word_sha256 ||
            error("post-commit all-zero truth does not match sealed identity")
        row["transmitted_word_sha256_match"] == "true" ||
            error("sealed transmitted-word identity did not regenerate")
        row["all_eight_identity_matches"] == "true" ||
            error("not all eight preflight identities matched")
    end

    hard_path = joinpath(candidate_root, "hard_decisions_packed.bin")
    hard_io = open(hard_path, "r")
    scored_hard_header = String[
        "case_ordinal", "frame", "update", "role", "hard_sha256",
        "candidate_syndrome_weight", "recomputed_syndrome_weight",
        "candidate_tie_count", "candidate_parity_valid", "coded_bit_errors",
        "transmitted_word_equal", "wrong_valid_codeword",
    ]
    scored_hard_rows = Vector{Vector{String}}()
    scored_by_key = Dict{Tuple{Int,String,Int},NamedTuple}()
    try
        ordered = sort(hard_table.rows; by=row -> parse(Int, row["byte_offset"]))
        next_offset = 0
        for row in ordered
            parse(Int, row["byte_offset"]) == next_offset ||
                error("hard-decision records are not contiguous")
            bits = _read_packed_record(hard_io, row)
            next_offset += parse(Int, row["byte_count"])
            case_ordinal = parse(Int, row["case_ordinal"])
            frame = parse(Int, row["frame"])
            update = parse(Int, row["update"])
            role = row["role"]
            1 <= case_ordinal <= CASE_COUNT || error("case ordinal is out of range")
            frame == FRAME_FIRST + case_ordinal - 1 ||
                error("case/frame mapping differs")
            recomputed_syndrome = _syndrome_weight(checks, bits)
            candidate_syndrome = parse(Int, row["syndrome_weight"])
            recomputed_syndrome == candidate_syndrome ||
                error("candidate syndrome differs from scorer recomputation")
            candidate_ties = parse(Int, row["tie_count"])
            candidate_valid = row["parity_valid"] == "true"
            candidate_valid == (recomputed_syndrome == 0 && candidate_ties == 0) ||
                error("candidate parity-valid field differs")
            bit_errors = count(identity, bits)
            truth_equal = bit_errors == 0
            wrong_valid = candidate_valid && !truth_equal
            key = (case_ordinal, role, update)
            haskey(scored_by_key, key) && error("hard-decision key repeats")
            scored_by_key[key] = (; bit_errors, truth_equal, wrong_valid,
                                   candidate_valid,
                                   hard_sha256=row["hard_sha256"])
            push!(scored_hard_rows, String[
                string(case_ordinal), string(frame), string(update), role,
                row["hard_sha256"], string(candidate_syndrome),
                string(recomputed_syndrome), string(candidate_ties),
                bool_text(candidate_valid), string(bit_errors),
                bool_text(truth_equal), bool_text(wrong_valid),
            ])
        end
        next_offset == filesize(hard_path) ||
            error("hard-decision binary contains unindexed bytes")
    finally
        close(hard_io)
    end

    scored_case_header = String[
        "case_ordinal", "frame", "first_valid_update", "terminal_update",
        "stop_reason", "latched_coded_bit_errors", "terminal_coded_bit_errors",
        "latched_transmitted_word_equal", "terminal_transmitted_word_equal",
        "latched_wrong_valid_codeword", "terminal_wrong_valid_codeword",
        "terminal_classification",
    ]
    append!(scored_case_header,
            ["recovered_at_$(checkpoint)" for checkpoint in CHECKPOINTS])
    scored_case_rows = Vector{Vector{String}}()
    recovery_counts = Dict(checkpoint => 0 for checkpoint in CHECKPOINTS)
    classification_counts = Dict{String,Int}()

    for case_ordinal in 1:CASE_COUNT
        frame = FRAME_FIRST + case_ordinal - 1
        case_row = _unique_row(case_table.rows,
            row -> parse(Int, row["case_ordinal"]) == case_ordinal,
            "candidate case $case_ordinal")
        terminal_update = parse(Int, case_row["terminal_update"])
        terminal_key = (case_ordinal, "terminal", terminal_update)
        haskey(scored_by_key, terminal_key) ||
            error("terminal hard decision is missing at case $case_ordinal")
        terminal = scored_by_key[terminal_key]
        trace_row = _unique_row(trace_table.rows,
            row -> parse(Int, row["case_ordinal"]) == case_ordinal &&
                   row["row_kind"] == "checkpoint_terminal",
            "terminal trace $case_ordinal")

        first_valid_text = case_row["first_valid_update"]
        first_valid = isempty(first_valid_text) ? nothing : parse(Int, first_valid_text)
        latched = nothing
        if first_valid !== nothing
            key = (case_ordinal, "latched", first_valid)
            haskey(scored_by_key, key) ||
                error("latched hard decision is missing at case $case_ordinal")
            latched = scored_by_key[key]
            latched.candidate_valid || error("latched decision is not valid")
            latched.hard_sha256 == case_row["latched_hard_sha256"] ||
                error("latched decision hash differs from case table")
        else
            isempty(case_row["latched_hard_sha256"]) ||
                error("case table has an unlabeled latched hash")
        end
        terminal.hard_sha256 == case_row["terminal_hard_sha256"] ||
            error("terminal decision hash differs from case table")

        classification = _terminal_classification(
            case_row, trace_row, terminal.truth_equal, terminal.wrong_valid)
        classification_counts[classification] =
            get(classification_counts, classification, 0) + 1
        checkpoint_values = String[]
        for checkpoint in CHECKPOINTS
            recovered = first_valid !== nothing && first_valid <= checkpoint &&
                        latched.truth_equal
            recovery_counts[checkpoint] += recovered
            push!(checkpoint_values, bool_text(recovered))
        end
        push!(scored_case_rows, vcat(String[
            string(case_ordinal), string(frame),
            first_valid === nothing ? "" : string(first_valid),
            string(terminal_update), case_row["stop_reason"],
            latched === nothing ? "" : string(latched.bit_errors),
            string(terminal.bit_errors),
            latched === nothing ? "" : bool_text(latched.truth_equal),
            bool_text(terminal.truth_equal),
            latched === nothing ? "" : bool_text(latched.wrong_valid),
            bool_text(terminal.wrong_valid), classification,
        ], checkpoint_values))
    end

    write_csv(joinpath(output_root, "scored_hard_decisions.csv"),
              scored_hard_header, scored_hard_rows)
    write_csv(joinpath(output_root, "scored_cases.csv"),
              scored_case_header, scored_case_rows)
    summary_rows = Vector{Vector{String}}([
        ["schema", SCORE_SCHEMA], ["experiment_id", EXPERIMENT_ID],
        ["candidate_commit_sha256", file_sha256(joinpath(
            candidate_root, "CANDIDATE_COMMITTED.txt"))],
        ["candidate_manifest_sha256", commit["manifest_sha256"]],
        ["candidate_scientific_trace_sha256",
         commit["scientific_trace_sha256"]],
        ["case_count", string(CASE_COUNT)],
        ["truth_model", "registered_all_zero_word"],
        ["transmitted_word_sha256", transmitted_word_sha256],
        ["trusted_receipt_sha256", file_sha256(joinpath(
            receipt_root, "SOURCE_PREFLIGHT_COMPLETE.txt"))],
        ["trusted_receipt_manifest_sha256",
         receipt["receipt_manifest_sha256"]],
        ["scorer_sha256", file_sha256(@__FILE__)],
        ["bp_opened_or_run", "false"],
    ])
    for checkpoint in CHECKPOINTS
        push!(summary_rows,
              ["recoveries_at_$(checkpoint)", string(recovery_counts[checkpoint])])
    end
    for classification in sort!(collect(keys(classification_counts)))
        push!(summary_rows,
              ["terminal_" * classification,
               string(classification_counts[classification])])
    end
    write_csv(joinpath(output_root, "score_summary.csv"),
              ["field", "value"], summary_rows)

    members = String[
        "score_summary.csv", "scored_cases.csv", "scored_hard_decisions.csv",
    ]
    manifest = write_sha_manifest(output_root, members;
                                  filename="SCORE_MANIFEST.sha256")
    score_commit = joinpath(output_root, "SCORE_COMMITTED.txt")
    write_key_values(score_commit, Pair{String,String}[
        "schema" => "rq2-convex-parity-distance-001/score-commit-v1",
        "experiment_id" => EXPERIMENT_ID,
        "case_count" => string(CASE_COUNT),
        "candidate_commit_sha256" => file_sha256(joinpath(
            candidate_root, "CANDIDATE_COMMITTED.txt")),
        "candidate_manifest_sha256" => commit["manifest_sha256"],
        "score_manifest_file" => basename(manifest),
        "score_manifest_sha256" => file_sha256(manifest),
        "truth_opened_after_candidate_commit" => "true",
        "bp_used" => "false",
    ])
    (; score_commit, recovery_counts, classification_counts)
end

function parse_cli(args)
    options = Dict{String,String}()
    index = 1
    while index <= length(args)
        option = args[index]
        option in ("--candidate-root", "--score-root", "--packet-root",
                   "--receipt-root") ||
            throw(ArgumentError("unknown option: $option"))
        index < length(args) || throw(ArgumentError("$option needs a value"))
        options[option] = args[index + 1]
        index += 2
    end
    for required in ("--candidate-root", "--score-root", "--packet-root",
                     "--receipt-root")
        haskey(options, required) || throw(ArgumentError("$required is required"))
    end
    options
end

function main(args=ARGS)
    options = parse_cli(args)
    result = score(abspath(options["--candidate-root"]),
                   abspath(options["--score-root"]),
                   abspath(options["--packet-root"]),
                   abspath(options["--receipt-root"]))
    println("SCORE_COMMITTED score_commit_sha256=",
            file_sha256(result.score_commit))
    nothing
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2ConvexParityDistanceScorer.main()
end
