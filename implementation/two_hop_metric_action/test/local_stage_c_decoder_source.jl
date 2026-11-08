#!/usr/bin/env julia

using SHA
using Test
using LinearAlgebra

if !isdefined(Main, :RQ2TwoHopStageCDecoderSource)
    include(joinpath(@__DIR__, "..", "stage_c_decoder_source.jl"))
end
if !isdefined(Main, :RQ2TwoHopStageCTraceIntegrity)
    include(joinpath(@__DIR__, "..", "stage_c_trace_integrity.jl"))
end

const StageCSource = RQ2TwoHopStageCDecoderSource
const StageCIntegrity = RQ2TwoHopStageCTraceIntegrity
const StageCMetric = StageCSource.Metric
const StageCObjective = StageCSource.Objective

function stage_c_synthetic_case()
    # Every variable has degree two, so the registered diagonal is scalar and
    # the full condition bound equals the registered relative bound.
    graph = StageCMetric.EdgeGraph([[1, 2, 3], [1, 2, 3]], 3)
    llr = [1.3, -0.8, -0.6]
    coefficients = StageCMetric.MetricCoefficients(
        0.0,
        [-0.098969711158939794,
         -0.19129556359240465,
         -0.70584476358886339,
         -0.0036899816577923542],
    )
    (; graph, llr, coefficients)
end

stage_c_bits(values) = reinterpret(UInt64, Float64.(values))

function stage_c_trace_with(trace, field::Symbol, value)
    names = fieldnames(typeof(trace))
    field in names || error("unknown trace field: $field")
    values = ntuple(
        index -> names[index] == field ? value : getfield(trace, index),
        length(names))
    typeof(trace)(values...)
end

function stage_c_row_with(row::NamedTuple, field::Symbol, value)
    hasproperty(row, field) || error("unknown row field: $field")
    merge(row, NamedTuple{(field,)}((value,)))
end

function stage_c_trace_row_with(trace, collection::Symbol, index::Int,
                                field::Symbol, value)
    rows = copy(getproperty(trace, collection))
    rows[index] = stage_c_row_with(rows[index], field, value)
    stage_c_trace_with(trace, collection, rows)
end

function stage_c_traces_equal(left, right)
    typeof(left) === typeof(right) || return false
    all(name -> isequal(getproperty(left, name), getproperty(right, name)),
        fieldnames(typeof(left)))
end

function stage_c_six_variable_case(llr)
    graph = StageCMetric.EdgeGraph(
        [[1, 2, 3], [3, 4, 5], [5, 6, 1], [2, 4, 6]], 6)
    coefficients = stage_c_synthetic_case().coefficients
    (; graph, llr=Float64.(llr), coefficients)
end

function stage_c_signed_bits_equal(observed, reference, signs)
    length(observed) == length(reference) == length(signs) || return false
    all(index -> reinterpret(UInt64, Float64(observed[index])) ==
                 reinterpret(UInt64,
                     Float64(signs[index]) * Float64(reference[index])),
        eachindex(observed, reference, signs))
end

function run_direct_lower_reference(graph, llr;
                                    constants=StageCSource.DecoderConstants())
    state = StageCSource.initialize_edge_state(graph, llr)
    terminal_status = "update_cap_reached"
    rows = NamedTuple[]
    trials = NamedTuple[]
    for update in 1:constants.maximum_update_attempts
        current = StageCObjective.evaluate_objective(graph, llr, state)
        metric = StageCObjective.fixed_metric_diagonal(graph)
        direction = StageCMetric.baseline_direction(
            current.partial_derivatives, metric)
        result = StageCSource._projected_armijo_step(
            graph, llr, state, current, direction;
            update, constants, capture_vectors=true)
        append!(trials, result.rows)
        push!(rows, (;
            update, accepted=result.accepted,
            state_before=copy(state), direction=copy(direction),
            state_after=copy(result.state),
            trial_count=result.trial_count,
            accepted_step=result.accepted_step))
        if !result.accepted
            terminal_status = "line_search_stalled"
            break
        end
        state = result.state
    end
    (; terminal_state=state, rows, trials, status=terminal_status)
end

const STAGE_C_DENSE_ATOL = 3.0e-13
const STAGE_C_DENSE_RTOL = 3.0e-13

function stage_c_ordered_product_excluding(graph, state, check, omitted)
    product = 1.0
    for edge in graph.check_edges[check]
        edge in omitted && continue
        product *= Float64(state[edge])
    end
    product
end

function stage_c_dense_family_matrix(graph, state, llr, family)
    edges = StageCMetric.edge_count(graph)
    matrix = zeros(Float64, edges, edges)
    0 <= family < StageCMetric.FAMILY_COUNT ||
        error("invalid dense test family")
    for output_edge in 1:edges
        variable = graph.edge_variable[output_edge]
        output_check = graph.edge_check[output_edge]
        h_i = clamp(Float64(llr[variable]), -20.0, 20.0) / 20.0
        for recipient_edge in graph.variable_edges[variable]
            source_check = graph.edge_check[recipient_edge]
            source_check == output_check && continue
            p_i_c = stage_c_ordered_product_excluding(
                graph, state, source_check, (recipient_edge,))
            for source_edge in graph.check_edges[source_check]
                graph.edge_variable[source_edge] == variable && continue
                r_j_c_i = stage_c_ordered_product_excluding(
                    graph, state, source_check,
                    (recipient_edge, source_edge))
                u = if family == 0
                    1.0
                elseif family == 1
                    h_i * p_i_c
                elseif family == 2
                    Float64(state[output_edge]) * p_i_c
                else
                    h_i * Float64(state[output_edge])
                end
                weight = u * r_j_c_i
                matrix[output_edge, source_edge] += weight
                matrix[source_edge, output_edge] += weight
            end
        end
    end
    normalization = max(
        1.0, maximum(vec(sum(abs, matrix; dims=2))))
    matrix ./ normalization
