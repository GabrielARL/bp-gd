using Test
using SHA
using ConvexParityDistance

if !isdefined(@__MODULE__, :RQ2ConvexParityDistanceSNRThresholdScorer)
    include(joinpath(@__DIR__, "..", "execution", "score_candidate.jl"))
end
const Scorer = RQ2ConvexParityDistanceSNRThresholdScorer
const AIO = Scorer.ConvexParityDistanceArtifactIO
const SYNTHETIC_ACTIVATION_SHA256 = repeat("e", 64)

function _synthetic_activation(; sha256=SYNTHETIC_ACTIVATION_SHA256,
                               snrs=[6.0, 6.5])
    Scorer.StageActivation(
        "/synthetic/fine-activation.toml", sha256, "fine", Float64.(snrs),
        1, 2, 30, Dict{String,String}(), 6.5, repeat("a", 64),
        repeat("b", 64))
end

function _write_graph(path, checks)
    open(path, "w") do io
        for check in checks, bit in check
            write(io, htol(Int32(bit)))
        end
    end
end
function _write_f64_le(path, values)
    open(path, "w") do io
        for value in values
            write(io, htol(reinterpret(UInt64, Float64(value))))
        end
    end
end

function _hard_record!(io, rows, ordinal, snr, frame, role, update, bits,
                       syndrome, ties, valid)
    packed = AIO.pack_bits(bits)
    offset = position(io)
    write(io, packed)
    push!(rows, String[
        string(ordinal), "fine", repr(snr), string(frame), role,
        string(update), string(offset), string(length(packed)),
        string(length(bits)), ConvexParityDistance.vector_sha256(bits),
        AIO.bytes_sha256(packed), string(syndrome), string(ties),
        AIO.bool_text(valid),
    ])
end

