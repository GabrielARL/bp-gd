#!/usr/bin/env julia

include(joinpath(@__DIR__, "..", "test_two_hop_positive_metric.jl"))
include(joinpath(@__DIR__, "local_finite_difference.jl"))
include(joinpath(@__DIR__, "local_stage_b_direction_kernel.jl"))
include(joinpath(@__DIR__, "local_jc_metric_direction.jl"))
include(joinpath(@__DIR__, "local_authoritative_jc_fixture.jl"))
include(joinpath(@__DIR__, "local_population_summary.jl"))
include(joinpath(@__DIR__, "local_target_specific_gates.jl"))
include(joinpath(@__DIR__, "local_origin_row_adapter.jl"))
include(joinpath(@__DIR__, "local_full_synthetic_population_chain.jl"))
include(joinpath(@__DIR__, "local_stage_c_decoder_source.jl"))
