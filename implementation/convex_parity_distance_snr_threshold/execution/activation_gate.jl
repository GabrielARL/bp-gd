module RQ2ConvexParityDistanceSNRThresholdActivationGate

using SHA
using TOML

export ActivationSourcePaths, StageActivation, default_source_paths,
       verify_activation, ACTIVATION_SCHEMA, EXPERIMENT_ID, COARSE_SNRS,
       UPDATE_CAP

const EXPERIMENT_ID = "RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001"
const ACTIVATION_SCHEMA =
    "rq2-convex-parity-distance-snr-threshold-001/stage-activation-v1"
const UPDATE_CAP = 30
const COARSE_SNRS = collect(1.5:0.5:12.0)
const OBJECTIVE_SOURCE_SHA256 =
    "5df9ae2489356a8d9e0f38efe5453713fec3130dfb68f8a14119638357b251f3"
const ACCELERATED_SOURCE_SHA256 =
    "3eb0f8b85ba12a418fda9484cd658c43748a5bfc1db1dc92f9cc58b6f1edb5fc"

const HASH_FIELDS = (
    objective_source_sha256=:objective_source,
    accelerated_source_sha256=:accelerated_source,
    activation_gate_source_sha256=:activation_gate_source,
    preparer_source_sha256=:preparer_source,
    candidate_runner_source_sha256=:candidate_runner_source,
    scorer_source_sha256=:scorer_source,
    artifact_helper_source_sha256=:artifact_helper_source,
    local_artifact_shim_source_sha256=:local_artifact_shim_source,
    project_toml_sha256=:project_toml,
    manifest_toml_sha256=:manifest_toml,
    card_sha256=:card,
)

struct ActivationSourcePaths
    objective_source::String
    accelerated_source::String
    activation_gate_source::String
    preparer_source::String
    candidate_runner_source::String
    scorer_source::String
    artifact_helper_source::String
    local_artifact_shim_source::String
    project_toml::String
    manifest_toml::String
    card::String
    objective_expected_sha256::String
    accelerated_expected_sha256::String
end

struct StageActivation
    path::String
    sha256::String
    stage::String
    snrs::Vector{Float64}
    frame_first::Int
    frame_last::Int
    update_cap::Int
    source_hashes::Dict{String,String}
    coarse_crossing_s_c_db::Union{Nothing,Float64}
    coarse_score_commit_sha256::Union{Nothing,String}
    coarse_score_manifest_sha256::Union{Nothing,String}
end

function default_source_paths()
    implementation_root = normpath(joinpath(@__DIR__, ".."))
    repository_root = normpath(joinpath(implementation_root, "..", ".."))
    ActivationSourcePaths(
        normpath(joinpath(implementation_root, "..", "convex_parity_distance",
                          "src", "ConvexParityDistance.jl")),
        normpath(joinpath(implementation_root, "..",
                          "convex_parity_distance_accelerated", "src",
                          "ConvexParityDistanceAccelerated.jl")),
        joinpath(@__DIR__, "activation_gate.jl"),
        joinpath(@__DIR__, "prepare_packet.jl"),
        joinpath(@__DIR__, "candidate_runner.jl"),
        joinpath(@__DIR__, "score_candidate.jl"),
        normpath(joinpath(implementation_root, "..", "convex_parity_distance",
                          "execution", "artifact_io.jl")),
        joinpath(@__DIR__, "artifact_io.jl"),
        joinpath(implementation_root, "Project.toml"),
        joinpath(implementation_root, "Manifest.toml"),
        joinpath(repository_root, "research",
                 "rq2_convex_parity_distance_snr_threshold_001_card.md"),
        OBJECTIVE_SOURCE_SHA256,
        ACCELERATED_SOURCE_SHA256,
    )
end

_file_sha256(path::AbstractString) = bytes2hex(open(sha256, path))

function _require_exact_keys(table, required, label)
    actual = Set(String.(keys(table)))
    expected = Set(String.(required))
    missing = sort!(collect(setdiff(expected, actual)))
    extra = sort!(collect(setdiff(actual, expected)))
    isempty(missing) || throw(ArgumentError(
        "$label is missing fields: $(join(missing, ", "))"))
    isempty(extra) || throw(ArgumentError(
        "$label has unregistered fields: $(join(extra, ", "))"))
    table
end

function _require_sha256(value, label)
    text = String(value)
    occursin(r"^[0-9a-f]{64}$", text) ||
        throw(ArgumentError("$label is not a lowercase SHA-256 digest"))
    text
end

function _source_path(sources::ActivationSourcePaths, name::Symbol)
    String(getfield(sources, name))
end

function _verify_source_hashes(table, sources::ActivationSourcePaths)
    required = String.(propertynames(HASH_FIELDS))
    _require_exact_keys(table, required, "activation hashes")
    hashes = Dict{String,String}()
    for field in propertynames(HASH_FIELDS)
        key = String(field)
        expected = _require_sha256(table[key], "activation hash $key")
        path = _source_path(sources, getfield(HASH_FIELDS, field))
        isfile(path) || throw(ArgumentError(
            "activation-bound source is missing for $key: $path"))
        actual = _file_sha256(path)
        actual == expected || throw(ArgumentError(
            "activation hash differs for $key: expected $expected, got $actual"))
        hashes[key] = actual
    end
    hashes["objective_source_sha256"] == sources.objective_expected_sha256 ||
        throw(ArgumentError("activation objective hash is not the frozen source pin"))
    hashes["accelerated_source_sha256"] ==
        sources.accelerated_expected_sha256 || throw(ArgumentError(
            "activation accelerated hash is not the frozen source pin"))
    hashes