function _fixture(root)
    packet = joinpath(root, "packet")
    candidate = joinpath(root, "candidate")
    mkpath(packet); mkpath(candidate)
    checks = [collect(1:6) for _ in 1:3]
    activation = _synthetic_activation()
    graph_path = joinpath(packet, "checks_i32_6_by_m.bin")
    _write_graph(graph_path, checks)
    graph_hash = Scorer._graph_identity(checks)
    snrs = [6.0, 6.5]
    frames = [1, 2]
    llrs = Matrix{Float64}(undef, 6, 4)
    case_rows = Vector{Vector{String}}()
    ordinal = 0
    for snr in snrs, frame in frames
        ordinal += 1
        llrs[:, ordinal] .= [snr, frame, 0.2, -0.1, 0.3, -0.2]
        push!(case_rows, String[
            string(ordinal), string(frame), repr(snr), string(100 + frame),
            graph_hash, ConvexParityDistance.vector_sha256(view(llrs, :, ordinal)),
        ])
    end
    llr_path = joinpath(packet, "llr_f64_n_by_case.bin")
    _write_f64_le(llr_path, vec(llrs))
    AIO.write_csv(joinpath(packet, "case_index.csv"),
                  ["case_ordinal", "frame", "physical_esn0_db", "noise_seed",
                   "graph_sha256", "clipped_llr_sha256"], case_rows)
    AIO.write_csv(joinpath(packet, "snr_grid.csv"),
                  ["snr_ordinal", "physical_esn0_db"],
                  [[string(index), repr(snr)] for (index, snr) in enumerate(snrs)])
    AIO.write_csv(joinpath(packet, "packet_config.csv"), ["field", "value"],
                  Vector{Vector{String}}([
                      ["schema", Scorer.PACKET_SCHEMA],
                      ["experiment_id", Scorer.EXPERIMENT_ID],
                      ["stage", "fine"],
                      ["activation_sha256", activation.sha256],
                      ["case_count", "4"],
                      ["case_order", "ascending SNR outer, ascending frame inner"],
                      ["snr_count", "2"], ["frame_first", "1"],
                      ["frame_last", "2"],
                      ["n", "6"], ["m", "3"],
                      ["edge_count", "18"], ["check_degree", "6"],
                      ["variable_degree", "3"],
                      ["graph_binary_sha256", AIO.file_sha256(graph_path)],
                      ["graph_scientific_sha256", graph_hash],
                      ["llr_binary_sha256", AIO.file_sha256(llr_path)],
                      ["llr_encoding", "Float64 little-endian n-by-case column-major"],
                      ["adapter_sha256", "synthetic-adapter"],
                      ["archived_generator_sha256", "synthetic-generator"],
                      ["archived_config_sha256", "synthetic-config"],
                      ["retained_split_config_sha256", "synthetic-split-config"],
                      ["unit_noise_reused_by_frame_across_snr", "true"],
                      ["truth_fields_present", "false"],
                      ["comparison_decoder_fields_present", "false"],
                  ]))
    packet_members = String[
        "case_index.csv", "checks_i32_6_by_m.bin", "llr_f64_n_by_case.bin",
        "packet_config.csv", "snr_grid.csv",
    ]
    packet_manifest = AIO.write_sha_manifest(
        packet, packet_members; filename="PACKET_MANIFEST.sha256")
    packet_ready = joinpath(packet, "PACKET_READY.txt")
    AIO.write_key_values(packet_ready, Pair{String,String}[
        "schema" => Scorer.PACKET_SCHEMA, "experiment_id" => Scorer.EXPERIMENT_ID,
        "stage" => "fine", "activation_sha256" => activation.sha256,
        "case_count" => "4",
        "manifest_file" => basename(packet_manifest),
        "manifest_sha256" => AIO.file_sha256(packet_manifest),
        "truth_fields_present" => "false",
        "comparison_decoder_fields_present" => "false",
    ])

    terminal_bits = BitVector[
        falses(6), trues(6), BitVector([true, false, false, false, false, false]),
        falses(6),
    ]
    first_valid = [1, 1, 0, 30]
    trace_header = Scorer.TRACE_HEADER
    trace_rows = Vector{Vector{String}}()
    hard_header = Scorer.HARD_INDEX_HEADER
    hard_rows = Vector{Vector{String}}()
    case_header = Scorer.CASE_HEADER
    candidate_rows = Vector{Vector{String}}()
    state_rows = Vector{Vector{String}}()
    state_io = IOBuffer()
    hard_io = IOBuffer()
    for ordinal in 1:4
        snr = parse(Float64, case_rows[ordinal][3])
        frame = parse(Int, case_rows[ordinal][2])
        final = terminal_bits[ordinal]
        final_syndrome = Scorer._syndrome_weight(checks, final)
        local_trace = Vector{Vector{String}}()
        terminal_state = fill(ordinal / 10, 6)
        terminal_state_hash = ConvexParityDistance.vector_sha256(terminal_state)
        for update in 1:30
            valid_now = first_valid[ordinal] > 0 && update >= first_valid[ordinal]
            bits = valid_now ? final : BitVector([true, false, false, false, false, false])
            syndrome = Scorer._syndrome_weight(checks, bits)
            valid = syndrome == 0
            state_hash = update == 30 ? terminal_state_hash :
                bytes2hex(sha256("state-$ordinal-$update"))
            row = String[
                string(ordinal), "fine", repr(snr), string(frame), string(update),
                string(ordinal + update / 100), string((ordinal + update / 100) / 6),
                "0.003", "1.0", "0.5", "0.001", "0.0", "1.0", "0.0", "1.0",
                "0.0", "1.0", state_hash,
                ConvexParityDistance.vector_sha256(bits), string(syndrome), "0",
                AIO.bool_text(valid),
                AIO.bool_text(first_valid[ordinal] == update),
                valid_now ? string(first_valid[ordinal]) : "",
            ]
            push!(trace_rows, row)
            push!(local_trace, row)
        end
        if first_valid[ordinal] > 0
            _hard_record!(hard_io, hard_rows, ordinal, snr, frame, "latched",
                          first_valid[ordinal], final, 0, 0, true)
        end
        _hard_record!(hard_io, hard_rows, ordinal, snr, frame, "terminal", 30,
                      final, final_syndrome, 0, final_syndrome == 0)
        state_bytes = IOBuffer()
        for value in terminal_state
            write(state_bytes, htol(reinterpret(UInt64, value)))
        end
        bytes = take!(state_bytes)
        offset = position(state_io)
        write(state_io, bytes)
        push!(state_rows, String[
            string(ordinal), "fine", repr(snr), string(frame), "terminal", "30",
            string(offset), string(length(bytes)), "6", terminal_state_hash,
        ])
        hard_hash = ConvexParityDistance.vector_sha256(final)
        push!(candidate_rows, String[
            string(ordinal), "fine", repr(snr), string(frame),
            case_rows[ordinal][4], case_rows[ordinal][6],
            bytes2hex(sha256("initial-state-$ordinal")),
            first_valid[ordinal] == 0 ? "" : string(first_valid[ordinal]),
            first_valid[ordinal] == 0 ? "" : hard_hash, "30",
            terminal_state_hash, hard_hash,
            string(final_syndrome), "0", AIO.bool_text(final_syndrome == 0),
            string(ordinal), string(ordinal / 6), "0.1", "0.01", "0.9", "0.09",
            "0.001", "0.002", "1", "1", "0.003",
            AIO.bytes_sha256(AIO.csv_bytes(trace_header, local_trace)),
        ])
    end
    AIO.write_csv(joinpath(candidate, "candidate_trace.csv"), trace_header, trace_rows)
    AIO.write_csv(joinpath(candidate, "candidate_cases.csv"), case_header,
                  candidate_rows)
    AIO.write_csv(joinpath(candidate, "final_states_index.csv"),
                  Scorer.STATE_INDEX_HEADER, state_rows)
    open(joinpath(candidate, "final_states_f64_le.bin"), "w") do io
        write(io, take!(state_io))
    end
    AIO.write_csv(joinpath(candidate, "hard_decisions_index.csv"), hard_header,
                  hard_rows)
    open(joinpath(candidate, "hard_decisions_packed.bin"), "w") do io
        write(io, take!(hard_io))
    end
    AIO.write_csv(joinpath(candidate, "candidate_telemetry.csv"),
                  ["case_ordinal", "stage", "snr_db", "frame",
                   "primary_runtime_ns", "replay_runtime_ns",
                   "primary_allocated_bytes", "replay_allocated_bytes",
                   "primary_gc_runtime_ns", "replay_gc_runtime_ns",
                   "primary_process_maxrss", "replay_process_maxrss"],
                  [[string(index), "fine", case_rows[index][3], case_rows[index][2],
                    "1", "1", "2", "2", "0", "0", "3", "3"]
                   for index in 1:4])
    runner_path = joinpath(@__DIR__, "..", "execution", "candidate_runner.jl")
    AIO.write_csv(joinpath(candidate, "candidate_config.csv"), ["field", "value"],
                  Vector{Vector{String}}([
                      ["schema", Scorer.EXECUTION_SCHEMA],
                      ["experiment_id", Scorer.EXPERIMENT_ID], ["stage", "fine"],
                      ["case_count", "4"],
                      ["activation_sha256", activation.sha256],
                      ["update_cap", "30"],
                      ["parity_weight", "96.0"], ["global_curvature", "1.0"],
                      ["tie_tolerance", "1.0e-12"],
                      ["distance_tolerance", "1.0e-10"],
                      ["registered_graph_sha256", Scorer.REGISTERED_GRAPH_SHA256],
                      ["graph_binary_sha256", AIO.file_sha256(graph_path)],
                      ["llr_binary_sha256", AIO.file_sha256(llr_path)],
                      ["packet_ready_sha256", AIO.file_sha256(packet_ready)],
                      ["packet_manifest_sha256", AIO.file_sha256(packet_manifest)],
                      ["objective_source_sha256", Scorer.OBJECTIVE_SOURCE_SHA256],
                      ["accelerated_source_sha256", Scorer.ACCELERATED_SOURCE_SHA256],
                      ["candidate_runner_sha256", AIO.file_sha256(runner_path)],
                      ["julia_version", string(VERSION)], ["julia_threads", "1"],
                      ["blas_threads", "1"],
                      ["truth_used", "false"], ["bp_used", "false"],
                      ["telemetry_in_scientific_digest", "false"],
                  ]))
    AIO.write_csv(joinpath(candidate, "replay_verification.csv"),
                  ["field", "primary", "replay", "equal"],
                  [["scientific_trace_sha256", "PENDING", "PENDING", "true"]])
    candidate_members = String[
        Scorer.CANDIDATE_MEMBERS...,
    ]
    science_hash = Scorer._retained_science_digest(candidate)
    AIO.write_csv(joinpath(candidate, "replay_verification.csv"),
                  ["field", "primary", "replay", "equal"],
                  [["scientific_trace_sha256", science_hash, science_hash, "true"]])
    candidate_manifest = AIO.write_sha_manifest(
        candidate, candidate_members; filename="CANDIDATE_MANIFEST.sha256")
    commit_path = joinpath(candidate, "CANDIDATE_COMMITTED.txt")
    AIO.write_key_values(commit_path, Pair{String,String}[
        "schema" => Scorer.COMMIT_SCHEMA,
        "experiment_id" => Scorer.EXPERIMENT_ID, "stage" => "fine",
        "activation_sha256" => activation.sha256,
        "case_count" => "4", "manifest_file" => basename(candidate_manifest),
        "manifest_sha256" => AIO.file_sha256(candidate_manifest),
        "packet_ready_sha256" => AIO.file_sha256(packet_ready),
        "packet_manifest_sha256" => AIO.file_sha256(packet_manifest),
        "scientific_trace_sha256" => science_hash,
        "replay_scientific_trace_sha256" => science_hash,
        "scientific_replay_equal" => "true",
        "telemetry_excluded_from_scientific_replay" => "true",
        "candidate_outcome_committed" => "true", "truth_used" => "false",
        "bp_used" => "false",
    ])
    (; activation, packet, candidate, checks, llrs, cases=case_rows, commit_path)
