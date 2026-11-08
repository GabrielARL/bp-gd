module RQ2StageBDirectionKernel

using LinearAlgebra

export DirectionKernelError, evaluate_direction_origin

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-b-direction-origin-v2"
const RELATIVE_CONDITION_BOUND_MAX = 1.0e4
const FULL_CONDITION_BOUND_MAX = 1.0e4

struct DirectionKernelError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::DirectionKernelError) =
    print(io, error.code, ": ", error.detail)

_fail(code::Symbol, detail::AbstractString) =
    throw(DirectionKernelError(code, String(detail)))

function _require_metric_source(metric_source)
    metric_source isa Module || _fail(
        :invalid_metric_source, "the metric source must be a loaded module")
    for name in (:MetricCoefficients, :FAMILY_COUNT, :edge_count,
                 :generic_metric_action, :baseline_direction)
        isdefined(metric_source, name) || _fail(
            :invalid_metric_source, "the metric source lacks $(name)")
    end
    getfield(metric_source, :FAMILY_COUNT) == 4 || _fail(
        :invalid_metric_source, "the frozen metric family count is not four")
    metric_source
end

function _finite_vector(value, expected::Int, label::AbstractString)
    value isa AbstractVector || _fail(
        :invalid_vector, "$label must be an abstract vector")
    length(value) == expected || _fail(
        :dimension_mismatch,
        "$label has length $(length(value)); expected $expected")
    converted = try
        Float64.(value)
    catch error
        _fail(:invalid_vector, "$label cannot be converted to Float64: " *
              sprint(showerror, error))
    end
    all(isfinite, converted) || _fail(
        :nonfinite_input, "$label contains a nonfinite value")
    converted
end

@inline _float_bits(value::Float64) = reinterpret(UInt64, value)

function _vectors_bit_equal(left::AbstractVector{Float64},
                            right::AbstractVector{Float64})
    length(left) == length(right) || return false
    @inbounds for index in eachindex(left, right)
        _float_bits(left[index]) == _float_bits(right[index]) || return false
    end
    true
end

function _finite_scalar(value, label::AbstractString)
    converted = Float64(value)
    isfinite(converted) || _fail(
        :nonfinite_diagnostic, "$label is nonfinite")
    converted
end

function _metric_products(direction::Vector{Float64},
                          teacher::Vector{Float64},
                          metric_diagonal::Vector{Float64})
    direction_norm_squared = 0.0
    teacher_norm_squared = 0.0
    cross_inner_product = 0.0
    difference_norm_squared = 0.0
    @inbounds for index in eachindex(direction, teacher, metric_diagonal)
        weight = metric_diagonal[index]
        direction_value = direction[index]
        teacher_value = teacher[index]
        difference = direction_value - teacher_value
        direction_norm_squared += weight * direction_value * direction_value
        teacher_norm_squared += weight * teacher_value * teacher_value
        cross_inner_product += weight * direction_value * teacher_value
        difference_norm_squared += weight * difference * difference
    end
    all(isfinite, (direction_norm_squared, teacher_norm_squared,
                   cross_inner_product, difference_norm_squared)) || _fail(
        :nonfinite_diagnostic, "a weighted direction diagnostic is nonfinite")
    direction_norm_squared >= 0.0 || _fail(
        :invalid_diagnostic, "the direction norm squared is negative")
    teacher_norm_squared >= 0.0 || _fail(
        :invalid_diagnostic, "the teacher norm squared is negative")
    difference_norm_squared >= 0.0 || _fail(
        :invalid_diagnostic, "the difference norm squared is negative")
    (; direction_norm_squared,
       teacher_norm_squared,
       cross_inner_product,
       difference_norm_squared)
end

