module RQ2TwoHopStageCTraceIntegrity

using LinearAlgebra

const HOST_MODULE = parentmodule(@__MODULE__)
isdefined(HOST_MODULE, :RQ2TwoHopStageCDecoderSource) || error(
    "load RQ2TwoHopStageCDecoderSource before the trace-integrity module")
const Source = getfield(HOST_MODULE, :RQ2TwoHopStageCDecoderSource)
const Metric = Source.Metric
const Objective = Source.Objective

export validate_complete_decoder_trace, SCHEMA_VERSION

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-c-trace-integrity-v1"
const DIAGNOSTIC_FIELDS = (
    :readout, :hard_bits, :syndrome, :syndrome_weight, :zero_readout_ties)
const STATE_ROW_FIELDS = (
    :update, :state_sha256, :objective_value,
    :partial_derivatives_sha256, :partial_derivative_norm,
    :syndrome_weight, :zero_readout_ties, :state,
    :partial_derivatives, :readout, :hard_bits)
const TRIAL_ROW_FIELDS = (
    :update, :backtrack, :trial_ordinal, :step,
    :current_state_sha256, :raw_state_sha256, :projected_state_sha256,
    :trial_objective, :armijo_rhs, :descent_product, :finite,
    :strict_descent, :sufficient_decrease, :accepted, :rejection_reason,
    :current_state, :raw_state, :projected_state)
const ITERATION_ROW_FIELDS = (
    :update, :accepted, :trial_count, :accepted_step, :objective_before,
    :objective_after, :partial_derivatives_sha256, :direction_sha256,
    :state_before_sha256, :state_after_sha256, :descent_product,
    :armijo_rhs, :syndrome_weight, :zero_readout_ties, :condition,
    :family_normalizations, :family_row_sum_bounds, :status,
    :state_before, :state_after, :partial_derivatives, :direction)

@inline _float_bits(value::Real) = reinterpret(UInt64, Float64(value))

function _field(record, field::Symbol, label::AbstractString)
    hasproperty(record, field) || error("$label omits $field")
    getproperty(record, field)
end

function _require_schema(record, expected, label::AbstractString)
    record isa NamedTuple || error("$label must be a named tuple")
    propertynames(record) == expected || error(
        "$label field schema differs from the decoder source")
    true
end

function _exact_bool(value, label::AbstractString)
    value isa Bool || error("$label must be Boolean")
    value
end

function _exact_int(value, label::AbstractString)
    value isa Int || error("$label must be Int")
    value
end

function _count(value, label::AbstractString)
    observed = _exact_int(value, label)
    observed >= 0 || error("$label must be nonnegative")
    observed
end

function _finite_float(value, label::AbstractString)
    value isa Float64 || error("$label must be Float64")
    observed = value
    isfinite(observed) || error("$label must be finite")
    observed
end

function _vector(record, field::Symbol, dimension::Int,
                 label::AbstractString; bounded::Bool=false)
    raw = _field(record, field, label)
    raw isa Vector{Float64} || error(
        "$label.$field must be Vector{Float64}")
    length(raw) == dimension || error(
        "$label.$field has dimension $(length(raw)); expected $dimension")
    values = raw
    all(isfinite, values) || error("$label.$field contains a nonfinite value")
    if bounded
        all(value -> -1.0 <= value <= 1.0, values) || error(
            "$label.$field leaves [-1,1]")
    end
    values
end

function _bits(record, field::Symbol, dimension::Int, label::AbstractString)
    raw = _field(record, field, label)
    raw isa BitVector || error("$label.$field must be BitVector")
    length(raw) == dimension || error(
        "$label.$field has dimension $(length(raw)); expected $dimension")
    raw
end

function _same_vector(left, right)
    length(left) == length(right) || return false
    all(index -> _float_bits(left[index]) == _float_bits(right[index]),
        eachindex(left, right))
end