end

function _backend(fixture, calls)
    regenerate = function (snr, frame)
        calls[] += 1
        ordinal = findfirst(row -> parse(Float64, row[3]) == snr &&
                                   parse(Int, row[2]) == frame, fixture.cases)
        llr = Vector{Float64}(view(fixture.llrs, :, ordinal))
        (; llr, noise_seed=parse(Int, fixture.cases[ordinal][4]),
           graph_sha256=fixture.cases[ordinal][5], transmitted_bits=falses(6),
           clipped_llr_sha256=fixture.cases[ordinal][6])
    end
    decode_bp = llr -> (; hard=falses(6), syndrome_weight=0, parity_valid=true,
                         iterations=2)
    receipt = (; adapter_sha256="synthetic", config_sha256="synthetic",
               source_gate_passed=true,
               bp_rule="synthetic exact comparator for scorer unit test")
    () -> (; regenerate, decode_bp, receipt)
end

function _write_table(path, table)
    AIO.write_csv(path, table.header,
                  [[row[field] for field in table.header] for row in table.rows])
end

function _rewrite_commit(fixture, updates=Dict{String,String}())
    commit = AIO.read_key_values(fixture.commit_path)
    merge!(commit, updates)
    AIO.write_key_values(fixture.commit_path,
                         [key => commit[key] for key in sort!(collect(keys(commit)))])
