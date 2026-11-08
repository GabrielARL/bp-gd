using CompoundBoxGD
using LinearAlgebra
using SHA
using Test
using TOML

# The retained oracle used one Julia thread and one BLAS thread.  Set the BLAS
# count here as well so a caller's shell environment cannot alter the dot-product
# reduction order used by the exact objective-hash gate.
BLAS.set_num_threads(1)

const FIXTURE_DIR = joinpath(@__DIR__, "fixtures")
const FIXTURE_PATH = joinpath(FIXTURE_DIR, "frame_50025.bin")
const EXPECTED_PATH = joinpath(FIXTURE_DIR, "frame_50025_expected.toml")

@testset "execution environment" begin
    @test Threads.nthreads() == 1
    @test BLAS.get_num_threads() == 1
end

function read_fixture(path)
    open(path, "r") do io
        readline(io) == "compound-box-fixture-v1" ||
            error("unsupported fixture format")
        n = Int(ltoh(read(io, Int32)))
        check_count = Int(ltoh(read(io, Int32)))
        checks = Vector{Vector{Int}}(undef, check_count)
        for check_index in 1:check_count
            degree = Int(ltoh(read(io, Int32)))
            checks[check_index] = [Int(ltoh(read(io, Int32)))
                                   for _ in 1:degree]
        end
        llr = [reinterpret(Float64, ltoh(read(io, UInt64))) for _ in 1:n]
        eof(io) || error("fixture contains trailing bytes")
        (; checks, llr)
    end
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

float_hex(value::Float64) = string(reinterpret(UInt64, value); base=16, pad=16)

@testset "fixture provenance" begin
    expected = TOML.parsefile(EXPECTED_PATH)
    fixture = read_fixture(FIXTURE_PATH)
    @test expected["schema_version"] == "compound-box-oracle-fixture/v1"
    @test expected["frame"] == 50025
    @test expected["physical_esn0_db"] == 6.0
    @test expected["noise_seed"] == 20311037
    @test bytes2hex(open(sha256, FIXTURE_PATH)) == expected["fixture_sha256"]
    @test graph_sha256(fixture.checks) == expected["graph_sha256"]
    @test vector_sha256(fixture.llr) == expected["llr_sha256"]
    @test length(fixture.llr) == 10_200
    @test length(fixture.checks) == 5_100
    @test all(length(check) == 6 for check in fixture.checks)
end

@testset "bounded mean projection" begin
    q = [-2.0, 0.1, 2.4]
    z = bounded_mean_projection(q, 0.25)
    @test all(-1.0 .<= z .<= 1.0)
    @test sum(z) ≈ 3 * 0.25 atol=2e-12 rtol=0.0
    @test bounded_mean_projection([0.0, 0.0, 0.0], -1.0) == fill(-1.0, 3)
    @test bounded_mean_projection([0.0, 0.0, 0.0], 1.0) == fill(1.0, 3)
end

@testset "frozen compound__box equivalence" begin
    expected = TOML.parsefile(EXPECTED_PATH)
    fixture = read_fixture(FIXTURE_PATH)
    config = load_config()
    result = decode(fixture.checks, fixture.llr;
                    config, validate_derivatives=true)

    @test result.status == expected["status"] == "steps_completed"
    @test result.accepted_steps == expected["accepted_steps"] == 90
    @test result.last_effective_update == expected["last_effective_update"] == 90
    @test result.all_strict_decrease
    @test result.maximum_finite_difference_error <=
        config.finite_difference_tolerance
    @test float_hex(result.maximum_finite_difference_error) ==
        expected["maximum_finite_difference_error_float64_hex"]
    @test result.maximum_offset_mean_error <= config.mean_tolerance
    @test minimum(result.x) >= config.lower - config.box_tolerance
    @test maximum(result.x) <= config.upper + config.box_tolerance
    @test count(result.hard) == 0
    @test count(result.syndrome) == 0

    retained_delta_hash = expected["checkpoints"]["1"]["delta_sha256"]
    @test all(row.accepted for row in result.trace)
    @test all(row.loss_after < row.loss_before for row in result.trace)
    @test all(row.delta_sha256 == retained_delta_hash for row in result.trace)

    problem = Problem(fixture.checks, fixture.llr;
        parity_weight=config.parity_weight,
        binary_weight=config.binary_weight)
    for update in (1, 30, 90)
        checkpoint = expected["checkpoints"][string(update)]
        actual = result.snapshots[update]
        trace = only(row for row in result.trace if row.update == update)
        @test actual.x_sha256 == checkpoint["x_sha256"]
        @test actual.delta_sha256 == checkpoint["delta_sha256"]
        @test actual.hard_sha256 == checkpoint["hard_sha256"]
        @test float_hex(actual.objective) == checkpoint["objective_float64_hex"]
        @test isequal(actual.accepted_objective, actual.objective)
        recomputed = objective_gradient(problem, actual.x, actual.delta).loss
        @test isequal(actual.stored_state_objective, recomputed)
        @test float_hex(trace.accepted_step) ==
            checkpoint["accepted_step_float64_hex"]
        @test trace.trial_count == checkpoint["trial_count"]
    end

    first = result.snapshots[1]
    @test !isequal(first.stored_state_objective, first.accepted_objective)
    @test isequal(result.snapshots[30].stored_state_objective,
                  result.snapshots[30].accepted_objective)
    @test isequal(result.snapshots[90].stored_state_objective,
                  result.snapshots[90].accepted_objective)
    maximum_reading = maximum(abs(first.x[bit] + first.delta[check_index][slot])
        for (check_index, check) in enumerate(fixture.checks)
        for (slot, bit) in enumerate(check))
    @test maximum_reading <= 1.0 + config.box_tolerance

    for bit in eachindex(problem.var_edges)
        offset_sum = sum(first.delta[check_index][slot]
            for (check_index, slot) in problem.var_edges[bit])
        @test abs(offset_sum) <= config.mean_tolerance
    end
end
