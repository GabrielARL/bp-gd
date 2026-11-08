using Test
using TOML

const IMPLEMENTATION_ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(IMPLEMENTATION_ROOT, "execution", "prepare_packet.jl"))
const Packet = RQ2ConvexParityDistanceSNRThresholdPacket
const ArtifactIO = Packet.ConvexParityDistanceArtifactIO

function synthetic_activation_sources(root)
    registered = Packet.default_source_paths()
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
    Packet.ActivationSourcePaths(
        paths[:objective_source], paths[:accelerated_source],
        paths[:activation_gate_source], paths[:preparer_source],
        paths[:candidate_runner_source], paths[:scorer_source],
        paths[:artifact_helper_source], paths[:local_artifact_shim_source],
        paths[:project_toml], paths[:manifest_toml], paths[:card],
        ArtifactIO.file_sha256(paths[:objective_source]),
        ArtifactIO.file_sha256(paths[:accelerated_source]))
end

function write_synthetic_activation(path, sources;
        stage="coarse", snrs=collect(1.5:0.5:12.0), bad_pin=nothing,
        crossing=7.0)
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
        "schema" => Packet.ACTIVATION_SCHEMA,
        "experiment_id" => Packet.EXPERIMENT_ID,
        "stage" => stage,
        "snr_grid_db" => Float64.(snrs),
        "frame_first" => stage == "coarse" ? 20_001 : 30_001,
        "frame_last" => stage == "coarse" ? 20_024 : 30_200,
        "update_cap" => 30,
        "hashes" => hashes,
    )
    if stage == "fine"
        document["coarse_result"] = Dict(
            "crossing_s_c_db" => Float64(crossing),
            "score_commit_sha256" => repeat("a", 64),
            "score_manifest_sha256" => repeat("b", 64),
        )
    end
    open(path, "w") do io
        TOML.print(io, document; sorted=true)
    end
    path
end

@testset "registered source pins without population access" begin
    @test ArtifactIO.file_sha256(Packet.DEFAULT_ADAPTER) == Packet.ADAPTER_SHA256
    @test ArtifactIO.file_sha256(Packet.DEFAULT_ARCHIVED_GENERATOR) ==
          Packet.ARCHIVED_GENERATOR_SHA256
    @test ArtifactIO.file_sha256(Packet.DEFAULT_CONFIG) == Packet.CONFIG_SHA256
    @test ArtifactIO.file_sha256(Packet.DEFAULT_RETAINED_SPLIT_CONFIG) ==
          "d5f55d93a4ff20bd680082f80f24169d5a3f80d4fe6facb5dea76c8fe38e39a9"
end

@testset "stage and exact-grid validation" begin
    coarse = Packet.validate_stage_and_grid("coarse", collect(1.5:0.5:12.0))
    @test coarse.frames == 20_001:20_024
    @test length(coarse.snrs) == 22
    fine = Packet.validate_stage_and_grid(
        "fine", Packet.parse_snr_grid("6.5,6.6,6.7,6.8,6.9,7.0,7.1,7.2,7.3,7.4,7.5"))
    @test fine.frames == 30_001:30_200
    @test length(fine.snrs) == 11
    @test_throws ArgumentError Packet.validate_stage_and_grid(
        "coarse", collect(1.5:0.5:11.5))
    @test_throws ArgumentError Packet.validate_stage_and_grid(
        "fine", collect(6.5:0.2:8.5))
    @test_throws ArgumentError Packet.parse_snr_grid("6.0,5.5")
    @test_throws ArgumentError Packet.parse_snr_grid("6.0,6.0")
    @test_throws ArgumentError Packet.parse_snr_grid("6.0,,6.5")
end

@testset "prospective activation binds sources and exact stage population" begin
    mktempdir() do root
        sources = synthetic_activation_sources(root)
        valid = write_synthetic_activation(joinpath(root, "coarse.toml"), sources)
        activation = Packet.verify_activation(
            valid; expected_stage="coarse",
            expected_snrs=collect(1.5:0.5:12.0), sources=sources)
        @test activation.frame_first == 20_001
        @test activation.frame_last == 20_024
        @test activation.update_cap == 30
        @test activation.sha256 == ArtifactIO.file_sha256(valid)

        fine_snrs = [6.5 + 0.1 * index for index in 0:10]
        fine = write_synthetic_activation(
            joinpath(root, "fine.toml"), sources; stage="fine",
            snrs=fine_snrs, crossing=7.0)
        fine_activation = Packet.verify_activation(
            fine; expected_stage="fine", expected_snrs=fine_snrs,
            sources=sources)
        @test fine_activation.coarse_crossing_s_c_db == 7.0
        @test fine_activation.coarse_score_commit_sha256 == repeat("a", 64)
        @test fine_activation.coarse_score_manifest_sha256 == repeat("b", 64)
    end
end