function _direction_diagnostic(direction::Vector{Float64},
                               teacher::Vector{Float64},
                               metric_diagonal::Vector{Float64},
                               partial_derivatives::Vector{Float64},
                               descent_inner_product)
    products = _metric_products(direction, teacher, metric_diagonal)
    direction_zero = products.direction_norm_squared == 0.0
    teacher_zero = products.teacher_norm_squared == 0.0
    angle_class = if direction_zero && teacher_zero
        :both_zero
    elseif direction_zero
        :candidate_zero_only
    elseif teacher_zero
        :teacher_zero_only
    else
        :defined
    end

    angle_degrees = nothing
    if angle_class == :defined
        denominator = sqrt(products.direction_norm_squared) *
                      sqrt(products.teacher_norm_squared)
        isfinite(denominator) && denominator > 0.0 || _fail(
            :nonfinite_diagnostic, "the angle denominator is invalid")
        cosine = clamp(products.cross_inner_product / denominator, -1.0, 1.0)
        angle_degrees = _finite_scalar(acosd(cosine), "direction angle")
    end

    relative_direction_error = if angle_class == :candidate_zero_only
        1.0
    elseif angle_class == :defined
        _finite_scalar(
            sqrt(products.difference_norm_squared /
                 products.teacher_norm_squared),
            "relative direction error")
    else
        nothing
    end

    descent = _finite_scalar(
        descent_inner_product, "descent inner product")
    independently_recomputed_descent = _finite_scalar(
        dot(partial_derivatives, direction),
        "recomputed descent inner product")
    _float_bits(descent) == _float_bits(independently_recomputed_descent) ||
        _fail(:descent_mismatch,
              "the production and recomputed descent values differ")
    strict_descent_applicable = !direction_zero
    strict_descent_passed = !strict_descent_applicable || descent < 0.0

    (; angle_class,
       angle_degrees,
       relative_direction_error,
       direction_norm_squared=products.direction_norm_squared,
       teacher_norm_squared=products.teacher_norm_squared,
       cross_inner_product=products.cross_inner_product,
       difference_norm_squared=products.difference_norm_squared,
       descent_inner_product=descent,
       strict_descent_applicable,
       strict_descent_passed)
end

function _condition_record(condition)
    relative = _finite_scalar(
        condition.relative_condition_bound, "relative condition bound")
    full = _finite_scalar(
        condition.full_euclidean_condition_bound,
        "full Euclidean condition bound")
    metric = _finite_scalar(condition.metric_condition, "metric condition")
    lambda_min = _finite_scalar(
        condition.guaranteed_lambda_min_A, "guaranteed minimum eigenvalue")
    lambda_max = _finite_scalar(
        condition.guaranteed_lambda_max_A, "guaranteed maximum eigenvalue")
    lambda_min > 0.0 || _fail(
        :invalid_condition, "the guaranteed minimum eigenvalue is not positive")
    relative_condition_passed = relative <= RELATIVE_CONDITION_BOUND_MAX
    full_condition_passed = full <= FULL_CONDITION_BOUND_MAX
    (; guaranteed_lambda_min_A=lambda_min,
       guaranteed_lambda_max_A=lambda_max,
       relative_condition_bound=relative,
       metric_condition=metric,
       full_euclidean_condition_bound=full,
       relative_condition_passed,
       full_condition_passed,
       condition_passed=relative_condition_passed && full_condition_passed)
end

