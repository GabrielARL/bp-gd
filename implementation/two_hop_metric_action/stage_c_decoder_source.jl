module RQ2TwoHopStageCDecoderSource

using LinearAlgebra
using SHA

const METRIC_SOURCE_PATH = joinpath(@__DIR__, "two_hop_positive_metric.jl")
const OBJECTIVE_SOURCE_PATH = joinpath(@__DIR__, "compound_objective_jc.jl")
const METRIC_SOURCE_SHA256 =
    "8f5edffbd6a1e817422da857fc4c78d095e682b42c6cebfdc429437de7e71efb"
const OBJECTIVE_SOURCE_SHA256 =
    "6565b88e3974f7efbfac1dbdd8446ace79752779d5a40bf8e53bb47f7db53bb0"

function _require_source(path::AbstractString, expected::AbstractString,
                         label::AbstractString)
    isfile(path) || error("missing $label source")
    observed = bytes2hex(sha256(read(path)))
    observed == expected || error("$label source hash differs")
    path
end

include(_require_source(
    METRIC_SOURCE_PATH, METRIC_SOURCE_SHA256, "two-hop matrix"))
include(_require_source(
    OBJECTIVE_SOURCE_PATH, OBJECTIVE_SOURCE_SHA256, "compound objective"))

const Metric = RQ2TwoHopPositiveMetric001
const Objective = RQ2CompoundObjectiveJC

export DecoderConstants, DecoderTrace, initialize_edge_state,
       readout_diagnostics,
       run_candidate_decoder, run_lower_endpoint_decoder,
       vector_sha256, SCHEMA_VERSION,
       METRIC_SOURCE_SHA256, OBJECTIVE_SOURCE_SHA256

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-c-decoder-source-preparation-v1"
const RELATIVE_CONDITION_BOUND_MAX = 1.0e4
const FULL_CONDITION_BOUND_MAX = 1.0e4

struct DecoderConstants
    armijo_constant::Float64
    maximum_backtracks::Int
    maximum_update_attempts::Int
end

DecoderConstants() = DecoderConstants(1.0e-4, 12, 30)

function _constants_gate(constants::DecoderConstants)
    constants.armijo_constant == 1.0e-4 || error(
        "registered Armijo constant changed")
    constants.maximum_backtracks == 12 || error(
        "registered backtrack cap changed")
    constants.maximum_update_attempts == 30 || error(
        "registered attempted-update cap changed")
    true
end

function _coefficient_gate(coefficients::Metric.MetricCoefficients)
    report = Metric.coefficient_admissibility(
        coefficients.theta0, coefficients.beta)
    report.admissible || throw(ArgumentError(
        "inadmissible metric coefficients: $(report.reason)"))
    true
end

function vector_sha256(values)
    converted = Float64.(values)
    bytes2hex(sha256(reinterpret(UInt8, converted)))
end

@inline _float_bits(value::Real) = reinterpret(UInt64, Float64(value))

function _vectors_bit_equal(left, right)
    length(left) == length(right) || return false
    all(index -> _float_bits(left[index]) == _float_bits(right[index]),
        eachindex(left, right))
end

function _require_clipped_llr(graph::Metric.EdgeGraph, llr)
    llr isa AbstractVector || throw(ArgumentError(
        "channel LLR input must be an abstract vector"))
    length(llr) == graph.n || throw(DimensionMismatch(
        "channel LLR length differs from graph variable count"))
    converted = Float64.(llr)
    all(isfinite, converted) || throw(DomainError(
        converted, "channel LLR input contains a nonfinite value"))
    all(value -> abs(value) <= 20.0, converted) || throw(DomainError(
        converted, "decoder source requires LLRs already clipped to [-20,20]"))
    converted
end

"""Lift `tanh(L_i/2)` to every directed variable-to-check edge slot."""
function initialize_edge_state(graph::Metric.EdgeGraph, clipped_llr)
    llr = _require_clipped_llr(graph, clipped_llr)
    variable_state = tanh.(llr ./ 2.0)
    [variable_state[graph.edge_variable[edge]]
     for edge in 1:Metric.edge_count(graph)]
end