@testset "bad activation fails before generator loading" begin
    mktempdir() do root
        sources = synthetic_activation_sources(root)
        generation_calls = Ref(0)
        loader = _ -> begin
            generation_calls[] += 1
            error("synthetic loader must not be reached")
        end

        bad_pin = write_synthetic_activation(
            joinpath(root, "bad-pin.toml"), sources;
            bad_pin=:preparer_source_sha256)
        @test_throws ArgumentError Packet.prepare_packet(
            "coarse", collect(1.5:0.5:12.0), joinpath(root, "packet-a");
            activation_path=bad_pin, _activation_sources=sources,
            _adapter_loader=loader)
        @test generation_calls[] == 0

        bad_gate_pin = write_synthetic_activation(
            joinpath(root, "bad-gate-pin.toml"), sources;
            bad_pin=:activation_gate_source_sha256)
        @test_throws ArgumentError Packet.prepare_packet(
            "coarse", collect(1.5:0.5:12.0), joinpath(root, "packet-gate");
            activation_path=bad_gate_pin, _activation_sources=sources,
            _adapter_loader=loader)
        @test generation_calls[] == 0

        bad_grid_values = vcat(collect(1.5:0.5:11.5), 12.5)
        bad_grid = write_synthetic_activation(
            joinpath(root, "bad-grid.toml"), sources; snrs=bad_grid_values)
        @test_throws ArgumentError Packet.prepare_packet(
            "coarse", bad_grid_values, joinpath(root, "packet-b");
            activation_path=bad_grid, _activation_sources=sources,
            _adapter_loader=loader)
        @test generation_calls[] == 0
    end
end

@testset "packet CLI requires activation" begin
    @test_throws ArgumentError Packet.parse_cli([
        "--stage", "coarse", "--snr-grid", "1.5", "--output-root", "/tmp/x"])
end

function synthetic_regular_checks()
    checks = Vector{Vector{Int}}(undef, Packet.M)
    pair_bits(pair) = (2pair - 1, 2pair)
    for check in 1:Packet.M
        pairs = (check, mod1(check + 1, Packet.M), mod1(check + 2, Packet.M))
        checks[check] = collect(Iterators.flatten(pair_bits(pair) for pair in pairs))
    end
    checks
end

@testset "synthetic graph and LLR byte encodings" begin
    checks = synthetic_regular_checks()
    degrees = zeros(Int, Packet.N)
    for check in checks, bit in check
        degrees[bit] += 1
    end
    @test all(==(Packet.VARIABLE_DEGREE), degrees)
    mktempdir() do root
        graph_path = joinpath(root, "checks.bin")
        Packet.write_graph_binary(graph_path, checks)
        @test filesize(graph_path) == 4 * Packet.CHECK_DEGREE * Packet.M
        values = reinterpret(Int32, read(graph_path))
        @test Int.(values[1:6]) == checks[1]

        llr_a = zeros(Packet.N)
        llr_b = [20sin(index / 31) for index in 1:Packet.N]
        llr_path = joinpath(root, "llrs.bin")
        Packet.write_llr_binary(llr_path, [llr_a, llr_b])
        @test filesize(llr_path) == 8 * Packet.N * 2
        decoded = reinterpret(Float64, read(llr_path))
        @test decoded[1:Packet.N] == llr_a
        @test decoded[Packet.N + 1:end] == llr_b
        @test Packet.vector_f64_sha256(llr_b) ==
              ArtifactIO.bytes_sha256(reinterpret(UInt8, llr_b))
        @test_throws ArgumentError Packet.write_llr_binary(
            IOBuffer(), fill(20.1, Packet.N))
    end
end

@testset "artifact manifest and firewall metadata" begin
    mktempdir() do root
        ArtifactIO.write_csv(joinpath(root, "case_index.csv"),
            ["case_ordinal", "frame", "physical_esn0_db", "noise_seed",
             "graph_sha256", "clipped_llr_sha256"],
            [["1", "20001", "1.5", "20281013", repeat("a", 64), repeat("b", 64)]])
        ArtifactIO.write_csv(joinpath(root, "snr_grid.csv"),
            ["snr_ordinal", "physical_esn0_db"], [["1", "1.5"]])
        manifest = ArtifactIO.write_sha_manifest(root,
            ["case_index.csv", "snr_grid.csv"];
            filename="PACKET_MANIFEST.sha256")
        @test ArtifactIO.verify_sha_manifest(root, basename(manifest);
            expected_members=["case_index.csv", "snr_grid.csv"])
        index = ArtifactIO.read_csv(joinpath(root, "case_index.csv"))
        @test index.header == [
            "case_ordinal", "frame", "physical_esn0_db", "noise_seed",
            "graph_sha256", "clipped_llr_sha256"]
        forbidden = ("transmitted", "truth", "bp_", "recovery", "scorer")
        @test all(!any(occursin(token, lowercase(field)) for token in forbidden)
                  for field in index.header)
        open(joinpath(root, "snr_grid.csv"), "a") do io
            println(io, "2,2.0")
        end
        @test_throws ArgumentError ArtifactIO.verify_sha_manifest(
            root, basename(manifest))
    end
end
