module RQ2JCMetricDirection

using LinearAlgebra

export DirectionCompositionError, evaluate_jc_metric_direction,
       SCHEMA_VERSION

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/jc-metric-direction-v1"
const RELATIVE_CONDITION_BOUND_MAX = 1.0e4
const FULL_CONDITION_BOUND_MAX = 1.0e4

struct DirectionCompositionError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::DirectionCompositionError) =
    print(io, error.code, ": ", error.detail)

_fail(code::Symbol, detail::AbstractString) =
    throw(DirectionCompositionError(code, String(detail)))

function _require_source(source, names, label::AbstractString)
    source isa Module || _fail(
        :invalid_source, "$(label) source must be a loaded module")
    for name in names
        isdefined(source, name) || _fail(
            :invalid_source, "$(label) source lacks $(name)")
    end
    source
end

@inline _float_bits(value::Float64) = reinterpret(UInt64, value)

function _vectors_bit_equal(left, right)
    length(left) == length(right) || return false
    @inbounds for index in eachindex(left, right)
        _float_bits(Float64(left[index])) ==
            _float_bits(Float64(right[index])) || return false
    end
    true
end

"""
Calculate one candidate direction from a graph, state, LLRs, and coefficients.

This pure composition evaluates `J_C`, constructs its fixed positive diagonal
matrix, and applies the registered state-dependent two-hop matrix. It returns
diagnostics but performs no state update, projection, step search, stopping
test, or word decision.
"""
function evaluate_jc_metric_direction(metric_source,
                                      objective_source,
                                      graph,
                                      pattern,
                                      state,
                                      llr,
                                      caller_coefficients)
    metric_source = _require_source(
        metric_source,
        (:MetricCoefficients, :FAMILY_COUNT, :generic_metric_action,
         :baseline_direction),
        "matrix")
    objective_source = _require_source(
        objective_source,
        (:evaluate_objective, :fixed_metric_diagonal),
        "objective")

    coefficient_type = getfield(metric_source, :MetricCoefficients)
    caller_coefficients isa coefficient_type || _fail(
        :invalid_coefficients,
        "caller coefficients do not use the registered type")
    beta = getproperty(caller_coefficients, :beta)
    any(value -> value != 0.0, beta) || _fail(
        :identity_only_coefficients,
        "candidate requires a nonzero two-hop coefficient")

    objective = try
        getfield(objective_source, :evaluate_objective)(graph, llr, state)
    catch error
        _fail(:objective_evaluation_failure, sprint(showerror, error))
    end
    metric_diagonal = try
        getfield(objective_source, :fixed_metric_diagonal)(graph)
    catch error
        _fail(:metric_construction_failure, sprint(showerror, error))
    end
    partial_derivatives = objective.partial_derivatives

    candidate = try
        getfield(metric_source, :generic_metric_action)(
            graph, pattern, state, objective.clipped_llr,
            partial_derivatives, metric_diagonal, caller_coefficients)
    catch error
        _fail(:candidate_action_failure, sprint(showerror, error))
    end

    family_count = getfield(metric_source, :FAMILY_COUNT)
    zero_coefficients = try
        coefficient_type(zeros(Float64, family_count + 1))
    catch error
        _fail(:zero_coefficient_construction_failure, sprint(showerror, error))
    end
    lower_endpoint = try
        getfield(metric_source, :generic_metric_action)(
            graph, pattern, state, objective.clipped_llr,
            partial_derivatives, metric_diagonal, zero_coefficients)
    catch error
        _fail(:lower_endpoint_action_failure, sprint(showerror, error))
    end
    declared_lower_endpoint = try
        getfield(metric_source, :baseline_direction)(
            partial_derivatives, metric_diagonal)
    catch error
        _fail(:lower_endpoint_reference_failure, sprint(showerror, error))
    end
    _vectors_bit_equal(lower_endpoint.direction, lower_endpoint.baseline) ||
        _fail(:lower_endpoint_bit_mismatch,
              "zero-coefficient direction differs from returned baseline")
    _vectors_bit_equal(lower_endpoint.direction, declared_lower_endpoint) ||
        _fail(:lower_endpoint_bit_mismatch,
              "zero-coefficient direction differs from declared baseline")

    descent_inner_product = dot(
        Float64.(partial_derivatives), Float64.(candidate.direction))
    _float_bits(descent_inner_product) ==
        _float_bits(Float64(candidate.descent_inner_product)) || _fail(
        :descent_mismatch,
        "candidate descent calculation is not reproducible")
    strict_descent_applicable = any(
        value -> value != 0.0, candidate.direction)
    strict_descent_passed =
        !strict_descent_applicable || descent_inner_product < 0.0
    condition = candidate.condition
    relative_condition_passed =
        condition.relative_condition_bound <= RELATIVE_CONDITION_BOUND_MAX
    full_condition_passed =
        condition.full_euclidean_condition_bound <=
        FULL_CONDITION_BOUND_MAX

    (; schema_version=SCHEMA_VERSION,
       objective_schema_version=objective.schema_version,
       objective_value=objective.value,
       objective_terms=objective.terms,
       mean_state=objective.mean_state,
       clipped_llr=objective.clipped_llr,
       partial_derivatives,
       metric_diagonal,
       candidate_direction=candidate.direction,
       lower_endpoint_direction=lower_endpoint.direction,
       exact_zero_lower_endpoint_bit_exact=true,
       candidate_condition=condition,
       candidate_family_normalizations=candidate.family_normalizations,
       candidate_family_row_sum_bounds=candidate.family_row_sum_bounds,
       descent_inner_product,
       strict_descent_applicable,
       strict_descent_passed,
       relative_condition_passed,
       full_condition_passed,
       local_candidate_gate_passed=
           strict_descent_passed && relative_condition_passed &&
           full_condition_passed)
end

end # module