function _centered_incident_mean(graph::Metric.EdgeGraph, state)
    length(state) == Metric.edge_count(graph) || throw(DimensionMismatch(
        "edge-state length differs from graph edge count"))
    converted = Float64.(state)
    all(isfinite, converted) || throw(DomainError(
        converted, "edge state contains a nonfinite value"))
    mean_state = Vector{Float64}(undef, graph.n)
    @inbounds for variable in 1:graph.n
        incident = graph.variable_edges[variable]
        anchor = converted[first(incident)]
        anchor_bits = reinterpret(UInt64, anchor)
        exact = true
        displacement = 0.0
        for edge in incident
            value = converted[edge]
            exact &= reinterpret(UInt64, value) == anchor_bits
            displacement += value - anchor
        end
        mean_state[variable] = exact ? anchor :
            anchor + displacement / length(incident)
    end
    mean_state
end

"""Apply the registered centered readout and strict-negative decision."""
function readout_diagnostics(graph::Metric.EdgeGraph, state)
    readout = _centered_incident_mean(graph, state)
    hard_bits = BitVector(readout .< 0.0)
    syndrome = BitVector(undef, length(graph.checks))
    @inbounds for (check_index, members) in enumerate(graph.checks)
        parity = false
        for variable in members
            parity = xor(parity, hard_bits[variable])
        end
        syndrome[check_index] = parity
    end
    (; readout, hard_bits, syndrome,
       syndrome_weight=count(identity, syndrome),
       zero_readout_ties=count(iszero, readout))
end

function _finite_evaluation(evaluation)
    isfinite(Float64(evaluation.value)) &&
    all(isfinite, evaluation.partial_derivatives) &&
    all(isfinite, evaluation.scalar_partial_derivatives) &&
    all(isfinite, evaluation.mean_state) &&
    all(isfinite, evaluation.clipped_llr)
end

_capture(enabled::Bool, value) = enabled ? copy(Float64.(value)) : Float64[]

struct DecoderTrace
    schema_version::String
    initial_state::Vector{Float64}
    terminal_state::Vector{Float64}
    initial_diagnostics::Any
    terminal_diagnostics::Any
    iteration_rows::Vector{NamedTuple}
    trial_rows::Vector{NamedTuple}
    state_rows::Vector{NamedTuple}
    status::String
    attempted_updates::Int
    accepted_updates::Int
    first_parity_valid_update::Union{Nothing,Int}
    capture_vectors::Bool
end

function _state_row(update::Int, state, evaluation, diagnostics,
                    capture_vectors::Bool)
    (; update,
       state_sha256=vector_sha256(state),
       objective_value=Float64(evaluation.value),
       partial_derivatives_sha256=
           vector_sha256(evaluation.partial_derivatives),
       partial_derivative_norm=norm(evaluation.partial_derivatives),
       syndrome_weight=diagnostics.syndrome_weight,
       zero_readout_ties=diagnostics.zero_readout_ties,
       state=_capture(capture_vectors, state),
       partial_derivatives=
           _capture(capture_vectors, evaluation.partial_derivatives),
       readout=_capture(capture_vectors, diagnostics.readout),
       hard_bits=copy(diagnostics.hard_bits))
end

