module RQ2StageBTargetSpecificGates

export TargetSpecificGateError, evaluate_target_specific_origin,
       reduce_target_specific_level, SCHEMA_VERSION, CONDITION_BOUND_MAX

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-b-target-specific-gates-v1"
const CONDITION_BOUND_MAX = 1.0e4
const _HEX64 = r"^[0-9a-f]{64}$"

struct TargetSpecificGateError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::TargetSpecificGateError) =
    print(io, error.code, ": ", error.detail)

_fail(code::Symbol, detail::AbstractString) =
    throw(TargetSpecificGateError(code, String(detail)))

function _field(record, name::Symbol)
    if hasproperty(record, name)
        return getproperty(record, name)
    elseif record isa AbstractDict
        haskey(record, name) && return record[name]
        text_name = String(name)
        haskey(record, text_name) && return record[text_name]
    end
    _fail(:missing_field, "record lacks required field $(name)")
end

function _exact_bool(value, name::Symbol)
    value isa Bool || _fail(:invalid_boolean, "$(name) must be Bool")
    value
end

function _finite_float(value, name::Symbol)
    converted = try
        Float64(value)
    catch error
        _fail(:invalid_diagnostic, "$(name) cannot be represented as Float64: " *
              sprint(showerror, error))
    end
    isfinite(converted) || _fail(
        :nonfinite_diagnostic, "$(name) is nonfinite")
    converted
end

function _nonempty_string(value, name::Symbol)
    value isa AbstractString || _fail(
        :invalid_string, "$(name) must be a string")
    converted = String(value)
    isempty(converted) && _fail(:invalid_string, "$(name) is empty")
    converted
end

function _hash(value, name::Symbol)
    converted = _nonempty_string(value, name)
    occursin(_HEX64, converted) || _fail(
        :invalid_hash, "$(name) must be exactly 64 lowercase hexadecimal digits")
    converted
end

@inline _float_bits(value::Float64) = reinterpret(UInt64, value)
@inline _bit_equal(left::Float64, right::Float64) =
    _float_bits(left) == _float_bits(right)

"""
Validate the new target-specific gates for one already-materialized record.

The opaque `record_id` is preserved only for caller correlation. This adapter
does not interpret or reconstruct the generic pairing, level, trajectory, or
replay identity owned by the retained Stage-B machinery.
"""
function evaluate_target_specific_origin(record)
    record_id = _nonempty_string(_field(record, :record_id), :record_id)

    lambda_min = _finite_float(
        _field(record, :candidate_guaranteed_lambda_min_A),
        :candidate_guaranteed_lambda_min_A)
    lambda_max = _finite_float(
        _field(record, :candidate_guaranteed_lambda_max_A),
        :candidate_guaranteed_lambda_max_A)
    relative = _finite_float(
        _field(record, :candidate_relative_condition_bound),
        :candidate_relative_condition_bound)
    metric = _finite_float(
        _field(record, :candidate_metric_condition),
        :candidate_metric_condition)
    full = _finite_float(
        _field(record, :candidate_full_euclidean_condition_bound),
        :candidate_full_euclidean_condition_bound)

    lambda_min > 0.0 || _fail(
        :invalid_condition_diagnostic,
        "candidate guaranteed minimum eigenvalue must be positive")
    lambda_max >= lambda_min || _fail(
        :invalid_condition_diagnostic,
        "candidate guaranteed maximum eigenvalue is below the minimum")
    relative >= 1.0 || _fail(
        :invalid_condition_diagnostic,
        "candidate relative condition bound is below one")
    metric >= 1.0 || _fail(
        :invalid_condition_diagnostic,
        "candidate metric condition is below one")
    full >= 1.0 || _fail(
        :invalid_condition_diagnostic,
        "candidate full condition bound is below one")
    _bit_equal(relative, lambda_max / lambda_min) || _fail(
        :condition_diagnostic_mismatch,
        "relative condition bound differs from lambda_max/lambda_min")
    _bit_equal(full, relative * metric) || _fail(
        :condition_diagnostic_mismatch,
        "full condition bound differs from relative times metric condition")

    relative_passed = relative <= CONDITION_BOUND_MAX
    full_passed = full <= CONDITION_BOUND_MAX
    condition_passed = relative_passed && full_passed
    _exact_bool(
        _field(record, :candidate_relative_condition_passed),
        :candidate_relative_condition_passed) == relative_passed || _fail(
        :condition_flag_mismatch,
        "candidate relative-condition flag differs from its diagnostic")
    _exact_bool(
        _field(record, :candidate_full_condition_passed),
        :candidate_full_condition_passed) == full_passed || _fail(
        :condition_flag_mismatch,
        "candidate full-condition flag differs from its diagnostic")
    _exact_bool(
        _field(record, :candidate_condition_passed),
        :candidate_condition_passed) == condition_passed || _fail(
        :condition_flag_mismatch,
        "candidate joint-condition flag differs from its diagnostics")

    lower_direction_sha256 = _hash(
        _field(record, :lower_endpoint_direction_sha256),
        :lower_endpoint_direction_sha256)
    returned_baseline_sha256 = _hash(
        _field(record, :lower_endpoint_returned_baseline_sha256),
        :lower_endpoint_returned_baseline_sha256)
    declared_baseline_sha256 = _hash(
        _field(record, :lower_endpoint_declared_baseline_sha256),
        :lower_endpoint_declared_baseline_sha256)
    lower_endpoint_bit_identity_passed =
        lower_direction_sha256 == returned_baseline_sha256 ==
        declared_baseline_sha256
    _exact_bool(
        _field(record, :exact_zero_lower_endpoint_bit_exact),
        :exact_zero_lower_endpoint_bit_exact) ==
        lower_endpoint_bit_identity_passed || _fail(
        :lower_endpoint_identity_flag_mismatch,
        "exact-zero lower-endpoint flag differs from the exact hashes")

    finite_values_passed = _exact_bool(
        _field(record, :finite_values_passed), :finite_values_passed)
    finite_values_passed || _fail(
        :finite_flag_mismatch,
        "inspected diagnostics are finite but finite_values_passed is false")

    strict_descent_passed = _exact_bool(
        _field(record, :candidate_strict_descent_passed),
        :candidate_strict_descent_passed)
    local_candidate_gate_passed = strict_descent_passed && condition_passed
    _exact_bool(
        _field(record, :local_candidate_gate_passed),
        :local_candidate_gate_passed) == local_candidate_gate_passed || _fail(
        :local_gate_mismatch,
        "local gate differs from strict descent and joint condition flags")

    (; schema_version=SCHEMA_VERSION,
       record_id,
       finite_values_passed,
       relative_condition_passed=relative_passed,
       full_condition_passed=full_passed,
       condition_passed,
       lower_endpoint_bit_identity_passed,
       local_candidate_gate_passed,
       target_specific_origin_passed=
           finite_values_passed && condition_passed &&
           lower_endpoint_bit_identity_passed && local_candidate_gate_passed)
