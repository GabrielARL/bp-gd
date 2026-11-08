#!/usr/bin/env julia

# This is a maintainer-only provenance tool. Run it with the frozen
# JadeJcade project named below; the normal package test does not require
# JadeJcade or the historical worktree.

using Random
using SHA
using TOML

const HERE = @__DIR__
const PACKAGE_ROOT = normpath(joinpath(HERE, ".."))
const DEFAULT_FREEZE = normpath(joinpath(
    "/home/gabiel/Documents/GitHub",
    "sp_gd_admm-rq2-common-coordinate-state-update-20261104",
    "experiments", "rq2_native_composition_001", "freeze", "2026-11-01_v2"))
const FREEZE = get(ENV, "COMPOUND_BOX_ORACLE_FREEZE", DEFAULT_FREEZE)
const ORACLE_RUNNER = joinpath(FREEZE, "rq2_gd_residual_projection_budget_001",
                               "rq2_gd_residual_projection_budget_001.jl")
const ORACLE_CONFIG = joinpath(FREEZE, "rq2_gd_residual_projection_budget_001",
                               "config.toml")
const SPLIT_CONFIG = joinpath(FREEZE, "rq2_gd_parity_assignment_refresh_001",
    "vendor", "rq2_gd_offset_split_001", "config.toml")

isfile(ORACLE_RUNNER) || error("frozen oracle not found at $FREEZE")
include(joinpath(PACKAGE_ROOT, "src", "CompoundBoxGD.jl"))
using .CompoundBoxGD
include(ORACLE_RUNNER)
const Oracle = RQ2GDResidualProjectionBudget001

function qpsk_symbols(x::AbstractVector{<:Real})
    iseven(length(x)) || throw(ArgumentError("QPSK requires an even bit count"))
    symbols = Vector{ComplexF64}(undef, length(x) ÷ 2)
    scale = inv(sqrt(2.0))
    @inbounds for q in eachindex(symbols)
        symbols[q] = complex(x[2q - 1], x[2q]) * scale
    end
    symbols
end

function pinned_llr(split, frame::Int)
    n = Int(split["code"]["n"])
    variance = Float64(split["channel"]["noise_variance"])
    seed = Int(split["channel"]["noise_seed_base"]) + frame
    transmitted = qpsk_symbols(ones(Float64, n))
    rng = MersenneTwister(seed)
    unit_noise = complex.(randn(rng, length(transmitted)),
                          randn(rng, length(transmitted))) ./ sqrt(2.0)
    received = transmitted .+ sqrt(variance) .* unit_noise
    raw = Vector{Float64}(undef, n)
    scale = 2sqrt(2.0) / variance
    @inbounds for q in eachindex(received)
        raw[2q - 1] = scale * real(received[q])
        raw[2q] = scale * imag(received[q])
    end
    clipped = clamp.(raw, -Float64(split["channel"]["llr_clip"]),
                     Float64(split["channel"]["llr_clip"]))
    (; clipped, seed, received)
end

function graph_sha256(checks)
    io = IOBuffer()
    for check in checks
        write(io, htol(Int32(length(check))))
        for bit in check
            write(io, htol(Int32(bit)))
        end
    end
    bytes2hex(sha256(take!(io)))
end

function write_fixture(path, checks, llr)
    open(path, "w") do io
        write(io, codeunits("compound-box-fixture-v1\n"))
        write(io, htol(Int32(length(llr))))
        write(io, htol(Int32(length(checks))))
        for check in checks
            write(io, htol(Int32(length(check))))
            for bit in check
                write(io, htol(Int32(bit)))
            end
        end
        for value in llr
            write(io, htol(reinterpret(UInt64, Float64(value))))
        end
    end
end

function trace_at(result, update)
    only(row for row in result.traces if row.update == update)
end