function _projected_armijo_step(
        graph::Metric.EdgeGraph, llr, state, current, direction;
        update::Integer,
        constants::DecoderConstants,
        capture_vectors::Bool)
    _constants_gate(constants)
    length(state) == length(current.partial_derivatives) == length(direction) ||
        throw(DimensionMismatch(
            "state, partial-derivative, and direction lengths differ"))
    all(isfinite, state) || throw(DomainError(state, "nonfinite current state"))
    all(value -> -1.0 <= Float64(value) <= 1.0, state) ||
        throw(DomainError(state, "current state lies outside [-1,1]"))
    all(isfinite, current.partial_derivatives) || throw(DomainError(
        current.partial_derivatives, "nonfinite objective partial derivatives"))
    all(isfinite, direction) || throw(DomainError(
        direction, "nonfinite candidate direction"))
    _finite_evaluation(current) || error("nonfinite current objective evaluation")

    current_state = Float64.(state)
    derivative = Float64.(current.partial_derivatives)
    candidate_direction = Float64.(direction)
    rows = NamedTuple[]
    for backtrack in 0:constants.maximum_backtracks
        step = 2.0^(-backtrack)
        raw = current_state .+ step .* candidate_direction
        all(isfinite, raw) || throw(DomainError(
            raw, "nonfinite raw projected-Armijo trial"))
        trial = clamp.(raw, -1.0, 1.0)
        displacement = trial .- current_state
        descent_product = dot(derivative, displacement)
        armijo_rhs = Float64(current.value) +
            constants.armijo_constant * descent_product
        evaluation = Objective.evaluate_objective(graph, llr, trial)
        finite = _finite_evaluation(evaluation) &&
            isfinite(descent_product) && isfinite(armijo_rhs)
        finite || error("nonfinite projected-Armijo trial evaluation")
        strict_descent = descent_product < 0.0
        sufficient_decrease = evaluation.value <= armijo_rhs
        accepted = strict_descent && sufficient_decrease
        rejection_reason = accepted ? "accepted" :
            !strict_descent ? "not_strict_descent" :
            "insufficient_decrease"
        push!(rows, (;
            update=Int(update), backtrack, trial_ordinal=backtrack + 1, step,
            current_state_sha256=vector_sha256(current_state),
            raw_state_sha256=vector_sha256(raw),
            projected_state_sha256=vector_sha256(trial),
            trial_objective=Float64(evaluation.value),
            armijo_rhs, descent_product, finite, strict_descent,
            sufficient_decrease, accepted, rejection_reason,
            current_state=_capture(capture_vectors, current_state),
            raw_state=_capture(capture_vectors, raw),
            projected_state=_capture(capture_vectors, trial)))
        accepted && return (;
            accepted=true, state=trial, evaluation, rows,
            accepted_step=step, trial_count=length(rows))
    end
    (; accepted=false, state=current_state, evaluation=nothing, rows,
       accepted_step=0.0, trial_count=length(rows))
end