function _require_same_vector(observed, expected, label::AbstractString)
    _same_vector(observed, expected) || error("$label differs bit-exactly")
    true
end

function _require_same_float(observed, expected, label::AbstractString)
    value = _finite_float(observed, label)
    _float_bits(value) == _float_bits(expected) || error(
        "$label differs bit-exactly")
    value
end

function _require_hash(record, field::Symbol, values, label::AbstractString)
    observed = _field(record, field, label)
    observed isa String || error("$label.$field must be String")
    occursin(r"^[0-9a-f]{64}$", observed) || error(
        "$label.$field is not a lowercase SHA-256 digest")
    observed == Source.vector_sha256(values) || error(
        "$label.$field does not match its vector")
    observed
end


function _exact_string(value, label::AbstractString)
    value isa String || error("$label must be String")
    value
end

function _require_same_record(observed, expected, label::AbstractString)
    isequal(observed, expected) || error("$label differs from recomputation")
    true
end

function _validated_llr(graph::Metric.EdgeGraph, clipped_llr)
    clipped_llr isa AbstractVector || error("clipped_llr must be a vector")
    length(clipped_llr) == graph.n || error(
        "clipped_llr dimension differs from the graph")
    llr = try
        Float64.(clipped_llr)
    catch
        error("clipped_llr must be representable as Float64")
    end
    all(isfinite, llr) || error("clipped_llr contains a nonfinite value")
    all(value -> abs(value) <= 20.0, llr) || error(
        "clipped_llr leaves [-20,20]")
    llr
end

function _validate_diagnostics(record, expected, bit_dimension::Int,
                               label::AbstractString)
    _require_schema(record, DIAGNOSTIC_FIELDS, label)
    readout = _vector(record, :readout, bit_dimension, label)
    hard_bits = _bits(record, :hard_bits, bit_dimension, label)
    syndrome = _bits(record, :syndrome, length(expected.syndrome), label)
    _require_same_vector(readout, expected.readout, "$label.readout")
    hard_bits == expected.hard_bits || error(
        "$label.hard_bits differs from recomputation")
    syndrome == expected.syndrome || error(
        "$label.syndrome differs from recomputation")
    _count(_field(record, :syndrome_weight, label),
           "$label.syndrome_weight") == expected.syndrome_weight || error(
        "$label.syndrome_weight differs from recomputation")
    _count(_field(record, :zero_readout_ties, label),
           "$label.zero_readout_ties") == expected.zero_readout_ties || error(
        "$label.zero_readout_ties differs from recomputation")
    true
end

function _validate_state_row(row, state, evaluation, diagnostics,
                             expected_update::Int, state_dimension::Int,
                             bit_dimension::Int, ordinal::Int)
    label = "state_rows[$ordinal]"
    _require_schema(row, STATE_ROW_FIELDS, label)
    _exact_int(_field(row, :update, label), "$label.update") ==
        expected_update || error("$label.update differs from its accepted update")
    observed_state = _vector(
        row, :state, state_dimension, label; bounded=true)
    partial_derivatives = _vector(
        row, :partial_derivatives, state_dimension, label)
    readout = _vector(row, :readout, bit_dimension, label)
    hard_bits = _bits(row, :hard_bits, bit_dimension, label)
    _require_same_vector(diagnostics.readout, evaluation.mean_state,
                         "$label.readout_objective_mean")
    _require_same_vector(observed_state, state, "$label.state")
    _require_same_vector(partial_derivatives,
                         evaluation.partial_derivatives,
                         "$label.partial_derivatives")
    _require_same_vector(readout, diagnostics.readout, "$label.readout")
    hard_bits == diagnostics.hard_bits || error(
        "$label.hard_bits differs from recomputation")
    _require_hash(row, :state_sha256, observed_state, label)
    _require_hash(row, :partial_derivatives_sha256,
                  partial_derivatives, label)
    _require_same_float(_field(row, :objective_value, label),
                        evaluation.value, "$label.objective_value")
    _require_same_float(_field(row, :partial_derivative_norm, label),
                        norm(evaluation.partial_derivatives),
                        "$label.partial_derivative_norm")
    _count(_field(row, :syndrome_weight, label),
           "$label.syndrome_weight") == diagnostics.syndrome_weight || error(
        "$label.syndrome_weight differs from recomputation")
    _count(_field(row, :zero_readout_ties, label),
           "$label.zero_readout_ties") == diagnostics.zero_readout_ties || error(
        "$label.zero_readout_ties differs from recomputation")
    true