"""
Evaluate one already-materialized Stage-B origin without advancing any state.

The caller supplies the frozen metric module and every scientific quantity.
The function applies the module's generic metric action once with the supplied
sealed coefficients and once with exact-zero coefficients. The latter call is
required to reproduce the declared lower endpoint bit for bit.
"""
function evaluate_direction_origin(metric_source,
                                   graph,
                                   pattern,
                                   state,
                                   llr,
                                   partial_derivatives,
                                   metric_diagonal,
                                   sealed_coefficients,
                                   teacher_direction)
    metric_source = _require_metric_source(metric_source)
    coefficient_type = getfield(metric_source, :MetricCoefficients)
    sealed_coefficients isa coefficient_type || _fail(
        :invalid_coefficients,
        "sealed coefficients do not use the frozen MetricCoefficients type")
    beta = getproperty(sealed_coefficients, :beta)
    any(value -> value != 0.0, beta) || _fail(
        :identity_only_coefficients,
        "the Stage-B candidate must retain a nonzero two-hop coefficient")

    edge_count = try
        getfield(metric_source, :edge_count)(graph)
    catch error
        _fail(:invalid_graph, sprint(showerror, error))
    end
    edge_count > 0 || _fail(:invalid_graph, "the graph contains no edge")
    hasproperty(graph, :n) || _fail(
        :invalid_graph, "the graph does not expose its variable count")
    variable_count = Int(getproperty(graph, :n))

    state64 = _finite_vector(state, edge_count, "edge state")
    all(value -> -1.0 <= value <= 1.0, state64) || _fail(
        :state_out_of_range, "the edge state must lie in [-1,1]")
    llr64 = _finite_vector(llr, variable_count, "channel LLR vector")
    derivatives64 = _finite_vector(
        partial_derivatives, edge_count, "objective partial derivatives")
    metric64 = _finite_vector(
        metric_diagonal, edge_count, "positive metric diagonal")
    all(value -> value > 0.0, metric64) || _fail(
        :invalid_metric, "every metric diagonal entry must be positive")
    teacher64 = _finite_vector(
        teacher_direction, edge_count, "teacher direction")

    generic_action = getfield(metric_source, :generic_metric_action)
    candidate_action = try
        generic_action(graph, pattern, state64, llr64, derivatives64,
                       metric64, sealed_coefficients)
    catch error
        _fail(:metric_action_failure, sprint(showerror, error))
    end

    family_count = getfield(metric_source, :FAMILY_COUNT)
    zero_coefficients = try
        coefficient_type(zeros(Float64, family_count + 1))
    catch error
        _fail(:zero_coefficient_construction_failure, sprint(showerror, error))
    end
    lower_action = try
        generic_action(graph, pattern, state64, llr64, derivatives64,
                       metric64, zero_coefficients)
    catch error
        _fail(:lower_endpoint_action_failure, sprint(showerror, error))
    end

    candidate_direction = _finite_vector(
        candidate_action.direction, edge_count, "candidate direction")
    lower_direction = _finite_vector(
        lower_action.direction, edge_count, "lower-endpoint direction")
    returned_baseline = _finite_vector(
        lower_action.baseline, edge_count, "returned lower-endpoint baseline")
    declared_baseline = try
        getfield(metric_source, :baseline_direction)(derivatives64, metric64)
    catch error
        _fail(:lower_endpoint_reference_failure, sprint(showerror, error))
    end
    declared_baseline = _finite_vector(
        declared_baseline, edge_count, "declared lower-endpoint baseline")
    _vectors_bit_equal(lower_direction, returned_baseline) || _fail(
        :lower_endpoint_bit_mismatch,
        "the exact-zero generic output differs from its returned baseline")
    _vectors_bit_equal(lower_direction, declared_baseline) || _fail(
        :lower_endpoint_bit_mismatch,
        "the exact-zero generic output differs from the declared baseline")

    candidate_diagnostic = _direction_diagnostic(
        candidate_direction, teacher64, metric64, derivatives64,
        candidate_action.descent_inner_product)
    lower_diagnostic = _direction_diagnostic(
        lower_direction, teacher64, metric64, derivatives64,
        lower_action.descent_inner_product)
    candidate_condition = _condition_record(candidate_action.condition)
    lower_condition = _condition_record(lower_action.condition)
    paired_angle_improvement_degrees =
        candidate_diagnostic.angle_class == :defined &&
        lower_diagnostic.angle_class == :defined ?
        _finite_scalar(
            lower_diagnostic.angle_degrees -
            candidate_diagnostic.angle_degrees,
            "paired angle improvement") : nothing

    (; schema_version=SCHEMA_VERSION,
       candidate_direction,
       lower_endpoint_direction=lower_direction,
       lower_endpoint_returned_baseline=returned_baseline,
       lower_endpoint_declared_baseline=declared_baseline,
       teacher_direction=teacher64,
       candidate=candidate_diagnostic,
       lower_endpoint=lower_diagnostic,
       paired_angle_improvement_degrees,
       candidate_condition,
       lower_endpoint_condition=lower_condition,
       exact_zero_lower_endpoint_bit_exact=true,
       candidate_family_normalizations=candidate_action.family_normalizations,
       candidate_family_row_sum_bounds=candidate_action.family_row_sum_bounds,
       local_candidate_gate_passed=
           candidate_diagnostic.strict_descent_passed &&
           candidate_condition.condition_passed)
end

end # module
