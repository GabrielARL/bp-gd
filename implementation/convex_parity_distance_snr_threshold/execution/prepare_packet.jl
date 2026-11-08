#!/usr/bin/env julia

module RQ2ConvexParityDistanceSNRThresholdPacket

using SHA
using TOML

include(joinpath(@__DIR__, "..", "..", "convex_parity_distance",
                 "execution", "artifact_io.jl"))
using .ConvexParityDistanceArtifactIO
include(joinpath(@__DIR__, "activation_gate.jl"))
using .RQ2ConvexParityDistanceSNRThresholdActivationGate

export prepare_packet, parse_snr_grid, validate_stage_and_grid,
       write_graph_binary, write_llr_binary, vector_f64_sha256,
       EXPERIMENT_ID, PACKET_SCHEMA

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001"
const PACKET_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/candidate-packet-v1"
const N = 10_200
const M = 5_100
const CHECK_DEGREE = 6
const VARIABLE_DEGREE = 3
const EDGE_COUNT = 30_600
const REGISTERED_GRAPH_SHA256 =
    "94d94376995c6eb9e21a5859dde6354d7233f61634b5dbdc91fd70653f5f6e2d"

const DEFAULT_SOURCE_ROOT =
    "/home/gabiel/Documents/GitHub/sp_gd_admm-rq2-jc-projected-stationarity-20261107/experiments"
const DEFAULT_ADAPTER = joinpath(
    DEFAULT_SOURCE_ROOT, "rq2_native_gap_001", "rq2_native_gap_001.jl")
const DEFAULT_CONFIG = joinpath(
    DEFAULT_SOURCE_ROOT, "rq2_native_gap_001", "config.toml")
const DEFAULT_ARCHIVED_GENERATOR = joinpath(
    DEFAULT_SOURCE_ROOT, "rq2_gd_state_use_001", "rq2_gd_state_use_001.jl")
const DEFAULT_RETAINED_SPLIT_CONFIG = joinpath(
    DEFAULT_SOURCE_ROOT, "rq2_native_gap_001", "results",
    "2026-10-31_profile_v2", "source", "retained", "split_config.toml")
const ADAPTER_SHA256 =
    "5ce7ba12efe06b4e9a4d5b31401064128b5b95e12fe38a990e24bf228a368ec8"
const ARCHIVED_GENERATOR_SHA256 =
    "6c09396c7f394ad2c45ae4ee0b22d8b556c384784e2ce21fcea0ce3632009f7d"
const CONFIG_SHA256 =
    "7730e668a4dc48bbf8afb8a5ed1ba365ae4b4bfb7f5306be86a795eb203286b9"
const COARSE_SNRS = collect(1.5:0.5:12.0)
const STAGE_FRAMES = Dict(
    "coarse" => (20_001:20_024),
    "fine" => (30_001:30_200),
)

# The registered adapter is loaded only when packet preparation actually
# begins.  Unit tests can therefore exercise all byte/schema helpers without
# importing the channel generator or opening any population case.
module FrozenAdapterNamespace end

function _require_registered_file(path::AbstractString, expected::AbstractString,
                                  label::AbstractString)
    isfile(path) || throw(ArgumentError("$label is missing: $path"))
    actual = file_sha256(path)
    actual == expected || throw(ArgumentError(
        "$label SHA-256 differs: expected $expected, got $actual"))
    abspath(path)
end

function _load_adapter(adapter_path::String)
    _require_registered_file(adapter_path, ADAPTER_SHA256, "immutable adapter")
    if !isdefined(FrozenAdapterNamespace, :RQ2NativeGap001)
        Base.include(FrozenAdapterNamespace, adapter_path)
    end
    Base.invokelatest(getfield, FrozenAdapterNamespace, :RQ2NativeGap001)
end

function parse_snr_grid(text::AbstractString)
    isempty(strip(text)) && throw(ArgumentError("SNR grid is empty"))
    values = Float64[]
    for field in split(text, ',')
        isempty(strip(field)) && throw(ArgumentError("SNR grid has an empty field"))
        value = tryparse(Float64, strip(field))
        value === nothing && throw(ArgumentError("invalid SNR value: $field"))
        isfinite(value) || throw(ArgumentError("SNR values must be finite"))
        push!(values, value)
    end
    length(unique(values)) == length(values) ||
        throw(ArgumentError("SNR grid repeats a value"))
    issorted(values; lt=<) ||
        throw(ArgumentError("SNR grid must be strictly increasing"))
    values
end