end

function _rebind_candidate!(fixture; recompute_science::Bool)
    updates = Dict{String,String}()
    if recompute_science
        digest = Scorer._retained_science_digest(fixture.candidate)
        AIO.write_csv(joinpath(fixture.candidate, "replay_verification.csv"),
                      ["field", "primary", "replay", "equal"],
                      [["scientific_trace_sha256", digest, digest, "true"]])
        updates["scientific_trace_sha256"] = digest
        updates["replay_scientific_trace_sha256"] = digest
    end
    manifest = AIO.write_sha_manifest(
        fixture.candidate, Scorer.CANDIDATE_MEMBERS;
        filename=Scorer.CANDIDATE_MANIFEST)
    updates["manifest_sha256"] = AIO.file_sha256(manifest)
    _rewrite_commit(fixture, updates)
end

function _gate_without_backend(fixture, root; activation=fixture.activation)
    calls = Ref(0)
    loader = () -> begin
        calls[] += 1
        error("backend must remain closed")
    end
    outcome = try
        Scorer.score_with_backend_for_synthetic_test(
            activation, fixture.packet, fixture.candidate,
            joinpath(root, "score"), loader,
            Val(:synthetic_test_only))
        nothing
    catch error
        error
    end
    (; outcome, calls=calls[])
end