end

function stage_c_dense_metric_diagonal(graph)
    diagonal = Vector{Float64}(undef, StageCMetric.edge_count(graph))
    for variable in 1:graph.n
        incident = graph.variable_edges[variable]
        degree = length(incident)
        value = (
            2.0 * StageCObjective.PARITY_WEIGHT * degree +
            8.0 * StageCObjective.BINARY_WEIGHT
        ) / (graph.n * degree)
        diagonal[incident] .= value
    end
    diagonal
end

function stage_c_dense_direction(graph, state, llr, gradient, coefficients)
    edges = StageCMetric.edge_count(graph)
    matrix = (1.0 + coefficients.theta0) .*
        Matrix{Float64}(I, edges, edges)
    for family in 0:(StageCMetric.FAMILY_COUNT - 1)
        matrix .+= coefficients.beta[family + 1] .*
            stage_c_dense_family_matrix(
                graph, state, llr, family)
    end
    metric_diagonal = stage_c_dense_metric_diagonal(graph)
    inverse_square_root = Diagonal(1.0 ./ sqrt.(metric_diagonal))
    -(inverse_square_root * matrix * inverse_square_root) * gradient
end

function stage_c_dense_diagnostics(graph, state)
    readout = Vector{Float64}(undef, graph.n)
    for variable in 1:graph.n
        incident = graph.variable_edges[variable]
        anchor = Float64(state[first(incident)])
        readout[variable] = anchor +
            sum(Float64(state[edge]) - anchor for edge in incident) /
            length(incident)
    end
    hard_bits = BitVector(readout .< 0.0)
    syndrome = BitVector([
        isodd(count(variable -> hard_bits[variable], members))
        for members in graph.checks
    ])
    (; readout, hard_bits, syndrome,
       syndrome_weight=count(identity, syndrome),
       zero_readout_ties=count(iszero, readout))
end

function run_dense_candidate_path(
        graph, llr, coefficients;
        constants=StageCSource.DecoderConstants())
    state = [
        tanh(Float64(llr[graph.edge_variable[edge]]) / 2.0)
        for edge in eachindex(graph.edge_variable)
    ]
    initial_diagnostics = stage_c_dense_diagnostics(graph, state)
    first_parity_valid_update =
        initial_diagnostics.syndrome_weight == 0 ? 0 : nothing
    rows = NamedTuple[]
    trials = NamedTuple[]
    attempted_updates = 0
    accepted_updates = 0
    status = "update_cap_reached"
    for update in 1:constants.maximum_update_attempts
        attempted_updates = update
        current = StageCObjective.evaluate_objective(graph, llr, state)
        direction = stage_c_dense_direction(
            graph, state, llr, current.partial_derivatives, coefficients)
        accepted = false
        state_before = copy(state)
        first_trial = length(trials) + 1
        accepted_step = 0.0
        for backtrack in 0:constants.maximum_backtracks
            step = 2.0^(-backtrack)
            raw = state_before .+ step .* direction
            projected = clamp.(raw, -1.0, 1.0)
            displacement = projected .- state_before
            descent_product = dot(
                current.partial_derivatives, displacement)
            armijo_rhs = Float64(current.value) +
                constants.armijo_constant * descent_product
            trial_evaluation = StageCObjective.evaluate_objective(
                graph, llr, projected)
            strict_descent = descent_product < 0.0
            sufficient_decrease = trial_evaluation.value <= armijo_rhs
            accepted = strict_descent && sufficient_decrease
            rejection_reason = accepted ? "accepted" :
                !strict_descent ? "not_strict_descent" :
                "insufficient_decrease"
            push!(trials, (;
                update, backtrack, trial_ordinal=backtrack + 1, step,
                accepted, strict_descent, sufficient_decrease,
                rejection_reason,
                raw_state=raw, projected_state=projected,
                trial_objective=Float64(trial_evaluation.value),
                armijo_rhs, descent_product))
            if accepted
                state = projected
                accepted_step = step
                accepted_updates += 1
                diagnostics = stage_c_dense_diagnostics(graph, state)
                if first_parity_valid_update === nothing &&
                        diagnostics.syndrome_weight == 0
                    first_parity_valid_update = update
                end
                break
            end
        end
        trial_count = length(trials) - first_trial + 1
        push!(rows, (;
            update, accepted, trial_count, accepted_step,
            objective_before=Float64(current.value),
            objective_after=accepted ? trials[end].trial_objective :
                Float64(current.value),
            state_before, state_after=copy(state),
            partial_derivatives=copy(current.partial_derivatives),
            direction))
        if !accepted
            status = "line_search_stalled"
            break
        end
    end
    (; terminal_state=copy(state), rows, trials, status,
       attempted_updates, accepted_updates, first_parity_valid_update,
       initial_diagnostics,
       terminal_diagnostics=stage_c_dense_diagnostics(graph, state))
end

function stage_c_collapse_to_incident_means(graph, values)
    collapsed = Float64.(values)
    for incident in graph.variable_edges
        anchor = collapsed[first(incident)]
        mean_value = anchor +
            sum(collapsed[edge] - anchor for edge in incident) /
            length(incident)
        for edge in incident
            collapsed[edge] = mean_value
        end
    end
    collapsed
