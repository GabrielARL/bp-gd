using Test
using TOML

import ConvexParityDistance
import ConvexParityDistanceAccelerated

const CPD = ConvexParityDistance

include(joinpath(@__DIR__, "..", "execution", "candidate_runner.jl"))
const Candidate = RQ2ConvexParityDistanceSNRThresholdCandidate
const ArtifactIO = Candidate.ConvexParityDistanceArtifactIO

function synthetic_activation_sources(root)
    registered = Candidate.default_source_paths()
    names = [
        (:objective_source, "objective.jl"),
        (:accelerated_source, "accelerated.jl"),
        (:activation_gate_source, "activation_gate.jl"),
        (:preparer_source, "prepare_packet.jl"),
        (:candidate_runner_source, "candidate_runner.jl"),
        (:scorer_source, "score_candidate.jl"),
        (:artifact_helper_source, "artifact_io.jl"),
        (:local_artifact_shim_source, "local_artifact_shim.jl"),
        (:project_toml, "Project.toml"),
        (:manifest_toml, "Manifest.toml"),
        (:card, "card.md"),
    ]
    paths = Dict{Symbol,String}()
    for (field, name) in names
        target = joinpath(root, name)
        cp(getfield(registered, field), target)
        paths[field] = target
    end
    Candidate.ActivationSourcePaths(
        paths[:objective_source], paths[:accelerated_source],
        paths[:activation_gate_source], paths[:preparer_source],
        paths[:candidate_runner_source], paths[:scorer_source],
        paths[:artifact_helper_source], paths[:local_artifact_shim_source],
        paths[:project_toml], paths[:manifest_toml], paths[:card],
        ArtifactIO.file_sha256(paths[:objective_source]),
        ArtifactIO.file_sha256(paths[:accelerated_source]))
end

function write_synthetic_activation(path, sources;
        snrs=collect(1.5:0.5:12.0), bad_pin=nothing)
    hashes = Dict(
        "objective_source_sha256" => ArtifactIO.file_sha256(sources.objective_source),
        "accelerated_source_sha256" => ArtifactIO.file_sha256(sources.accelerated_source),
        "activation_gate_source_sha256" =>
            ArtifactIO.file_sha256(sources.activation_gate_source),
        "preparer_source_sha256" => ArtifactIO.file_sha256(sources.preparer_source),
        "candidate_runner_source_sha256" =>
            ArtifactIO.file_sha256(sources.candidate_runner_source),
        "scorer_source_sha256" => ArtifactIO.file_sha256(sources.scorer_source),
        "artifact_helper_source_sha256" =>
            ArtifactIO.file_sha256(sources.artifact_helper_source),
        "local_artifact_shim_source_sha256" =>
            ArtifactIO.file_sha256(sources.local_artifact_shim_source),
        "project_toml_sha256" => ArtifactIO.file_sha256(sources.project_toml),
        "manifest_toml_sha256" => ArtifactIO.file_sha256(sources.manifest_toml),
        "card_sha256" => ArtifactIO.file_sha256(sources.card),
    )
    bad_pin === nothing || (hashes[String(bad_pin)] = repeat("0", 64))
    document = Dict{String,Any}(
        "schema" => Candidate.ACTIVATION_SCHEMA,
        "experiment_id" => Candidate.EXPERIMENT_ID,
        "stage" => "coarse",
        "snr_grid_db" => Float64.(snrs),
        "frame_first" => 20_001,
        "frame_last" => 20_024,
        "update_cap" => 30,
        "hashes" => hashes,
    )
    open(path, "w") do io
        TOML.print(io, document; sorted=true)
    end
    path
end

function synthetic_stage_activation(hash=repeat("e", 64))
    Candidate.StageActivation(
        "/synthetic/activation.toml", hash, "coarse",
        collect(1.5:0.5:12.0), 20_001, 20_024, 30,
        Dict{String,String}(), nothing, nothing, nothing)
end