function main()
    frame = 50025
    config = Oracle.load_config(ORACLE_CONFIG)
    split = TOML.parsefile(SPLIT_CONFIG)
    code = Oracle.make_bp_code(split, 80).code
    input = pinned_llr(split, frame)
    problem = Oracle.BridgeProblem(code, input.clipped;
        parity_weight=Float64(config["solver"]["parity_weight"]),
        binary_weight=Float64(config["solver"]["binary_weight"]))
    initial = tanh.(input.clipped ./ 2.0)
    seed = Oracle.common_update_one(problem, code, initial, split, config)
    oracle = Oracle.solve_arm(problem, code, initial, seed, Oracle.ARMS[1], config)

    portable = CompoundBoxGD.decode(code.check_vars, input.clipped;
                                    config=CompoundBoxGD.load_config())
    checkpoints = Dict{String,Any}()
    for update in (1, 30, 90)
        oracle_trace = trace_at(oracle, update)
        actual = portable.snapshots[update]
        expected_x = String(oracle_trace.x_after_sha256)
        expected_delta = String(oracle_trace.delta_sha256)
        actual.x_sha256 == expected_x || error("x mismatch at update $update")
        actual.delta_sha256 == expected_delta ||
            error("offset mismatch at update $update")
        expected_hard = update == 1 ?
            Oracle.vector_sha256(BitVector(value < 0.0 for value in seed.x)) :
            String(oracle.checkpoints[update].hard_word_sha256)
        actual.hard_sha256 == expected_hard ||
            error("hard-word mismatch at update $update")
        isequal(actual.objective, Float64(oracle_trace.loss_after)) ||
            error("objective mismatch at update $update")
        checkpoints[string(update)] = Dict(
            "x_sha256" => expected_x,
            "delta_sha256" => expected_delta,
            "hard_sha256" => expected_hard,
            "objective_float64_hex" => string(reinterpret(UInt64,
                Float64(oracle_trace.loss_after)); base=16, pad=16),
            "accepted_step_float64_hex" => string(reinterpret(UInt64,
                Float64(oracle_trace.accepted_step)); base=16, pad=16),
            "trial_count" => Int(oracle_trace.trial_count),
        )
    end
    portable.accepted_steps == oracle.accepted_steps ||
        error("accepted-step count differs")
    portable.status == oracle.status || error("terminal status differs")
    CompoundBoxGD.vector_sha256(portable.x) == Oracle.vector_sha256(oracle.x) ||
        error("terminal scalar state differs")
    CompoundBoxGD.edge_sha256(portable.delta) == Oracle.edge_sha256(oracle.delta) ||
        error("terminal offset state differs")

    fixture_dir = joinpath(HERE, "fixtures")
    mkpath(fixture_dir)
    fixture_path = joinpath(fixture_dir, "frame_50025.bin")
    write_fixture(fixture_path, code.check_vars, input.clipped)
    expected = Dict(
        "schema_version" => "compound-box-oracle-fixture/v1",
        "frame" => frame,
        "physical_esn0_db" => Float64(split["channel"]["physical_esn0_db"]),
        "noise_seed" => input.seed,
        "graph_sha256" => graph_sha256(code.check_vars),
        "llr_sha256" => CompoundBoxGD.vector_sha256(input.clipped),
        "fixture_sha256" => bytes2hex(open(sha256, fixture_path)),
        "oracle_runner_sha256" => bytes2hex(open(sha256, ORACLE_RUNNER)),
        "oracle_config_sha256" => bytes2hex(open(sha256, ORACLE_CONFIG)),
        "accepted_steps" => oracle.accepted_steps,
        "last_effective_update" => oracle.last_effective_update,
        "status" => oracle.status,
        "maximum_finite_difference_error_float64_hex" =>
            string(reinterpret(UInt64, oracle.maximum_finite_difference_error);
                   base=16, pad=16),
        "checkpoints" => checkpoints,
    )
    open(joinpath(fixture_dir, "frame_50025_expected.toml"), "w") do io
        TOML.print(io, expected; sorted=true)
    end
    println("frozen oracle and portable wrapper agree at updates 1, 30, and 90")
    println("fixture: ", fixture_path)
end

main()