end

function _snr_vector(value)
    value isa Vector || throw(ArgumentError(
        "activation snr_grid_db must be an ordered TOML array"))
    snrs = Float64[]
    for item in value
        item isa Real || throw(ArgumentError(
            "activation SNR values must be numeric"))
        snr = Float64(item)
        isfinite(snr) || throw(ArgumentError(
            "activation SNR values must be finite"))
        push!(snrs, snr)
    end
    isempty(snrs) && throw(ArgumentError("activation SNR grid is empty"))
    all(snrs[index] < snrs[index + 1] for index in 1:length(snrs)-1) ||
        throw(ArgumentError("activation SNR grid must be strictly increasing"))
    snrs
end

function _same_grid(left, right; atol=0.0)
    length(left) == length(right) || return false
    all(isapprox(Float64(left[index]), Float64(right[index]);
                 atol=atol, rtol=0.0) for index in eachindex(left))
end

function verify_activation(path::AbstractString;
        expected_stage::Union{Nothing,AbstractString}=nothing,
        expected_snrs::Union{Nothing,AbstractVector{<:Real}}=nothing,
        sources::ActivationSourcePaths=default_source_paths())
    activation_path = abspath(path)
    isfile(activation_path) || throw(ArgumentError(
        "stage activation is missing: $activation_path"))
    document = TOML.parsefile(activation_path)
    stage = get(document, "stage", nothing)
    stage isa AbstractString || throw(ArgumentError(
        "activation stage must be coarse or fine"))
    stage = String(stage)
    stage in ("coarse", "fine") || throw(ArgumentError(
        "activation stage must be coarse or fine"))
    top_keys = stage == "coarse" ?
        ["schema", "experiment_id", "stage", "snr_grid_db", "frame_first",
         "frame_last", "update_cap", "hashes"] :
        ["schema", "experiment_id", "stage", "snr_grid_db", "frame_first",
         "frame_last", "update_cap", "hashes", "coarse_result"]
    _require_exact_keys(document, top_keys, "stage activation")
    document["schema"] == ACTIVATION_SCHEMA || throw(ArgumentError(
        "activation schema differs"))
    document["experiment_id"] == EXPERIMENT_ID || throw(ArgumentError(
        "activation experiment ID differs"))
    update_cap = document["update_cap"]
    update_cap isa Integer && !isa(update_cap, Bool) || throw(ArgumentError(
        "activation update_cap must be an integer"))
    Int(update_cap) == UPDATE_CAP || throw(ArgumentError(
        "activation update cap must be 30"))
    frame_first = document["frame_first"]
    frame_last = document["frame_last"]
    all(value -> value isa Integer && !isa(value, Bool),
        (frame_first, frame_last)) || throw(ArgumentError(
            "activation frame endpoints must be integers"))
    frame_first = Int(frame_first)
    frame_last = Int(frame_last)
    registered_frames = stage == "coarse" ? (20_001, 20_024) : (30_001, 30_200)
    (frame_first, frame_last) == registered_frames || throw(ArgumentError(
        "activation frame range differs from the registered $stage stage"))
    snrs = _snr_vector(document["snr_grid_db"])

    coarse_crossing = nothing
    coarse_commit = nothing
    coarse_manifest = nothing
    if stage == "coarse"
        _same_grid(snrs, COARSE_SNRS) || throw(ArgumentError(
            "coarse activation requires the exact 1.5:0.5:12.0 dB grid"))
    else
        result = document["coarse_result"]
        result isa AbstractDict || throw(ArgumentError(
            "fine activation coarse_result must be a table"))
        _require_exact_keys(result,
            ["crossing_s_c_db", "score_commit_sha256",
             "score_manifest_sha256"], "fine activation coarse result")
        crossing = result["crossing_s_c_db"]
        crossing isa Real || throw(ArgumentError(
            "fine activation coarse crossing must be numeric"))
        coarse_crossing = Float64(crossing)
        isfinite(coarse_crossing) || throw(ArgumentError(
            "fine activation coarse crossing must be finite"))
        coarse_crossing in COARSE_SNRS || throw(ArgumentError(
            "fine activation coarse crossing is not a registered coarse level"))
        coarse_commit = _require_sha256(
            result["score_commit_sha256"], "coarse score commit hash")
        coarse_manifest = _require_sha256(
            result["score_manifest_sha256"], "coarse score manifest hash")
        expected_fine = [coarse_crossing - 0.5 + 0.1 * index for index in 0:10]
        _same_grid(snrs, expected_fine; atol=2.0e-12) || throw(ArgumentError(
            "fine activation grid must equal s_c-0.5:0.1:s_c+0.5"))
    end

    expected_stage === nothing || stage == String(expected_stage) ||
        throw(ArgumentError("requested stage differs from the activation"))
    if expected_snrs !== nothing
        tolerance = stage == "fine" ? 2.0e-12 : 0.0
        _same_grid(snrs, Float64.(expected_snrs); atol=tolerance) ||
            throw(ArgumentError("requested SNR grid differs from the activation"))
    end

    hashes = document["hashes"]
    hashes isa AbstractDict || throw(ArgumentError(
        "activation hashes must be a table"))
    source_hashes = _verify_source_hashes(hashes, sources)
    StageActivation(
        activation_path, _file_sha256(activation_path), stage, snrs,
        frame_first, frame_last, UPDATE_CAP, source_hashes, coarse_crossing,
        coarse_commit, coarse_manifest)
end

end # module