end

stage_c_within_bit_null(graph, values) =
    Float64.(values) .- stage_c_collapse_to_incident_means(graph, values)

@testset "Stage-C source identity and fixed protocol" begin
    root = joinpath(@__DIR__, "..")
    metric_path = StageCSource.METRIC_SOURCE_PATH
    objective_path = StageCSource.OBJECTIVE_SOURCE_PATH
    source_path = joinpath(root, "stage_c_decoder_source.jl")
    @test bytes2hex(sha256(read(metric_path))) ==
          StageCSource.METRIC_SOURCE_SHA256
    @test bytes2hex(sha256(read(objective_path))) ==
          StageCSource.OBJECTIVE_SOURCE_SHA256
    @test isfile(source_path) && all(
        name -> !occursin("projected_armijo_step", String(name)),
        names(StageCSource))
    @test StageCSource.SCHEMA_VERSION ==
          "rq2-two-hop-positive-metric-001/stage-c-decoder-source-preparation-v1"

    constants = StageCSource.DecoderConstants()
    @test constants.armijo_constant == 1.0e-4
    @test constants.maximum_backtracks == 12
    @test constants.maximum_update_attempts == 30
    case = stage_c_synthetic_case()
    @test_throws ErrorException StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients;
        constants=StageCSource.DecoderConstants(2.0e-4, 12, 30))
    @test_throws ErrorException StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients;
        constants=StageCSource.DecoderConstants(1.0e-4, 11, 30))
    @test_throws ErrorException StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients;
        constants=StageCSource.DecoderConstants(1.0e-4, 12, 29))
    nonuniform_graph = StageCMetric.EdgeGraph([[1, 2], [2, 3]], 3)
    @test_throws ErrorException StageCSource.run_candidate_decoder(
        nonuniform_graph, zeros(3), case.coefficients)
    bypassed = StageCMetric.MetricCoefficients(
        -0.5, (0.1, 0.0, 0.0, 0.0))
    @test !StageCMetric.coefficient_admissibility(
        bypassed.theta0, bypassed.beta).admissible
    @test_throws ArgumentError StageCSource.run_candidate_decoder(
        case.graph, case.llr, bypassed)
end

@testset "clipped initialization and centered strict-negative readout" begin
    case = stage_c_synthetic_case()
    initial = StageCSource.initialize_edge_state(case.graph, case.llr)
    expected = [tanh(case.llr[case.graph.edge_variable[edge]] / 2.0)
                for edge in 1:StageCMetric.edge_count(case.graph)]
    @test stage_c_bits(initial) == stage_c_bits(expected)
    @test initial[1] == initial[4]
    @test initial[2] == initial[5]
    @test initial[3] == initial[6]
    @test_throws DimensionMismatch StageCSource.initialize_edge_state(
        case.graph, case.llr[1:2])
    @test_throws DomainError StageCSource.initialize_edge_state(
        case.graph, [21.0, case.llr[2], case.llr[3]])
    @test_throws DomainError StageCSource.initialize_edge_state(
        case.graph, [NaN, case.llr[2], case.llr[3]])

    state = [0.8, -0.6, 0.0, 0.2, -0.2, -0.0]
    diagnostics = StageCSource.readout_diagnostics(case.graph, state)
    @test stage_c_bits(diagnostics.readout) == stage_c_bits([0.5, -0.4, 0.0])
    @test diagnostics.hard_bits == BitVector([false, true, false])
    @test diagnostics.syndrome == BitVector([true, true])
    @test diagnostics.syndrome_weight == 2
    @test diagnostics.zero_readout_ties == 1
end

@testset "projected Armijo backtracking and exact 13-trial stall" begin
    case = stage_c_synthetic_case()
    state = [0.2, 0.2, -0.9, -0.9, -0.9, -0.9]
    current = StageCObjective.evaluate_objective(
        case.graph, case.llr, state)
    direction = -2.0 .* current.partial_derivatives
    accepted = StageCSource._projected_armijo_step(
        case.graph, case.llr, state, current, direction;
        update=1, constants=StageCSource.DecoderConstants(),
        capture_vectors=true)
    @test accepted.accepted
    @test accepted.accepted_step == 0.5
    @test accepted.trial_count == 2
    @test maximum(abs, accepted.rows[1].raw_state) > 1.0
    @test maximum(abs, accepted.rows[1].projected_state) == 1.0
    @test accepted.rows[1].descent_product == dot(
        current.partial_derivatives,
        accepted.rows[1].projected_state .- state)
    @test accepted.rows[1].strict_descent
    @test !accepted.rows[1].sufficient_decrease
    @test !accepted.rows[1].accepted &&
          accepted.rows[1].rejection_reason == "insufficient_decrease"
    @test accepted.rows[2].accepted &&
          accepted.rows[2].sufficient_decrease &&
          accepted.rows[2].trial_objective <= accepted.rows[2].armijo_rhs

    stalled = StageCSource._projected_armijo_step(
        case.graph, case.llr, state, current, zeros(length(state));
        update=1, constants=StageCSource.DecoderConstants(),
        capture_vectors=true)
    @test !stalled.accepted
    @test stalled.accepted_step == 0.0
    @test stalled.trial_count == 13
    @test length(stalled.rows) == 13
    @test all(row -> row.rejection_reason == "not_strict_descent",
              stalled.rows)
    @test all(row -> !row.accepted && !row.strict_descent, stalled.rows)
    @test stage_c_bits(stalled.state) == stage_c_bits(state)
    @test [row.step for row in stalled.rows] ==
          [2.0^(-backtrack) for backtrack in 0:12]