function validate_stage_and_grid(stage::AbstractString,
                                 snrs::AbstractVector{<:Real})
    haskey(STAGE_FRAMES, stage) ||
        throw(ArgumentError("stage must be coarse or fine"))
    values = Float64.(snrs)
    all(isfinite, values) || throw(ArgumentError("SNR values must be finite"))
    length(unique(values)) == length(values) ||
        throw(ArgumentError("SNR grid repeats a value"))
    issorted(values; lt=<) ||
        throw(ArgumentError("SNR grid must be strictly increasing"))
    if stage == "coarse"
        values == COARSE_SNRS || throw(ArgumentError(
            "coarse stage requires the registered 1.5:0.5:12.0 dB grid"))
    else
        length(values) == 11 || throw(ArgumentError(
            "fine stage requires the frozen 11-level grid"))
        all(isapprox(values[index + 1] - values[index], 0.1;
                     atol=2.0e-12, rtol=0.0)
            for index in 1:10) || throw(ArgumentError(
                "fine-stage SNR levels must be spaced by 0.1 dB"))
    end
    (; stage=String(stage), snrs=values, frames=STAGE_FRAMES[String(stage)])
end

function vector_f64_sha256(values::AbstractVector{<:Real})
    vector = Float64.(values)
    bytes_sha256(reinterpret(UInt8, vector))
end

function write_graph_binary(path::AbstractString, checks)
    Base.ENDIAN_BOM == 0x04030201 ||
        error("registered packet encoding requires a little-endian host")
    length(checks) == M ||
        throw(DimensionMismatch("graph must contain $M checks"))
    open(path, "w") do io
        for (check_index, check) in enumerate(checks)
            length(check) == CHECK_DEGREE || throw(DimensionMismatch(
                "check $check_index does not have degree $CHECK_DEGREE"))
            for bit in check
                1 <= bit <= N || throw(ArgumentError(
                    "check $check_index has an out-of-range bit"))
                write(io, htol(Int32(bit)))
            end
        end
    end
    filesize(path) == sizeof(Int32) * CHECK_DEGREE * M ||
        error("graph binary byte count differs")
    path
end

function write_llr_binary(io::IO, llr::AbstractVector{<:Real})
    Base.ENDIAN_BOM == 0x04030201 ||
        error("registered packet encoding requires a little-endian host")
    length(llr) == N || throw(DimensionMismatch("LLR vector length differs"))
    vector = Float64.(llr)
    all(isfinite, vector) || throw(ArgumentError("LLR vector is nonfinite"))
    all(value -> -20.0 <= value <= 20.0, vector) ||
        throw(ArgumentError("LLR vector exceeds the registered clip"))
    write(io, reinterpret(UInt8, vector))
    vector
end

function write_llr_binary(path::AbstractString,
                          columns::AbstractVector{<:AbstractVector})
    open(path, "w") do io
        for column in columns
            write_llr_binary(io, column)
        end
    end
    filesize(path) == sizeof(Float64) * N * length(columns) ||
        error("LLR binary byte count differs")
    path
end

function _verify_source_gate(Adapter, config_path::String,
                             archived_generator_path::String,
                             retained_split_config_path::String)
    _require_registered_file(config_path, CONFIG_SHA256, "archived configuration")
    _require_registered_file(archived_generator_path, ARCHIVED_GENERATOR_SHA256,
                             "archived generator")
    config = Base.invokelatest(Adapter.load_config, config_path)
    protocol = config["protocol"]
    _require_registered_file(
        retained_split_config_path, String(protocol["split_config_sha256"]),
        "retained split configuration")
    _require_registered_file(
        Adapter.SPLIT_RUNNER_PATH, String(protocol["split_runner_sha256"]),
        "retained split runner")
    _require_registered_file(
        Adapter.Split.LEGACY_RUNNER_PATH, String(protocol["legacy_runner_sha256"]),
        "adapter-bound generator")
    realpath(Adapter.Split.LEGACY_RUNNER_PATH) == realpath(archived_generator_path) ||
        throw(ArgumentError("adapter did not bind the registered generator source"))
    split = TOML.parsefile(retained_split_config_path)
    legacy_gate = Base.invokelatest(Adapter.Legacy.source_gate, split)
    Bool(legacy_gate["passed"]) || throw(ArgumentError(
        "archived generator source gate failed"))
    gate = Dict{String,Any}(
        "passed" => true,
        "retained_split_config" => true,
        "retained_split_runner" => true,
        "adapter_bound_generator" => true,
        "archived_generator_static_sources" => legacy_gate,
    )
    (; config, split, gate)