end

function _validate_trial_row(
        row, graph::Metric.EdgeGraph, llr, state, evaluation, direction,
        update::Int, backtrack::Int, constants::Source.DecoderConstants,
        state_dimension::Int)
    ordinal = backtrack + 1
    label = "trial_rows(update=$update,ordinal=$ordinal)"
    _require_schema(row, TRIAL_ROW_FIELDS, label)
    _exact_int(_field(row, :update, label), "$label.update") == update ||
        error("$label.update differs from its iteration")
    _exact_int(_field(row, :backtrack, label), "$label.backtrack") ==
        backtrack || error("$label.backtrack order changed")
    _exact_int(_field(row, :trial_ordinal, label), "$label.trial_ordinal") ==
        ordinal || error("$label.trial_ordinal order changed")
    step = _require_same_float(_field(row, :step, label),
                               2.0^(-backtrack), "$label.step")
    current_state = _vector(
        row, :current_state, state_dimension, label; bounded=true)
    raw_state = _vector(row, :raw_state, state_dimension, label)
    projected_state = _vector(
        row, :projected_state, state_dimension, label; bounded=true)
    _require_same_vector(current_state, state, "$label.current_state")
    raw_expected = state .+ step .* direction
    projected_expected = clamp.(raw_expected, -1.0, 1.0)
    _require_same_vector(raw_state, raw_expected, "$label.raw_state")
    _require_same_vector(projected_state, projected_expected,
                         "$label.projected_state")
    _require_hash(row, :current_state_sha256, current_state, label)
    _require_hash(row, :raw_state_sha256, raw_state, label)
    _require_hash(row, :projected_state_sha256, projected_state, label)

    trial_evaluation = Objective.evaluate_objective(
        graph, llr, projected_expected)
    displacement = projected_expected .- state
    descent_product = dot(evaluation.partial_derivatives, displacement)
    armijo_rhs = evaluation.value +
        constants.armijo_constant * descent_product
    finite = isfinite(trial_evaluation.value) &&
        all(isfinite, trial_evaluation.partial_derivatives) &&
        isfinite(descent_product) && isfinite(armijo_rhs)
    strict_descent = descent_product < 0.0
    sufficient_decrease = trial_evaluation.value <= armijo_rhs
    accepted = finite && strict_descent && sufficient_decrease
    reason = accepted ? "accepted" :
        !strict_descent ? "not_strict_descent" : "insufficient_decrease"

    _require_same_float(_field(row, :trial_objective, label),
                        trial_evaluation.value, "$label.trial_objective")
    _require_same_float(_field(row, :armijo_rhs, label),
                        armijo_rhs, "$label.armijo_rhs")
    _require_same_float(_field(row, :descent_product, label),
                        descent_product, "$label.descent_product")
    _exact_bool(_field(row, :finite, label), "$label.finite") == finite ||
        error("$label.finite differs from recomputation")
    _exact_bool(_field(row, :strict_descent, label),
                "$label.strict_descent") == strict_descent || error(
        "$label.strict_descent differs from recomputation")
    _exact_bool(_field(row, :sufficient_decrease, label),
                "$label.sufficient_decrease") == sufficient_decrease || error(
        "$label.sufficient_decrease differs from recomputation")
    _exact_bool(_field(row, :accepted, label), "$label.accepted") == accepted ||
        error("$label.accepted differs from recomputation")
    _exact_string(_field(row, :rejection_reason, label),
                  "$label.rejection_reason") == reason || error(
        "$label.rejection_reason differs from recomputation")
    (; projected_state, trial_evaluation, descent_product, armijo_rhs,
       accepted, step)