end

@testset "candidate recomputes J_C and the state-dependent action" begin
    case = stage_c_synthetic_case()
    llr_before = copy(case.llr)
    trace = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    pattern = StageCMetric.TwoHopPattern(case.graph)
    metric = StageCObjective.fixed_metric_diagonal(case.graph)

    @test trace.schema_version == StageCSource.SCHEMA_VERSION
    @test trace.status == "update_cap_reached"
    @test trace.attempted_updates == 30
    @test trace.accepted_updates == 30
    @test trace.first_parity_valid_update == 0
    @test length(trace.iteration_rows) == 30
    @test length(trace.state_rows) == 31
    @test length(trace.trial_rows) == 30
    @test trace.initial_diagnostics.syndrome_weight == 0
    @test stage_c_bits(case.llr) == stage_c_bits(llr_before)

    previous_after = trace.initial_state
    distinct_direction_hashes = Set{String}()
    for row in trace.iteration_rows
        @test row.accepted
        @test stage_c_bits(row.state_before) == stage_c_bits(previous_after)
        evaluation = StageCObjective.evaluate_objective(
            case.graph, case.llr, row.state_before)
        action = StageCMetric.generic_metric_action(
            case.graph, pattern, row.state_before, case.llr,
            evaluation.partial_derivatives, metric, case.coefficients)
        @test stage_c_bits(row.partial_derivatives) ==
              stage_c_bits(evaluation.partial_derivatives)
        @test stage_c_bits(row.direction) == stage_c_bits(action.direction)
        @test row.partial_derivatives_sha256 ==
              StageCSource.vector_sha256(evaluation.partial_derivatives)
        @test row.direction_sha256 ==
              StageCSource.vector_sha256(action.direction)
        @test row.condition == action.condition
        @test row.family_normalizations == action.family_normalizations
        @test row.family_row_sum_bounds == action.family_row_sum_bounds
        @test row.condition.relative_condition_bound <= 1.0e4
        @test row.condition.full_euclidean_condition_bound <= 1.0e4
        @test row.descent_product < 0.0
        @test row.objective_after <= row.armijo_rhs
        @test row.objective_after <= row.objective_before
        @test row.state_after_sha256 ==
              StageCSource.vector_sha256(row.state_after)
        push!(distinct_direction_hashes, row.direction_sha256)
        previous_after = row.state_after
    end
    @test length(distinct_direction_hashes) > 1
    @test stage_c_bits(previous_after) == stage_c_bits(trace.terminal_state)

    for trial in trace.trial_rows
        row = trace.iteration_rows[trial.update]
        expected_raw = row.state_before .+ trial.step .* row.direction
        expected_projected = clamp.(expected_raw, -1.0, 1.0)
        @test stage_c_bits(trial.raw_state) == stage_c_bits(expected_raw)
        @test stage_c_bits(trial.projected_state) ==
              stage_c_bits(expected_projected)
        @test trial.current_state_sha256 == row.state_before_sha256
        @test trial.projected_state_sha256 == row.state_after_sha256
        @test trial.trial_ordinal == trial.backtrack + 1
        @test trial.accepted
    end
end

@testset "exact-zero generic path equals a direct fixed-diagonal reference" begin
    case = stage_c_synthetic_case()
    control = StageCSource.run_lower_endpoint_decoder(
        case.graph, case.llr; capture_vectors=true)
    reference = run_direct_lower_reference(case.graph, case.llr)
    @test control.status == reference.status
    @test control.attempted_updates == length(reference.rows)
    @test length(control.iteration_rows) == length(reference.rows)
    @test length(control.trial_rows) == length(reference.trials)
    @test stage_c_bits(control.terminal_state) ==
          stage_c_bits(reference.terminal_state)

    for (observed, expected) in zip(control.iteration_rows, reference.rows)
        @test observed.update == expected.update
        @test observed.accepted == expected.accepted
        @test observed.trial_count == expected.trial_count
        @test observed.accepted_step == expected.accepted_step
        @test stage_c_bits(observed.state_before) ==
              stage_c_bits(expected.state_before)
        @test stage_c_bits(observed.direction) ==
              stage_c_bits(expected.direction)
        @test stage_c_bits(observed.state_after) ==
              stage_c_bits(expected.state_after)
    end
    for (observed, expected) in zip(control.trial_rows, reference.trials)
        @test observed.update == expected.update
        @test observed.backtrack == expected.backtrack
        @test observed.accepted == expected.accepted
        @test observed.rejection_reason == expected.rejection_reason
        @test reinterpret(UInt64, observed.trial_objective) ==
              reinterpret(UInt64, expected.trial_objective)
        @test reinterpret(UInt64, observed.armijo_rhs) ==
              reinterpret(UInt64, expected.armijo_rhs)
        @test reinterpret(UInt64, observed.descent_product) ==
              reinterpret(UInt64, expected.descent_product)
        @test stage_c_bits(observed.raw_state) ==
              stage_c_bits(expected.raw_state)
        @test stage_c_bits(observed.projected_state) ==
              stage_c_bits(expected.projected_state)
    end

    zero = StageCMetric.MetricCoefficients(
        zeros(Float64, StageCMetric.FAMILY_COUNT + 1))
    @test_throws ArgumentError StageCSource.run_candidate_decoder(
        case.graph, case.llr, zero)
end