function synthetic_packet()
    checks = [collect(1:6) for _ in 1:3]
    llrs = hcat(fill(8.0, 6), [-8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
    rows = Dict{String,String}[]
    for ordinal in 1:2
        push!(rows, Dict(
            "case_ordinal" => string(ordinal),
            "frame" => string(20_000 + ordinal),
            "physical_esn0_db" => "7.5",
            "noise_seed" => string(20_261_012 + 20_000 + ordinal),
            "graph_sha256" => "synthetic",
            "clipped_llr_sha256" => CPD.vector_sha256(view(llrs, :, ordinal)),
        ))
    end
    Candidate.CandidatePacket(
        "coarse", repeat("e", 64), checks, llrs, rows,
        repeat("a", 64), repeat("b", 64),
        repeat("c", 64), repeat("d", 64))
end

function column_index(header, name)
    found = findfirst(==(name), header)
    found === nothing && error("missing test column $name")
    found
end

@testset "candidate executes the frozen 30-update path" begin
    packet = synthetic_packet()
    collector = Candidate.Collector(true)
    trace = Vector{Vector{String}}()
    row = Candidate.run_case!(packet, collector, trace, 1)

    @test length(trace) == Candidate.UPDATE_CAP
    @test parse(Int, row[column_index(Candidate.CASE_HEADER,
                                     "terminal_update")]) == 30
    @test parse(Int, row[column_index(Candidate.CASE_HEADER,
                                     "first_valid_update")]) == 1
    @test row[column_index(Candidate.CASE_HEADER,
                           "latched_hard_sha256")] != ""
    @test all(parse(Int, trace[update][column_index(
        Candidate.TRACE_HEADER, "update")]) == update for update in 1:30)
    @test trace[1][column_index(Candidate.TRACE_HEADER, "latch_event")] == "true"
    @test all(trace[update][column_index(Candidate.TRACE_HEADER,
        "latch_event")] == "false" for update in 2:30)
    @test length(collector.state_rows) == 1
    @test count(row -> row[column_index(Candidate.HARD_INDEX_HEADER,
                                       "role")] == "latched",
                collector.hard_rows) == 1
    @test count(row -> row[column_index(Candidate.HARD_INDEX_HEADER,
                                       "role")] == "terminal",
                collector.hard_rows) == 1
end

@testset "candidate scientific replay is exact and excludes telemetry" begin
    packet = synthetic_packet()
    activation = synthetic_stage_activation()
    primary = Candidate.run_pass(packet, activation, "primary"; capture=true)
    replay = Candidate.run_pass(packet, activation, "replay"; capture=true)

    @test Candidate._verify_replay(primary, replay)
    @test primary.digest == replay.digest
    @test primary.states == replay.states
    @test primary.hards == replay.hards
    @test primary.case_rows == replay.case_rows
    @test primary.trace_rows == replay.trace_rows
    @test primary.telemetry != replay.telemetry ||
          all(row.label != "replay" for row in primary.telemetry)

    mktempdir() do output
        result = Candidate.write_results(output, packet, primary, replay)
        commit = Candidate.read_key_values(result.commit)
        @test commit["scientific_replay_equal"] == "true"
        @test commit["telemetry_excluded_from_scientific_replay"] == "true"
        @test commit["candidate_outcome_committed"] == "true"
        @test commit["truth_used"] == "false"
        @test commit["bp_used"] == "false"
        @test isfile(joinpath(output, "candidate_telemetry.csv"))
        @test isfile(joinpath(output, "final_states_f64_le.bin"))
        @test isfile(joinpath(output, "hard_decisions_packed.bin"))
    end
end


@testset "bad activation fails before packet load or candidate updates" begin
    mktempdir() do root
        sources = synthetic_activation_sources(root)
        packet_loads = Ref(0)
        run_calls = Ref(0)
        packet_loader = (packet_root, activation) -> begin
            packet_loads[] += 1
            error("synthetic packet loader must not be reached")
        end
        pass_runner = (packet, activation, label; capture) -> begin
            run_calls[] += 1
            error("synthetic pass runner must not be reached")
        end

        bad_pin = write_synthetic_activation(
            joinpath(root, "bad-pin.toml"), sources;
            bad_pin=:candidate_runner_source_sha256)
        @test_throws ArgumentError Candidate.execute_candidate(
            bad_pin, joinpath(root, "packet-a"), joinpath(root, "output-a");
            _activation_sources=sources, _packet_loader=packet_loader,
            _pass_runner=pass_runner)
        @test packet_loads[] == 0
        @test run_calls[] == 0

        bad_shim_pin = write_synthetic_activation(
            joinpath(root, "bad-shim-pin.toml"), sources;
            bad_pin=:local_artifact_shim_source_sha256)
        @test_throws ArgumentError Candidate.execute_candidate(
            bad_shim_pin, joinpath(root, "packet-shim"),
            joinpath(root, "output-shim");
            _activation_sources=sources, _packet_loader=packet_loader,
            _pass_runner=pass_runner)
        @test packet_loads[] == 0
        @test run_calls[] == 0

        bad_grid_values = vcat(collect(1.5:0.5:11.5), 12.5)
        bad_grid = write_synthetic_activation(
            joinpath(root, "bad-grid.toml"), sources; snrs=bad_grid_values)
        @test_throws ArgumentError Candidate.execute_candidate(
            bad_grid, joinpath(root, "packet-b"), joinpath(root, "output-b");
            _activation_sources=sources, _packet_loader=packet_loader,
            _pass_runner=pass_runner)
        @test packet_loads[] == 0
        @test run_calls[] == 0
    end
end

@testset "candidate CLI requires activation" begin
    @test_throws ArgumentError Candidate.parse_cli([
        "--packet-root", "/tmp/p", "--output-root", "/tmp/o"])
end

@testset "candidate fails closed on invalid continuous state" begin
    @test_throws ErrorException Candidate._validate_box_state!(
        [0.0, NaN], "synthetic", 1, 1)
    @test_throws ErrorException Candidate._validate_box_state!(
        [0.0, 1.0 + eps(Float64)], "synthetic", 1, 1)
    @test Candidate._validate_box_state!([0.0, 0.5, 1.0],
                                         "synthetic", 1, 1) === nothing
end

@testset "candidate source has no prohibited decoder or generator dependency" begin
    source_path = joinpath(@__DIR__, "..", "execution", "candidate_runner.jl")
    source = read(source_path, String)
    prohibited = [
        r"(?m)^\s*(using|import)\s+JadeJcade\b",
        r"\bLegacy\.",
        r"\bdecode_bp\b",
        r"\btransmitted_word\b",
        r"\bgenerate_input\b",
    ]
    @test all(pattern -> !occursin(pattern, source), prohibited)
end