@testset "activation mismatch fails before packet and backend access" begin
    mktempdir() do root
        fixture = _fixture(root)
        wrong_activation = _synthetic_activation(sha256=repeat("f", 64))
        result = _gate_without_backend(
            fixture, root; activation=wrong_activation)
        @test result.outcome isa Exception
        @test occursin("packet marker activation hash differs",
                       sprint(showerror, result.outcome))
        @test result.calls == 0
    end
end

@testset "production scorer CLI requires activation first" begin
    error = try
        Scorer.run_cli(["packet", "candidate", "score"])
        nothing
    catch caught
        caught
    end
    @test error isa Exception
    @test occursin("ACTIVATION PACKET_ROOT CANDIDATE_ROOT SCORE_ROOT",
                   sprint(showerror, error))
end

@testset "post-commit synthetic scoring" begin
    mktempdir() do root
        fixture = _fixture(root)
        calls = Ref(0)
        score_root = joinpath(root, "score")
        result = Scorer.score_with_backend_for_synthetic_test(
            fixture.activation, fixture.packet, fixture.candidate, score_root,
            _backend(fixture, calls), Val(:synthetic_test_only))
        @test calls[] == 4
        @test length(result.scored) == 4
        @test [item.candidate_recovered for item in result.scored] ==
              [true, false, false, true]
        @test [item.candidate_wrong_valid for item in result.scored] ==
              [false, true, false, false]
        @test all(item.bp_recovered for item in result.scored)
        @test isfile(joinpath(score_root, "SCORE_COMMITTED.txt"))
        @test AIO.verify_sha_manifest(score_root, "SCORE_MANIFEST.sha256")
        summary = AIO.read_csv(joinpath(score_root, "snr_summary.csv"))
        @test length(summary.rows) == 2
        @test summary.rows[1]["candidate_recoveries"] == "1"
        @test summary.rows[1]["bp_recoveries"] == "2"
        receipt = AIO.read_csv(joinpath(score_root, "scorer_source_receipt.csv"))
        fields = Set(row["field"] for row in receipt.rows)
        @test "retained_split_config_sha256" in fields
        @test "retained_split_runner_sha256" in fields
        @test "archived_generator_sha256" in fields
        @test "jade_package_source_sha256" in fields
        @test "candidate_scientific_trace_sha256" in fields
        @test "activation_sha256" in fields
        threshold = AIO.read_key_values(joinpath(score_root, "threshold_summary.txt"))
        @test threshold["activation_sha256"] == fixture.activation.sha256
        commit = AIO.read_key_values(joinpath(score_root, "SCORE_COMMITTED.txt"))
        @test commit["activation_sha256"] == fixture.activation.sha256
    end
end

@testset "backend is not loaded before candidate gate" begin
    mktempdir() do root
        fixture = _fixture(root)
        commit = AIO.read_key_values(fixture.commit_path)
        entries = Pair{String,String}[key =>
            (key == "scientific_replay_equal" ? "false" : value)
            for (key, value) in sort!(collect(commit); by=first)]
        AIO.write_key_values(fixture.commit_path, entries)
        calls = Ref(0)
        loader = () -> begin
            calls[] += 1
            error("backend must remain closed")
        end
        @test_throws ErrorException Scorer.score_with_backend_for_synthetic_test(
            fixture.activation, fixture.packet, fixture.candidate,
            joinpath(root, "score"), loader,
            Val(:synthetic_test_only))
        @test calls[] == 0
    end
end