@testset "independent dense matrix reproduces complete candidate paths" begin
    cases = (
        stage_c_synthetic_case(),
        stage_c_six_variable_case(
            [0.04, 0.17, 0.21, 0.16, 0.04, -0.07]),
    )
    for case in cases
        observed = StageCSource.run_candidate_decoder(
            case.graph, case.llr, case.coefficients; capture_vectors=true)
        dense = run_dense_candidate_path(
            case.graph, case.llr, case.coefficients)
        @test observed.status == dense.status
        @test observed.attempted_updates == dense.attempted_updates
        @test observed.accepted_updates == dense.accepted_updates
        @test observed.first_parity_valid_update ==
              dense.first_parity_valid_update
        @test length(observed.iteration_rows) == length(dense.rows)
        @test length(observed.trial_rows) == length(dense.trials)
        @test isapprox(
            observed.terminal_state, dense.terminal_state;
            atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
        for (production, independent) in
                zip(observed.iteration_rows, dense.rows)
            @test production.update == independent.update
            @test production.accepted == independent.accepted
            @test production.trial_count == independent.trial_count
            @test production.accepted_step == independent.accepted_step
            @test isapprox(
                production.objective_before, independent.objective_before;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.objective_after, independent.objective_after;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.state_before, independent.state_before;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.partial_derivatives,
                independent.partial_derivatives;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.direction, independent.direction;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.state_after, independent.state_after;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
        end
        for (production, independent) in
                zip(observed.trial_rows, dense.trials)
            @test production.update == independent.update
            @test production.backtrack == independent.backtrack
            @test production.trial_ordinal == independent.trial_ordinal
            @test production.step == independent.step
            @test production.accepted == independent.accepted
            @test production.strict_descent == independent.strict_descent
            @test production.sufficient_decrease ==
                  independent.sufficient_decrease
            @test production.rejection_reason == independent.rejection_reason
            @test isapprox(
                production.trial_objective, independent.trial_objective;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.armijo_rhs, independent.armijo_rhs;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.descent_product, independent.descent_product;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.raw_state, independent.raw_state;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
            @test isapprox(
                production.projected_state, independent.projected_state;
                atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
        end
        @test isapprox(
            observed.initial_diagnostics.readout,
            dense.initial_diagnostics.readout;
            atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
        @test observed.initial_diagnostics.hard_bits ==
              dense.initial_diagnostics.hard_bits
        @test observed.initial_diagnostics.syndrome ==
              dense.initial_diagnostics.syndrome
        @test isapprox(
            observed.terminal_diagnostics.readout,
            dense.terminal_diagnostics.readout;
            atol=STAGE_C_DENSE_ATOL, rtol=STAGE_C_DENSE_RTOL)
        @test observed.terminal_diagnostics.hard_bits ==
              dense.terminal_diagnostics.hard_bits
        @test observed.terminal_diagnostics.syndrome ==
              dense.terminal_diagnostics.syndrome
        @test observed.terminal_diagnostics.syndrome_weight ==
              dense.terminal_diagnostics.syndrome_weight
        @test observed.terminal_diagnostics.zero_readout_ties ==
              dense.terminal_diagnostics.zero_readout_ties
    end
end

@testset "nondegenerate path activates recipient-excluded edge state" begin
    case = stage_c_six_variable_case([4.0, -3.0, 2.0, -1.0, 0.5, -0.2])
    candidate = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    first_row = candidate.iteration_rows[1]
    direction_null = stage_c_within_bit_null(
        case.graph, first_row.direction)
    displacement_null = stage_c_within_bit_null(
        case.graph, first_row.state_after .- first_row.state_before)
    @test maximum(abs, direction_null) > 2.5e-3
    @test maximum(abs, displacement_null) > 2.5e-3

    collapsed = stage_c_collapse_to_incident_means(
        case.graph, first_row.state_after)
    full_evaluation = StageCObjective.evaluate_objective(
        case.graph, case.llr, first_row.state_after)
    collapsed_evaluation = StageCObjective.evaluate_objective(
        case.graph, case.llr, collapsed)
    @test reinterpret(UInt64, full_evaluation.value) ==
          reinterpret(UInt64, collapsed_evaluation.value)
    @test stage_c_bits(full_evaluation.partial_derivatives) ==
          stage_c_bits(collapsed_evaluation.partial_derivatives)

    pattern = StageCMetric.TwoHopPattern(case.graph)
    metric = StageCObjective.fixed_metric_diagonal(case.graph)
    full_action = StageCMetric.generic_metric_action(
        case.graph, pattern, first_row.state_after, case.llr,
        full_evaluation.partial_derivatives, metric, case.coefficients)
    collapsed_action = StageCMetric.generic_metric_action(
        case.graph, pattern, collapsed, case.llr,
        collapsed_evaluation.partial_derivatives, metric, case.coefficients)
    @test maximum(abs, full_action.direction .- collapsed_action.direction) >
          5.0e-4

    control = StageCSource.run_lower_endpoint_decoder(
        case.graph, case.llr; capture_vectors=true)
    @test maximum(abs, stage_c_within_bit_null(
        case.graph, control.iteration_rows[1].direction)) == 0.0
end

@testset "fixed-diagonal projected-gradient diagnostic distinguishes stalls" begin
    case = stage_c_six_variable_case(
        [0.04, 0.17, 0.21, 0.16, 0.04, -0.07])
    candidate = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    @test candidate.status == "line_search_stalled"
    terminal = candidate.terminal_state
    current = StageCObjective.evaluate_objective(
        case.graph, case.llr, terminal)
    stalled_row = candidate.iteration_rows[end]
    @test stage_c_bits(stalled_row.state_before) == stage_c_bits(terminal)
    @test dot(current.partial_derivatives, stalled_row.direction) < 0.0
    final_trials = filter(
        row -> row.update == candidate.attempted_updates,
        candidate.trial_rows)
    @test length(final_trials) == 13
    @test all(row -> row.rejection_reason == "not_strict_descent",
              final_trials)
    @test all(row -> row.descent_product > 0.0, final_trials)

    metric = StageCObjective.fixed_metric_diagonal(case.graph)
    eta = 0.2
    projected = clamp.(
        terminal .- eta .* current.partial_derivatives ./ metric,
        -1.0, 1.0)
    mapping = (terminal .- projected) ./ eta
    displacement = projected .- terminal
    projected_evaluation = StageCObjective.evaluate_objective(
        case.graph, case.llr, projected)
    @test norm(mapping) > 1.0e-2
    @test dot(current.partial_derivatives, displacement) < 0.0
    @test projected_evaluation.value < current.value

    control = StageCSource.run_lower_endpoint_decoder(
        case.graph, case.llr; capture_vectors=true)
    @test control.status == "line_search_stalled"
    control_terminal = control.terminal_state
    control_evaluation = StageCObjective.evaluate_objective(
        case.graph, case.llr, control_terminal)
    control_projected = clamp.(
        control_terminal .-
            eta .* control_evaluation.partial_derivatives ./ metric,
        -1.0, 1.0)
    @test stage_c_bits(control_projected) == stage_c_bits(control_terminal)
    @test norm((control_terminal .- control_projected) ./ eta) == 0.0
end

@testset "valid-codeword sign covariance through every state and trial" begin
    case = stage_c_synthetic_case()
    signs = [-1.0, -1.0, 1.0]
    edge_signs = [signs[case.graph.edge_variable[edge]]
                  for edge in 1:StageCMetric.edge_count(case.graph)]
    left = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    right = StageCSource.run_candidate_decoder(
        case.graph, signs .* case.llr, case.coefficients;
        capture_vectors=true)
    @test left.status == right.status
    @test left.attempted_updates == right.attempted_updates
    @test left.accepted_updates == right.accepted_updates
    @test left.first_parity_valid_update == right.first_parity_valid_update
    @test stage_c_signed_bits_equal(
        right.initial_state, left.initial_state, edge_signs)
    @test stage_c_signed_bits_equal(
        right.terminal_state, left.terminal_state, edge_signs)

    for (a, b) in zip(left.state_rows, right.state_rows)
        @test a.update == b.update
        @test reinterpret(UInt64, a.objective_value) ==
              reinterpret(UInt64, b.objective_value)
        @test stage_c_signed_bits_equal(b.state, a.state, edge_signs)
        @test stage_c_signed_bits_equal(
            b.partial_derivatives, a.partial_derivatives, edge_signs)
        @test stage_c_signed_bits_equal(b.readout, a.readout, signs)
        @test a.syndrome_weight == b.syndrome_weight
        @test a.zero_readout_ties == b.zero_readout_ties
    end
    for (a, b) in zip(left.trial_rows, right.trial_rows)
        @test a.update == b.update
        @test a.backtrack == b.backtrack
        @test a.accepted == b.accepted
        @test a.rejection_reason == b.rejection_reason
        @test reinterpret(UInt64, a.trial_objective) ==
              reinterpret(UInt64, b.trial_objective)
        @test reinterpret(UInt64, a.armijo_rhs) ==
              reinterpret(UInt64, b.armijo_rhs)
        @test reinterpret(UInt64, a.descent_product) ==
              reinterpret(UInt64, b.descent_product)
        @test stage_c_signed_bits_equal(
            b.current_state, a.current_state, edge_signs)
        @test stage_c_signed_bits_equal(b.raw_state, a.raw_state, edge_signs)
        @test stage_c_signed_bits_equal(
            b.projected_state, a.projected_state, edge_signs)
    end
    for (a, b) in zip(left.iteration_rows, right.iteration_rows)
        @test a.update == b.update
        @test a.accepted == b.accepted
        @test a.trial_count == b.trial_count
        @test a.accepted_step == b.accepted_step
        @test a.status == b.status
        @test reinterpret(UInt64, a.objective_before) ==
              reinterpret(UInt64, b.objective_before)
        @test reinterpret(UInt64, a.objective_after) ==
              reinterpret(UInt64, b.objective_after)
        @test stage_c_signed_bits_equal(
            b.state_before, a.state_before, edge_signs)
        @test stage_c_signed_bits_equal(
            b.state_after, a.state_after, edge_signs)
        @test stage_c_signed_bits_equal(
            b.partial_derivatives, a.partial_derivatives, edge_signs)
        @test stage_c_signed_bits_equal(
            b.direction, a.direction, edge_signs)
    end
end

@testset "complete trace integrity, replay, and no syndrome early stop" begin
    case = stage_c_synthetic_case()
    candidate = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    candidate_replay = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    candidate_summary = StageCIntegrity.validate_complete_decoder_trace(
        case.graph, case.llr, case.coefficients, candidate)
    @test stage_c_traces_equal(candidate, candidate_replay)
    @test candidate_summary.schema_version == StageCIntegrity.SCHEMA_VERSION
    @test candidate_summary.attempted_updates == 30
    @test candidate_summary.accepted_updates == 30
    @test candidate_summary.every_stored_objective_recomputed
    @test candidate_summary.every_stored_partial_derivative_recomputed
    @test candidate_summary.every_metric_action_recomputed
    @test candidate_summary.every_projection_recomputed
    @test candidate_summary.every_readout_and_syndrome_recomputed
    @test candidate_summary.update_trial_state_correspondence_verified
    bypassed = StageCMetric.MetricCoefficients(
        -0.5, (0.1, 0.0, 0.0, 0.0))
    @test_throws ArgumentError StageCIntegrity.validate_complete_decoder_trace(
        case.graph, case.llr, bypassed, candidate)

    control = StageCSource.run_lower_endpoint_decoder(
        case.graph, case.llr; capture_vectors=true)
    control_replay = StageCSource.run_lower_endpoint_decoder(
        case.graph, case.llr; capture_vectors=true)
    zero = StageCMetric.MetricCoefficients(
        zeros(Float64, StageCMetric.FAMILY_COUNT + 1))
    control_summary = StageCIntegrity.validate_complete_decoder_trace(
        case.graph, case.llr, zero, control)
    @test stage_c_traces_equal(control, control_replay)
    @test control_summary.attempted_updates == control.attempted_updates
    @test control_summary.accepted_updates == control.accepted_updates
    @test !isequal(candidate.iteration_rows[1].direction,
                   control.iteration_rows[1].direction)
    @test !isequal(candidate.terminal_state, control.terminal_state)

    stalled_case = stage_c_six_variable_case(
        [0.04, 0.17, 0.21, 0.16, 0.04, -0.07])
    stalled = StageCSource.run_candidate_decoder(
        stalled_case.graph, stalled_case.llr, stalled_case.coefficients;
        capture_vectors=true)
    stalled_replay = StageCSource.run_candidate_decoder(
        stalled_case.graph, stalled_case.llr, stalled_case.coefficients;
        capture_vectors=true)
    stalled_summary = StageCIntegrity.validate_complete_decoder_trace(
        stalled_case.graph, stalled_case.llr,
        stalled_case.coefficients, stalled)
    @test stage_c_traces_equal(stalled, stalled_replay)
    @test stalled.status == "line_search_stalled"
    @test stalled.attempted_updates == 28
    @test stalled.accepted_updates == 27
    @test stalled.iteration_rows[27].trial_count == 2
    @test stalled.iteration_rows[27].accepted_step == 0.5
    @test !stalled.trial_rows[27].accepted
    @test stalled.trial_rows[28].accepted
    @test stalled.iteration_rows[28].trial_count == 13
    @test stalled_summary.trial_record_count == 41

    transition_case = stage_c_six_variable_case(
        [0.02, 0.026, 0.021, 0.007, -0.01, -0.023])
    transition = StageCSource.run_candidate_decoder(
        transition_case.graph, transition_case.llr,
        transition_case.coefficients; capture_vectors=true)
    transition_summary = StageCIntegrity.validate_complete_decoder_trace(
        transition_case.graph, transition_case.llr,
        transition_case.coefficients, transition)
    @test transition.initial_diagnostics.syndrome_weight == 2
    @test transition.first_parity_valid_update == 16
    @test transition.state_rows[17].syndrome_weight == 0
    @test transition.attempted_updates == 30
    @test transition.accepted_updates == 30
    @test length(transition.state_rows) == 31
    @test transition_summary.first_parity_valid_update == 16
end

@testset "complete trace integrity fails closed on mutated records" begin
    case = stage_c_synthetic_case()
    trace = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=true)
    validate(value) = StageCIntegrity.validate_complete_decoder_trace(
        case.graph, case.llr, case.coefficients, value)

    changed_initial = copy(trace.initial_state)
    changed_initial[1] = nextfloat(changed_initial[1])
    changed_terminal = copy(trace.terminal_state)
    changed_terminal[1] = prevfloat(changed_terminal[1])
    initial_diagnostics = stage_c_row_with(
        trace.initial_diagnostics, :syndrome_weight,
        trace.initial_diagnostics.syndrome_weight + 1)
    terminal_diagnostics = stage_c_row_with(
        trace.terminal_diagnostics, :zero_readout_ties,
        trace.terminal_diagnostics.zero_readout_ties + 1)

    state = trace.state_rows[1]
    changed_state = copy(state.state)
    changed_state[1] = nextfloat(changed_state[1])
    changed_derivative = copy(state.partial_derivatives)
    changed_derivative[1] = nextfloat(changed_derivative[1])
    changed_bits = copy(state.hard_bits)
    changed_bits[1] = !changed_bits[1]

    trial = trace.trial_rows[1]
    changed_raw = copy(trial.raw_state)
    changed_raw[1] = nextfloat(changed_raw[1])
    changed_projected = copy(trial.projected_state)
    changed_projected[1] = prevfloat(changed_projected[1])

    iteration = trace.iteration_rows[1]
    changed_direction = copy(iteration.direction)
    changed_direction[1] = nextfloat(changed_direction[1])
    changed_condition = stage_c_row_with(
        iteration.condition, :relative_condition_bound,
        nextfloat(iteration.condition.relative_condition_bound))
    extra_state_rows = copy(trace.state_rows)
    extra_state_rows[1] = merge(
        extra_state_rows[1],
        (; transmitted_bits=BitVector([false, false, false])))

    broken_traces = Any[
        stage_c_trace_with(trace, :schema_version, "wrong-schema"),
        stage_c_trace_with(trace, :capture_vectors, false),
        stage_c_trace_with(trace, :initial_state, changed_initial),
        stage_c_trace_with(trace, :terminal_state, changed_terminal),
        stage_c_trace_with(trace, :initial_diagnostics, initial_diagnostics),
        stage_c_trace_with(trace, :terminal_diagnostics, terminal_diagnostics),
        stage_c_trace_row_with(trace, :state_rows, 1, :update, 1),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :state, changed_state),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :state_sha256, repeat("0", 64)),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :objective_value,
            nextfloat(state.objective_value)),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :partial_derivatives,
            changed_derivative),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :partial_derivative_norm,
            nextfloat(state.partial_derivative_norm)),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :hard_bits, changed_bits),
        stage_c_trace_row_with(
            trace, :state_rows, 1, :syndrome_weight,
            state.syndrome_weight + 1),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :trial_ordinal, 2),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :raw_state, changed_raw),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :projected_state, changed_projected),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :current_state_sha256, repeat("f", 64)),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :trial_objective,
            nextfloat(trial.trial_objective)),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :armijo_rhs,
            nextfloat(trial.armijo_rhs)),
        stage_c_trace_row_with(trace, :trial_rows, 1, :accepted, false),
        stage_c_trace_row_with(
            trace, :trial_rows, 1, :rejection_reason,
            "not_strict_descent"),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :direction, changed_direction),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :condition, changed_condition),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :objective_before,
            nextfloat(iteration.objective_before)),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :objective_after,
            nextfloat(iteration.objective_after)),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :state_after_sha256,
            repeat("a", 64)),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :trial_count, 2),
        stage_c_trace_with(trace, :state_rows, extra_state_rows),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :accepted_step, true),
        stage_c_trace_row_with(
            trace, :iteration_rows, 1, :status, :accepted_step),
        stage_c_trace_with(
            trace, :first_parity_valid_update, nothing),
        stage_c_trace_with(
            trace, :accepted_updates, trace.accepted_updates - 1),
        stage_c_trace_with(
            trace, :attempted_updates, trace.attempted_updates - 1),
        stage_c_trace_with(trace, :status, "unregistered-status"),
    ]
    @test length(broken_traces) == 35
    for broken in broken_traces
        @test_throws ErrorException validate(broken)
    end