function _run_decoder(
        graph::Metric.EdgeGraph, clipped_llr,
        coefficients::Metric.MetricCoefficients;
        constants::DecoderConstants,
        capture_vectors::Bool)
    _constants_gate(constants)
    _coefficient_gate(coefficients)
    llr = _require_clipped_llr(graph, clipped_llr)
    pattern = Metric.TwoHopPattern(graph)
    metric_diagonal = Objective.fixed_metric_diagonal(graph)
    state = initialize_edge_state(graph, llr)
    initial_state = copy(state)
    current = Objective.evaluate_objective(graph, llr, state)
    _finite_evaluation(current) || error("nonfinite initial objective evaluation")
    initial_diagnostics = readout_diagnostics(graph, state)
    first_parity_valid = initial_diagnostics.syndrome_weight == 0 ? 0 : nothing

    state_rows = NamedTuple[_state_row(
        0, state, current, initial_diagnostics, capture_vectors)]
    iteration_rows = NamedTuple[]
    trial_rows = NamedTuple[]
    attempted_updates = 0
    accepted_updates = 0
    status = "update_cap_reached"

    for update in 1:constants.maximum_update_attempts
        attempted_updates = update
        before = copy(state)
        evaluation_before = current
        action = Metric.generic_metric_action(
            graph, pattern, state, llr, current.partial_derivatives,
            metric_diagonal, coefficients)
        direction = copy(Float64.(action.direction))
        condition = action.condition
        condition.relative_condition_bound <=
            RELATIVE_CONDITION_BOUND_MAX || error(
                "relative condition bound exceeds the registered limit")
        condition.full_euclidean_condition_bound <=
            FULL_CONDITION_BOUND_MAX || error(
                "full condition bound exceeds the registered limit")
        _float_bits(dot(current.partial_derivatives, direction)) ==
            _float_bits(action.descent_inner_product) || error(
                "direction descent product is not reproducible")

        step_result = _projected_armijo_step(
            graph, llr, state, current, direction;
            update, constants, capture_vectors)
        append!(trial_rows, step_result.rows)
        if !step_result.accepted
            diagnostics = readout_diagnostics(graph, state)
            last_trial = step_result.rows[end]
            push!(iteration_rows, (;
                update, accepted=false,
                trial_count=step_result.trial_count,
                accepted_step=0.0,
                objective_before=Float64(evaluation_before.value),
                objective_after=Float64(evaluation_before.value),
                partial_derivatives_sha256=
                    vector_sha256(evaluation_before.partial_derivatives),
                direction_sha256=vector_sha256(direction),
                state_before_sha256=vector_sha256(before),
                state_after_sha256=vector_sha256(state),
                descent_product=last_trial.descent_product,
                armijo_rhs=last_trial.armijo_rhs,
                syndrome_weight=diagnostics.syndrome_weight,
                zero_readout_ties=diagnostics.zero_readout_ties,
                condition,
                family_normalizations=action.family_normalizations,
                family_row_sum_bounds=action.family_row_sum_bounds,
                status="line_search_stalled",
                state_before=_capture(capture_vectors, before),
                state_after=_capture(capture_vectors, state),
                partial_derivatives=_capture(
                    capture_vectors, evaluation_before.partial_derivatives),
                direction=_capture(capture_vectors, direction)))
            status = "line_search_stalled"
            break
        end

        accepted_trial = step_result.rows[end]
        state = step_result.state
        current = step_result.evaluation
        _finite_evaluation(current) || error(
            "nonfinite accepted objective evaluation")
        accepted_updates += 1
        diagnostics = readout_diagnostics(graph, state)
        if first_parity_valid === nothing && diagnostics.syndrome_weight == 0
            first_parity_valid = update
        end
        push!(iteration_rows, (;
            update, accepted=true,
            trial_count=step_result.trial_count,
            accepted_step=step_result.accepted_step,
            objective_before=Float64(evaluation_before.value),
            objective_after=Float64(current.value),
            partial_derivatives_sha256=
                vector_sha256(evaluation_before.partial_derivatives),
            direction_sha256=vector_sha256(direction),
            state_before_sha256=vector_sha256(before),
            state_after_sha256=vector_sha256(state),
            descent_product=accepted_trial.descent_product,
            armijo_rhs=accepted_trial.armijo_rhs,
            syndrome_weight=diagnostics.syndrome_weight,
            zero_readout_ties=diagnostics.zero_readout_ties,
            condition,
            family_normalizations=action.family_normalizations,
            family_row_sum_bounds=action.family_row_sum_bounds,
            status="accepted_step",
            state_before=_capture(capture_vectors, before),
            state_after=_capture(capture_vectors, state),
            partial_derivatives=_capture(
                capture_vectors, evaluation_before.partial_derivatives),
            direction=_capture(capture_vectors, direction)))
        push!(state_rows, _state_row(
            update, state, current, diagnostics, capture_vectors))
    end

    terminal_diagnostics = readout_diagnostics(graph, state)
    DecoderTrace(
        SCHEMA_VERSION, initial_state, copy(state), initial_diagnostics,
        terminal_diagnostics, iteration_rows, trial_rows, state_rows,
        status, attempted_updates, accepted_updates, first_parity_valid,
        capture_vectors)
end

"""Run the nonzero two-hop candidate through the registered update path."""
function run_candidate_decoder(
        graph::Metric.EdgeGraph, clipped_llr,
        coefficients::Metric.MetricCoefficients;
        constants::DecoderConstants=DecoderConstants(),
        capture_vectors::Bool=true)
    any(value -> value != 0.0, coefficients.beta) || throw(ArgumentError(
        "candidate source requires a nonzero two-hop coefficient"))
    _run_decoder(
        graph, clipped_llr, coefficients; constants, capture_vectors)
end

"""Run the exact-zero lower endpoint through the same generic matrix action."""
function run_lower_endpoint_decoder(
        graph::Metric.EdgeGraph, clipped_llr;
        constants::DecoderConstants=DecoderConstants(),
        capture_vectors::Bool=true)
    coefficients = Metric.MetricCoefficients(
        zeros(Float64, Metric.FAMILY_COUNT + 1))
    _run_decoder(
        graph, clipped_llr, coefficients; constants, capture_vectors)
end

end # module