end

function _graph_degree_gate(checks)
    length(checks) == M || throw(DimensionMismatch("graph check count differs"))
    degrees = zeros(Int, N)
    for (check_index, check) in enumerate(checks)
        length(check) == CHECK_DEGREE || throw(DimensionMismatch(
            "check $check_index does not have degree $CHECK_DEGREE"))
        for bit in check
            1 <= bit <= N || throw(ArgumentError("graph bit is out of range"))
            degrees[bit] += 1
        end
    end
    all(==(VARIABLE_DEGREE), degrees) ||
        throw(ArgumentError("graph variable degree differs"))
    true
end

function prepare_packet(stage::String, snrs::Vector{Float64}, output_root::String;
        activation_path::String,
        adapter_path::String=DEFAULT_ADAPTER,
        config_path::String=DEFAULT_CONFIG,
        archived_generator_path::String=DEFAULT_ARCHIVED_GENERATOR,
        retained_split_config_path::String=DEFAULT_RETAINED_SPLIT_CONFIG,
        _activation_sources::ActivationSourcePaths=default_source_paths(),
        _adapter_loader::Function=_load_adapter)
    activation = verify_activation(
        activation_path; expected_stage=stage, expected_snrs=snrs,
        sources=_activation_sources)
    spec = validate_stage_and_grid(stage, snrs)
    packet = require_empty_directory(output_root)
    Adapter = _adapter_loader(abspath(adapter_path))
    source = _verify_source_gate(
        Adapter, abspath(config_path), abspath(archived_generator_path),
        abspath(retained_split_config_path))

    Base.invokelatest(Adapter.Legacy.enforce_thread_environment, source.split)
    native = Base.invokelatest(Adapter.Legacy.load_native, source.split)
    generated = Base.invokelatest(Adapter.make_bp_code, source.config, source.split)
    checks = [Int.(check) for check in generated.code.check_vars]
    _graph_degree_gate(checks)
    graph_hash = Base.invokelatest(Adapter.Legacy.graph_sha256, checks)
    graph_hash == REGISTERED_GRAPH_SHA256 ||
        error("registered graph scientific hash differs")

    graph_name = "checks_i32_6_by_m.bin"
    llr_name = "llr_f64_n_by_case.bin"
    index_name = "case_index.csv"
    grid_name = "snr_grid.csv"
    config_name = "packet_config.csv"
    graph_path = joinpath(packet, graph_name)
    llr_path = joinpath(packet, llr_name)
    write_graph_binary(graph_path, checks)

    index_header = String[
        "case_ordinal", "frame", "physical_esn0_db", "noise_seed",
        "graph_sha256", "clipped_llr_sha256",
    ]
    index_rows = Vector{Vector{String}}()
    unit_noise_by_frame = Dict{Int,String}()
    seed_by_frame = Dict{Int,Int}()
    channels = Dict{Float64,Any}()
    case_ordinal = 0
    open(llr_path, "w") do io
        for snr in spec.snrs
            channel = get!(channels, snr) do
                Base.invokelatest(Adapter.channel_config, source.split, snr)
            end
            for frame in spec.frames
                case_ordinal += 1
                input = Base.invokelatest(
                    Adapter.Legacy.generate_input, channel, native,
                    generated.code, frame)
                llr = write_llr_binary(io, input.clipped_llr)
                llr_hash = vector_f64_sha256(llr)
                llr_hash == String(input.identities.clipped_llr_sha256) ||
                    error("generated LLR scientific hash differs at case $case_ordinal")
                String(input.identities.graph_sha256) == graph_hash ||
                    error("generated graph identity differs at case $case_ordinal")
                seed = Int(input.noise_seed)
                seed == 20_261_012 + frame ||
                    error("noise seed differs at case $case_ordinal")
                unit_hash = String(input.identities.unit_noise_sha256)
                if haskey(unit_noise_by_frame, frame)
                    unit_noise_by_frame[frame] == unit_hash || error(
                        "frame $frame did not reuse its unit-noise draw across SNR")
                    seed_by_frame[frame] == seed || error(
                        "frame $frame did not reuse its noise seed across SNR")
                else
                    unit_noise_by_frame[frame] = unit_hash
                    seed_by_frame[frame] = seed
                end
                push!(index_rows, String[
                    string(case_ordinal), string(frame), repr(snr), string(seed),
                    graph_hash, llr_hash,
                ])
            end
        end
    end
    case_count = length(spec.snrs) * length(spec.frames)
    case_ordinal == case_count || error("case count differs")
    filesize(llr_path) == sizeof(Float64) * N * case_count ||
        error("LLR packet byte count differs")

    grid_rows = [String[string(index), repr(snr)]
                 for (index, snr) in enumerate(spec.snrs)]
    write_csv(joinpath(packet, grid_name),
              ["snr_ordinal", "physical_esn0_db"], grid_rows)
    write_csv(joinpath(packet, index_name), index_header, index_rows)
    config_rows = Vector{Vector{String}}([
        ["schema", PACKET_SCHEMA],
        ["experiment_id", EXPERIMENT_ID],
        ["stage", spec.stage],
        ["activation_sha256", activation.sha256],
        ["case_order", "ascending SNR outer, ascending frame inner"],
        ["case_count", string(case_count)],
        ["snr_count", string(length(spec.snrs))],
        ["frame_first", string(first(spec.frames))],
        ["frame_last", string(last(spec.frames))],
        ["n", string(N)], ["m", string(M)],
        ["edge_count", string(EDGE_COUNT)],
        ["check_degree", string(CHECK_DEGREE)],
        ["variable_degree", string(VARIABLE_DEGREE)],
        ["graph_binary_sha256", file_sha256(graph_path)],
        ["graph_scientific_sha256", graph_hash],
        ["llr_binary_sha256", file_sha256(llr_path)],
        ["llr_encoding", "Float64 little-endian n-by-case column-major"],
        ["adapter_sha256", file_sha256(adapter_path)],
        ["archived_generator_sha256", file_sha256(archived_generator_path)],
        ["archived_config_sha256", file_sha256(config_path)],
        ["retained_split_config_sha256", file_sha256(retained_split_config_path)],
        ["unit_noise_reused_by_frame_across_snr", "true"],
        ["truth_fields_present", "false"],
        ["comparison_decoder_fields_present", "false"],
    ])
    write_csv(joinpath(packet, config_name), ["field", "value"], config_rows)
    members = String[graph_name, llr_name, index_name, grid_name, config_name]
    manifest = write_sha_manifest(
        packet, members; filename="PACKET_MANIFEST.sha256")
    ready = joinpath(packet, "PACKET_READY.txt")
    write_key_values(ready, Pair{String,String}[
        "schema" => PACKET_SCHEMA,
        "experiment_id" => EXPERIMENT_ID,
        "stage" => spec.stage,
        "activation_sha256" => activation.sha256,
        "case_count" => string(case_count),
        "manifest_file" => basename(manifest),
        "manifest_sha256" => file_sha256(manifest),
        "truth_fields_present" => "false",
        "comparison_decoder_fields_present" => "false",
    ])
    (; packet=packet, packet_ready=ready, manifest=manifest,
       activation_sha256=activation.sha256, case_count=case_count,
       graph_sha256=graph_hash,
       llr_binary_sha256=file_sha256(llr_path))