end

"""
Reduce only the new gates over one already-grouped caller population.

Input order and grouping ownership stay with the caller. The reducer preserves
the opaque identifiers in their supplied order and performs no identity,
sorting, matching, deduplication, or cross-level work.
"""
function reduce_target_specific_level(records)
    evaluated = Tuple(evaluate_target_specific_origin(record)
                      for record in records)
    isempty(evaluated) && _fail(
        :empty_population, "target-specific level population is empty")

    denominator = length(evaluated)
    finite_count = count(result -> result.finite_values_passed, evaluated)
    relative_count = count(
        result -> result.relative_condition_passed, evaluated)
    full_count = count(result -> result.full_condition_passed, evaluated)
    condition_count = count(result -> result.condition_passed, evaluated)
    lower_identity_count = count(
        result -> result.lower_endpoint_bit_identity_passed, evaluated)
    local_count = count(
        result -> result.local_candidate_gate_passed, evaluated)
    origin_count = count(
        result -> result.target_specific_origin_passed, evaluated)

    finite_gate = finite_count == denominator
    relative_gate = relative_count == denominator
    full_gate = full_count == denominator
    condition_gate = condition_count == denominator
    lower_identity_gate = lower_identity_count == denominator
    local_gate = local_count == denominator
    origin_gate = origin_count == denominator

    (; schema_version=SCHEMA_VERSION,
       record_ids=Tuple(result.record_id for result in evaluated),
       target_specific_denominator=denominator,
       finite_value_pass_count=finite_count,
       finite_value_denominator=denominator,
       finite_values_gate_passed=finite_gate,
       relative_condition_pass_count=relative_count,
       relative_condition_denominator=denominator,
       relative_condition_gate_passed=relative_gate,
       full_condition_pass_count=full_count,
       full_condition_denominator=denominator,
       full_condition_gate_passed=full_gate,
       condition_pass_count=condition_count,
       condition_denominator=denominator,
       condition_gate_passed=condition_gate,
       lower_endpoint_bit_identity_pass_count=lower_identity_count,
       lower_endpoint_bit_identity_denominator=denominator,
       lower_endpoint_bit_identity_gate_passed=lower_identity_gate,
       local_candidate_pass_count=local_count,
       local_candidate_denominator=denominator,
       local_candidate_gate_passed=local_gate,
       target_specific_origin_pass_count=origin_count,
       target_specific_origin_denominator=denominator,
       target_specific_origin_gate_passed=origin_gate,
       level_target_specific_gate_passed=
           finite_gate && relative_gate && full_gate && condition_gate &&
           lower_identity_gate && local_gate && origin_gate)
end

end # module