@testset "coarse crossing is provisional, never stable" begin
    rows = NamedTuple[]
    for (snr, candidate_count) in ((6.0, 19), (6.5, 20), (7.0, 21))
        for index in 1:24
            push!(rows, (; snr, candidate_recovered=index <= candidate_count,
                           bp_recovered=true))
        end
    end
    summaries = Scorer.summarize_snr(rows, "coarse")
    crossings = Scorer._threshold_crossings(summaries, "coarse")
    @test crossings.lowest_target == "6.5"
    @test crossings.provisional_coarse == "6.5"
    @test crossings.stable_working == ""
end

@testset "fine-grid stable suffix rule" begin
    rows = NamedTuple[]
    for (snr, candidate_count) in ((5.0, 169), (5.1, 170), (5.2, 171))
        for index in 1:200
            push!(rows, (; snr, candidate_recovered=index <= candidate_count,
                           bp_recovered=true))
        end
    end
    summaries = Scorer.summarize_snr(rows, "fine")
    @test [summary.passed for summary in summaries] == [false, true, true]
    @test [summary.stable_suffix_pass for summary in summaries] ==
          [false, true, true]
    @test summaries[2].deficit == -30
end


@testset "packet and candidate marker schemas are exact pre-backend gates" begin
    for (which, marker_name, key) in
            ((:packet, "PACKET_READY.txt", "schema"),
             (:candidate, "CANDIDATE_COMMITTED.txt", "schema"))
        mktempdir() do root
            fixture = _fixture(root)
            marker = which == :packet ? joinpath(fixture.packet, marker_name) :
                joinpath(fixture.candidate, marker_name)
            values = AIO.read_key_values(marker)
            values[key] = "tampered-schema"
            AIO.write_key_values(marker,
                                 [name => values[name]
                                  for name in sort!(collect(keys(values)))])
            result = _gate_without_backend(fixture, root)
            @test result.outcome isa Exception
            @test result.calls == 0
        end
    end
end

@testset "artifact directory allowlists reject unregistered members" begin
    for which in (:packet, :candidate)
        mktempdir() do root
            fixture = _fixture(root)
            target = which == :packet ? fixture.packet : fixture.candidate
            write(joinpath(target, "unregistered.txt"), "tamper")
            result = _gate_without_backend(fixture, root)
            @test result.outcome isa Exception
            @test result.calls == 0
        end
    end
end

@testset "packet and candidate manifests have exact member allowlists" begin
    for which in (:packet, :candidate)
        mktempdir() do root
            fixture = _fixture(root)
            if which == :packet
                AIO.write_key_values(joinpath(fixture.packet, "unregistered.txt"),
                                     ["tamper" => "true"])
                manifest = AIO.write_sha_manifest(
                    fixture.packet, vcat(Scorer.PACKET_MEMBERS, ["unregistered.txt"]);
                    filename=Scorer.PACKET_MANIFEST)
                marker_path = joinpath(fixture.packet, "PACKET_READY.txt")
                marker = AIO.read_key_values(marker_path)
                marker["manifest_sha256"] = AIO.file_sha256(manifest)
                AIO.write_key_values(marker_path,
                                     [key => marker[key]
                                      for key in sort!(collect(keys(marker)))])
            else
                AIO.write_key_values(joinpath(fixture.candidate, "unregistered.txt"),
                                     ["tamper" => "true"])
                manifest = AIO.write_sha_manifest(
                    fixture.candidate,
                    vcat(Scorer.CANDIDATE_MEMBERS, ["unregistered.txt"]);
                    filename=Scorer.CANDIDATE_MANIFEST)
                _rewrite_commit(fixture,
                    Dict("manifest_sha256" => AIO.file_sha256(manifest)))
            end
            result = _gate_without_backend(fixture, root)
            @test result.outcome isa Exception
            @test occursin("manifest member set differs",
                           sprint(showerror, result.outcome))
            @test result.calls == 0
        end
    end
end