end

"""
Validate every retained Stage-C value and every update/trial/state relation.

This pure checker recomputes the registered objective, matrix action,
projection, line-search predicates, readout, hard decisions, syndrome, and
terminal protocol from the pinned source primitives without trusting stored
trace values. It neither advances a trace nor loads case data.
"""
function validate_complete_decoder_trace(
        graph::Metric.EdgeGraph, clipped_llr,
        coefficients::Metric.MetricCoefficients,
        trace::Source.DecoderTrace;
        constants::Source.DecoderConstants=Source.DecoderConstants())
    constants.armijo_constant == 1.0e-4 || error(
        "registered Armijo constant changed")
    constants.maximum_backtracks == 12 || error(
        "registered backtrack cap changed")
    constants.maximum_update_attempts == 30 || error(
        "registered attempted-update cap changed")
    coefficient_report = Metric.coefficient_admissibility(
        coefficients.theta0, coefficients.beta)
    coefficient_report.admissible || throw(ArgumentError(
        "inadmissible metric coefficients: $(coefficient_report.reason)"))
    llr = _validated_llr(graph, clipped_llr)
    state_dimension = Metric.edge_count(graph)
    bit_dimension = graph.n
    trace.schema_version == Source.SCHEMA_VERSION || error(
        "decoder trace schema changed")
    _exact_bool(trace.capture_vectors, "trace.capture_vectors") || error(
        "complete trace validation requires capture_vectors=true")

    initial_state = _vector(
        trace, :initial_state, state_dimension, "trace"; bounded=true)
    expected_initial = Source.initialize_edge_state(graph, llr)
    _require_same_vector(initial_state, expected_initial,
                         "trace.initial_state")
    terminal_state = _vector(
        trace, :terminal_state, state_dimension, "trace"; bounded=true)
    attempted = _count(trace.attempted_updates, "trace.attempted_updates")
    accepted = _count(trace.accepted_updates, "trace.accepted_updates")
    0 <= accepted <= attempted <= constants.maximum_update_attempts || error(
        "trace update counts leave the registered budget")
    length(trace.iteration_rows) == attempted || error(
        "trace omits an attempted update")
    length(trace.state_rows) == accepted + 1 || error(
        "trace omits an accepted state")
    attempted > 0 || error("registered decoder trace has no attempted update")
    isempty(trace.trial_rows) && error("trace omits its line-search trials")

    pattern = Metric.TwoHopPattern(graph)
    metric_diagonal = Objective.fixed_metric_diagonal(graph)
    state = copy(expected_initial)
    evaluation = Objective.evaluate_objective(graph, llr, state)
    diagnostics = Source.readout_diagnostics(graph, state)
    _validate_diagnostics(trace.initial_diagnostics, diagnostics,
                          bit_dimension, "trace.initial_diagnostics")
    _validate_state_row(trace.state_rows[1], state, evaluation, diagnostics,
                        0, state_dimension, bit_dimension, 1)
    parity_valid_updates = diagnostics.syndrome_weight == 0 ? Int[0] : Int[]

    trial_cursor = 1
    state_cursor = 1
    observed_accepted = 0
    for (iteration_ordinal, iteration) in enumerate(trace.iteration_rows)
        label = "iteration_rows[$iteration_ordinal]"
        _require_schema(iteration, ITERATION_ROW_FIELDS, label)
        update = _exact_int(_field(iteration, :update, label),
                            "$label.update")
        update == iteration_ordinal || error("$label.update order changed")
        iteration_accepted = _exact_bool(
            _field(iteration, :accepted, label), "$label.accepted")
        trial_count = _count(_field(iteration, :trial_count, label),
                             "$label.trial_count")
        1 <= trial_count <= constants.maximum_backtracks + 1 || error(
            "$label.trial_count leaves the registered range")
        trial_cursor + trial_count - 1 <= length(trace.trial_rows) || error(
            "$label names missing trial rows")

        state_before = _vector(
            iteration, :state_before, state_dimension, label; bounded=true)
        state_after = _vector(
            iteration, :state_after, state_dimension, label; bounded=true)
        partial_derivatives = _vector(
            iteration, :partial_derivatives, state_dimension, label)
        direction = _vector(iteration, :direction, state_dimension, label)
        _require_same_vector(state_before, state, "$label.state_before")
        _require_same_vector(partial_derivatives,
                             evaluation.partial_derivatives,
                             "$label.partial_derivatives")
        _require_hash(iteration, :state_before_sha256, state_before, label)
        _require_hash(iteration, :state_after_sha256, state_after, label)
        _require_hash(iteration, :partial_derivatives_sha256,
                      partial_derivatives, label)
        _require_hash(iteration, :direction_sha256, direction, label)
        _require_same_float(_field(iteration, :objective_before, label),
                            evaluation.value, "$label.objective_before")

        action = Metric.generic_metric_action(
            graph, pattern, state, llr, evaluation.partial_derivatives,
            metric_diagonal, coefficients)
        action.condition.relative_condition_bound <=
            Source.RELATIVE_CONDITION_BOUND_MAX || error(
                "$label relative condition bound exceeds the registered limit")
        action.condition.full_euclidean_condition_bound <=
            Source.FULL_CONDITION_BOUND_MAX || error(
                "$label full condition bound exceeds the registered limit")
        _require_same_vector(direction, action.direction, "$label.direction")
        _require_same_record(_field(iteration, :condition, label),
                             action.condition, "$label.condition")
        _require_same_record(
            _field(iteration, :family_normalizations, label),
            action.family_normalizations, "$label.family_normalizations")
        _require_same_record(
            _field(iteration, :family_row_sum_bounds, label),
            action.family_row_sum_bounds, "$label.family_row_sum_bounds")

        selected = trace.trial_rows[
            trial_cursor:(trial_cursor + trial_count - 1)]
        validated_trials = NamedTuple[]
        for (trial_ordinal, trial) in enumerate(selected)
            push!(validated_trials, _validate_trial_row(
                trial, graph, llr, state, evaluation, direction, update,
                trial_ordinal - 1, constants, state_dimension))
        end
        accepted_ordinals = findall(item -> item.accepted, validated_trials)
        final_trial = validated_trials[end]
        _require_same_float(_field(iteration, :descent_product, label),
                            final_trial.descent_product,
                            "$label.descent_product")
        _require_same_float(_field(iteration, :armijo_rhs, label),
                            final_trial.armijo_rhs, "$label.armijo_rhs")

        if iteration_accepted
            accepted_ordinals == [trial_count] || error(
                "$label must accept only its final stored trial")
            _require_same_float(_field(iteration, :accepted_step, label),
                                final_trial.step, "$label.accepted_step")
            _exact_string(_field(iteration, :status, label),
                          "$label.status") == "accepted_step" ||
                error("$label.status differs for an accepted update")
            next_state = final_trial.projected_state
            next_evaluation = final_trial.trial_evaluation
            next_diagnostics = Source.readout_diagnostics(graph, next_state)
            _require_same_vector(state_after, next_state,
                                 "$label.state_after")
            _require_same_float(_field(iteration, :objective_after, label),
                                next_evaluation.value,
                                "$label.objective_after")
            _count(_field(iteration, :syndrome_weight, label),
                   "$label.syndrome_weight") ==
                next_diagnostics.syndrome_weight || error(
                    "$label.syndrome_weight differs from recomputation")
            _count(_field(iteration, :zero_readout_ties, label),
                   "$label.zero_readout_ties") ==
                next_diagnostics.zero_readout_ties || error(
                    "$label.zero_readout_ties differs from recomputation")
            observed_accepted += 1
            state_cursor += 1
            state_cursor <= length(trace.state_rows) || error(
                "$label has no accepted state row")
            _validate_state_row(
                trace.state_rows[state_cursor], next_state,
                next_evaluation, next_diagnostics, update, state_dimension,
                bit_dimension, state_cursor)
            next_diagnostics.syndrome_weight == 0 &&
                push!(parity_valid_updates, update)
            state = next_state
            evaluation = next_evaluation
            diagnostics = next_diagnostics
        else
            isempty(accepted_ordinals) || error(
                "$label is rejected but contains an accepted trial")
            trial_count == constants.maximum_backtracks + 1 || error(
                "$label stalled before exhausting the registered trials")
            iteration_ordinal == attempted || error(
                "only the final attempted update may stall")
            _require_same_float(_field(iteration, :accepted_step, label),
                                0.0, "$label.accepted_step")
            _exact_string(_field(iteration, :status, label),
                          "$label.status") ==
                "line_search_stalled" || error(
                    "$label.status differs for a stalled update")
            _require_same_vector(state_after, state, "$label.state_after")
            _require_same_float(_field(iteration, :objective_after, label),
                                evaluation.value, "$label.objective_after")
            _count(_field(iteration, :syndrome_weight, label),
                   "$label.syndrome_weight") == diagnostics.syndrome_weight ||
                error("$label.syndrome_weight differs from recomputation")
            _count(_field(iteration, :zero_readout_ties, label),
                   "$label.zero_readout_ties") ==
                diagnostics.zero_readout_ties || error(
                    "$label.zero_readout_ties differs from recomputation")
        end
        trial_cursor += trial_count
    end

    trial_cursor == length(trace.trial_rows) + 1 || error(
        "trace contains unassigned trial rows")
    state_cursor == length(trace.state_rows) || error(
        "trace contains unassigned state rows")
    observed_accepted == accepted || error(
        "trace.accepted_updates differs from recomputation")
    _require_same_vector(terminal_state, state, "trace.terminal_state")
    terminal_diagnostics = Source.readout_diagnostics(graph, state)
    _validate_diagnostics(trace.terminal_diagnostics,
                          terminal_diagnostics, bit_dimension,
                          "trace.terminal_diagnostics")

    expected_first_valid = isempty(parity_valid_updates) ? nothing :
        first(parity_valid_updates)
    isequal(trace.first_parity_valid_update, expected_first_valid) || error(
        "trace.first_parity_valid_update differs from recomputation")
    status = _exact_string(trace.status, "trace.status")
    if status == "update_cap_reached"
        attempted == constants.maximum_update_attempts &&
            accepted == constants.maximum_update_attempts || error(
                "update-cap trace did not complete every registered update")
    elseif status == "line_search_stalled"
        !trace.iteration_rows[end].accepted || error(
            "line-search-stalled trace lacks a final rejected update")
        accepted == attempted - 1 || error(
            "line-search-stalled trace has inconsistent update counts")
    else
        error("trace has an unregistered terminal status")
    end

    (; schema_version=SCHEMA_VERSION,
       decoder_schema_version=trace.schema_version,
       state_dimension, bit_dimension,
       attempted_updates=attempted,
       accepted_updates=accepted,
       state_record_count=length(trace.state_rows),
       trial_record_count=length(trace.trial_rows),
       first_parity_valid_update=expected_first_valid,
       every_stored_objective_recomputed=true,
       every_stored_partial_derivative_recomputed=true,
       every_metric_action_recomputed=true,
       every_projection_recomputed=true,
       every_readout_and_syndrome_recomputed=true,
       update_trial_state_correspondence_verified=true)
end

end # module