end

function parse_cli(args)
    options = Dict{String,String}()
    index = 1
    while index <= length(args)
        option = args[index]
        option in ("--activation", "--stage", "--snr-grid", "--output-root", "--adapter",
                   "--config", "--archived-generator",
                   "--retained-split-config") ||
            throw(ArgumentError("unknown option: $option"))
        index < length(args) || throw(ArgumentError("$option needs a value"))
        options[option] = args[index + 1]
        index += 2
    end
    for required in ("--activation", "--stage", "--snr-grid", "--output-root")
        haskey(options, required) || throw(ArgumentError("$required is required"))
    end
    options
end

function main(args=ARGS)
    options = parse_cli(args)
    result = prepare_packet(
        options["--stage"], parse_snr_grid(options["--snr-grid"]),
        abspath(options["--output-root"]);
        activation_path=abspath(options["--activation"]),
        adapter_path=abspath(get(options, "--adapter", DEFAULT_ADAPTER)),
        config_path=abspath(get(options, "--config", DEFAULT_CONFIG)),
        archived_generator_path=abspath(get(
            options, "--archived-generator", DEFAULT_ARCHIVED_GENERATOR)),
        retained_split_config_path=abspath(get(
            options, "--retained-split-config", DEFAULT_RETAINED_SPLIT_CONFIG)))
    println("PACKET_READY stage=", options["--stage"],
            " case_count=", result.case_count,
            " packet_ready_sha256=", file_sha256(result.packet_ready))
    nothing
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    RQ2ConvexParityDistanceSNRThresholdPacket.main()
end