end

@testset "complete trace validator capability boundary" begin
    integrity_path = joinpath(
        @__DIR__, "..", "stage_c_trace_integrity.jl")
    source = lowercase(read(integrity_path, String))
    @test occursin("validate_complete_decoder_trace", source)
    @test occursin("evaluate_objective", source)
    @test occursin("generic_metric_action", source)
    @test occursin("readout_diagnostics", source)
    @test !occursin("run_candidate_decoder", source)
    @test !occursin("run_lower_endpoint_decoder", source)
    @test !occursin("teacher_direction", source)
    @test !occursin("reference_direction", source)
    @test !occursin("exact_recurrence", source)
    @test !occursin("sum_product", source)
    @test !occursin("transmitted_bits", source)
    @test !occursin("frame_id", source)
    @test !occursin("snr_label", source)
    for forbidden_call in (
            "include(", "open(", "write(", "rand(", "randn(",
            "download(", "serialize(", "deserialize(")
        @test !occursin(forbidden_call, source)
    end
    @test all(name -> !occursin("run", String(name)),
              names(StageCIntegrity))
end

@testset "inference boundary, fail-closed inputs, and compact trace" begin
    case = stage_c_synthetic_case()
    source_path = joinpath(@__DIR__, "..", "stage_c_decoder_source.jl")
    source = lowercase(read(source_path, String))
    @test occursin("generic_metric_action", source)
    @test occursin("evaluate_objective", source)
    @test occursin("clamp.(raw, -1.0, 1.0)", source)
    @test occursin("descent_product < 0.0", source)
    @test !occursin("teacher_direction", source)
    @test !occursin("exact_recurrence", source)
    @test !occursin("sum_product", source)
    @test !occursin("transmitted_bits", source)
    @test !occursin("frame_id", source)
    @test !occursin("snr_label", source)
    @test !occursin("recovery_score", source)
    for forbidden_call in (
            "open(", "write(", "rand(", "randn(", "download(",
            "serialize(", "deserialize(")
        @test !occursin(forbidden_call, source)
    end

    calls = Ref(0)
    throwing_oracle = (args...; kwargs...) -> begin
        calls[] += 1
        error("forbidden oracle called")
    end
    @test throwing_oracle !== nothing
    trace = StageCSource.run_candidate_decoder(
        case.graph, case.llr, case.coefficients; capture_vectors=false)
    @test calls[] == 0
    @test isempty(trace.state_rows[1].state)
    @test isempty(trace.state_rows[1].partial_derivatives)
    @test isempty(trace.state_rows[1].readout)
    @test isempty(trace.iteration_rows[1].state_before)
    @test isempty(trace.iteration_rows[1].state_after)
    @test isempty(trace.iteration_rows[1].partial_derivatives)
    @test isempty(trace.iteration_rows[1].direction)
    @test isempty(trace.trial_rows[1].raw_state)
    @test isempty(trace.trial_rows[1].projected_state)
    for forbidden_field in (
            :transmitted_bits, :recovered, :coded_bit_errors,
            :bit_error_rate, :frame_error_rate, :reference_direction)
        @test forbidden_field ∉ fieldnames(StageCSource.DecoderTrace)
    end

    @test_throws DimensionMismatch StageCSource.run_candidate_decoder(
        case.graph, case.llr[1:2], case.coefficients)
    @test_throws DomainError StageCSource.run_candidate_decoder(
        case.graph, [Inf, case.llr[2], case.llr[3]], case.coefficients)
    @test_throws DomainError StageCSource.run_candidate_decoder(
        case.graph, [20.1, case.llr[2], case.llr[3]], case.coefficients)
end