@testset "committed science digest is recomputed from retained artifacts" begin
    mktempdir() do root
        fixture = _fixture(root)
        path = joinpath(fixture.candidate, "candidate_trace.csv")
        table = AIO.read_csv(path)
        table.rows[1]["objective"] = "999.0"
        _write_table(path, table)
        _rebind_candidate!(fixture; recompute_science=false)
        result = _gate_without_backend(fixture, root)
        @test result.outcome isa Exception
        @test occursin("committed scientific digest", sprint(showerror, result.outcome))
        @test result.calls == 0
    end
end

@testset "candidate noise seed is bound to the packet" begin
    mktempdir() do root
        fixture = _fixture(root)
        path = joinpath(fixture.candidate, "candidate_cases.csv")
        table = AIO.read_csv(path)
        table.rows[1]["noise_seed"] = "999999"
        _write_table(path, table)
        _rebind_candidate!(fixture; recompute_science=true)
        result = _gate_without_backend(fixture, root)
        @test result.outcome isa Exception
        @test occursin("noise seed", sprint(showerror, result.outcome))
        @test result.calls == 0
    end
end

@testset "terminal state is bound to the update-30 trace" begin
    mktempdir() do root
        fixture = _fixture(root)
        path = joinpath(fixture.candidate, "candidate_cases.csv")
        table = AIO.read_csv(path)
        table.rows[1]["terminal_state_sha256"] = repeat("0", 64)
        _write_table(path, table)
        _rebind_candidate!(fixture; recompute_science=true)
        result = _gate_without_backend(fixture, root)
        @test result.outcome isa Exception
        @test occursin("update-30 trace", sprint(showerror, result.outcome))
        @test result.calls == 0
    end
end

@testset "independent wrong-valid and tie gates" begin
    clean = [
        (; snr=7.0, candidate_recovered=true, bp_recovered=true,
           candidate_wrong_valid=false, trace_tie_coordinates=0),
    ]
    wrong = [
        (; snr=7.0, candidate_recovered=true, bp_recovered=true,
           candidate_wrong_valid=true, trace_tie_coordinates=0),
    ]
    tied = [
        (; snr=7.0, candidate_recovered=true, bp_recovered=true,
           candidate_wrong_valid=false, trace_tie_coordinates=1),
    ]
    clean_summary = only(Scorer.summarize_snr(clean, "fine"))
    wrong_summary = only(Scorer.summarize_snr(wrong, "fine"))
    tied_summary = only(Scorer.summarize_snr(tied, "fine"))
    @test clean_summary.count_pass && clean_summary.passed
    @test wrong_summary.count_pass && !wrong_summary.wrong_valid_gate_pass
    @test !wrong_summary.passed
    @test tied_summary.count_pass && !tied_summary.tie_gate_pass
    @test !tied_summary.passed
end

@testset "candidate update-cap gate precedes backend" begin
    mktempdir() do root
        fixture = _fixture(root)
        config_path = joinpath(fixture.candidate, "candidate_config.csv")
        config_table = AIO.read_csv(config_path)
        for row in config_table.rows
            row["field"] == "update_cap" && (row["value"] = "31")
        end
        AIO.write_csv(config_path, config_table.header,
                      [[row[field] for field in config_table.header]
                       for row in config_table.rows])
        # Rebind the manifest and commit so the test reaches the semantic gate.
        manifest_path = joinpath(fixture.candidate, "CANDIDATE_MANIFEST.sha256")
        members = collect(Scorer._manifest_members(manifest_path))
        AIO.write_sha_manifest(fixture.candidate, members;
                              filename="CANDIDATE_MANIFEST.sha256")
        commit = AIO.read_key_values(fixture.commit_path)
        commit["manifest_sha256"] = AIO.file_sha256(manifest_path)
        AIO.write_key_values(fixture.commit_path,
                             [key => commit[key] for key in sort!(collect(keys(commit)))])
        calls = Ref(0)
        loader = () -> begin
            calls[] += 1
            error("backend must remain closed")
        end
        @test_throws ErrorException Scorer.score_with_backend_for_synthetic_test(
            fixture.activation, fixture.packet, fixture.candidate,
            joinpath(root, "score"), loader,
            Val(:synthetic_test_only))
        @test calls[] == 0
    end
end
