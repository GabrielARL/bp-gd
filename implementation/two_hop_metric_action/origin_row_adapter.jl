module RQ2StageBOriginRowAdapter

export OriginRowAdapterError, prepare_origin_row, project_thresholds,
       reduce_prepared_level, SCHEMA_VERSION, PAIRING_FIELDS

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/stage-b-origin-row-adapter-v1"
const PAIRING_FIELDS = (
    :channel, :frame, :frame_rank, :origin_update,
    :state_sha256, :teacher_direction_sha256,
)
const TARGET_KERNEL_SCHEMA =
    "rq2-two-hop-positive-metric-001/stage-b-direction-origin-v2"
const ANGLE_CLASSES =
    (:defined, :both_zero, :candidate_zero_only, :teacher_zero_only)
const _HEX64 = r"^[0-9a-f]{64}$"

struct OriginRowAdapterError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::OriginRowAdapterError) =
    print(io, error.code, ": ", error.detail)

_fail(code::Symbol, detail::AbstractString) =
    throw(OriginRowAdapterError(code, String(detail)))

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

function _nonempty_string(value, name::Symbol)
    value isa AbstractString || _fail(
        :invalid_string, "$(name) must be a string")
    converted = String(value)
    isempty(converted) && _fail(:invalid_string, "$(name) is empty")
    converted
end

function _canonical_hash(value, name::Symbol)
    converted = _nonempty_string(value, name)
    occursin(_HEX64, converted) || _fail(
        :invalid_hash,
        "$(name) must be exactly 64 lowercase hexadecimal digits")
    converted
end

function _finite_float(value, name::Symbol)
    converted = try
        Float64(value)
    catch error
        _fail(:invalid_number, "$(name) is not representable as Float64: " *
              sprint(showerror, error))
    end
    isfinite(converted) || _fail(:nonfinite_number, "$(name) is nonfinite")
    converted
end

function _exact_integer(value, name::Symbol; minimum::Int)
    value isa Integer || _fail(
        :invalid_integer, "$(name) must be an integer")
    converted = Int(value)
    converted >= minimum || _fail(
        :invalid_integer, "$(name) is below its minimum")
    converted
end

function _exact_bool(value, name::Symbol)
    value isa Bool || _fail(:invalid_boolean, "$(name) must be Bool")
    value
end

function _angle_class(value, name::Symbol)
    converted = value isa Symbol ? value :
        Symbol(_nonempty_string(value, name))
    converted in ANGLE_CLASSES || _fail(
        :invalid_angle_class, "$(name) is not a registered angle class")
    converted
end

function _optional_finite(value, name::Symbol, required::Bool)
    if required
        value === nothing && _fail(
            :missing_diagnostic, "$(name) is required for this angle class")
        return _finite_float(value, name)
    end
    value === nothing ? nothing : _finite_float(value, name)
end

function _diagnostic_view(record, prefix::Symbol)
    angle_class = _angle_class(
        _field(record, :angle_class), Symbol(prefix, :_angle_class))
    angle_degrees = _optional_finite(
        _field(record, :angle_degrees), Symbol(prefix, :_angle_degrees),
        angle_class == :defined)
    relative_direction_error = _optional_finite(
        _field(record, :relative_direction_error),
        Symbol(prefix, :_relative_direction_error),
        angle_class in (:defined, :candidate_zero_only))
    strict_descent_applicable = _exact_bool(
        _field(record, :strict_descent_applicable),
        Symbol(prefix, :_strict_descent_applicable))
    strict_descent_passed = _exact_bool(
        _field(record, :strict_descent_passed),
        Symbol(prefix, :_strict_descent_passed))
    (; angle_class, angle_degrees, relative_direction_error,
       strict_descent_applicable, strict_descent_passed)
end

function _condition_view(record)
    lambda_min = _finite_float(
        _field(record, :guaranteed_lambda_min_A),
        :candidate_guaranteed_lambda_min_A)
    lambda_max = _finite_float(
        _field(record, :guaranteed_lambda_max_A),
        :candidate_guaranteed_lambda_max_A)
    relative = _finite_float(
        _field(record, :relative_condition_bound),
        :candidate_relative_condition_bound)
    metric = _finite_float(
        _field(record, :metric_condition), :candidate_metric_condition)
    full = _finite_float(
        _field(record, :full_euclidean_condition_bound),
        :candidate_full_euclidean_condition_bound)
    relative_passed = _exact_bool(
        _field(record, :relative_condition_passed),
        :candidate_relative_condition_passed)
    full_passed = _exact_bool(
        _field(record, :full_condition_passed),
        :candidate_full_condition_passed)
    condition_passed = _exact_bool(
        _field(record, :condition_passed), :candidate_condition_passed)
    (; lambda_min, lambda_max, relative, metric, full,
       relative_passed, full_passed, condition_passed)
end

function project_thresholds(direction_screen)
    median_max = _finite_float(
        _field(direction_screen, :median_angle_degrees_max),
        :median_angle_degrees_max)
    p90_max = _finite_float(
        _field(direction_screen, :p90_angle_degrees_max),
        :p90_angle_degrees_max)
    coverage_min = _finite_float(
        _field(direction_screen, :aligned_or_evaluable_coverage_min),
        :aligned_or_evaluable_coverage_min)
    one_sided_max = _finite_float(
        _field(direction_screen, :one_sided_zero_fraction_max),
        :one_sided_zero_fraction_max)
    paired_min = _finite_float(
        _field(direction_screen,
               :paired_median_improvement_over_lower_endpoint_degrees_min),
        :paired_median_improvement_over_lower_endpoint_degrees_min)
    relative_max = _finite_float(
        _field(direction_screen, :median_relative_direction_error_max),
        :median_relative_direction_error_max)

    0.0 <= median_max <= 180.0 || _fail(
        :invalid_threshold, "median-angle threshold is outside [0,180]")
    0.0 <= p90_max <= 180.0 || _fail(
        :invalid_threshold, "p90-angle threshold is outside [0,180]")
    0.0 <= coverage_min <= 1.0 || _fail(
        :invalid_threshold, "coverage threshold is outside [0,1]")
    0.0 <= one_sided_max <= 1.0 || _fail(
        :invalid_threshold, "one-sided-zero threshold is outside [0,1]")
    paired_min >= -180.0 || _fail(
        :invalid_threshold, "paired-improvement threshold is below -180")
    relative_max >= 0.0 || _fail(
        :invalid_threshold, "relative-error threshold is negative")

    retained_direction_screen = Dict{String,Any}(
        "median_angle_degrees_max" => median_max,
        "p90_angle_degrees_max" => p90_max,
        "aligned_or_evaluable_coverage_min" => coverage_min,
        "one_sided_zero_fraction_max" => one_sided_max,
        "median_improvement_over_native_J_C_degrees_min" => paired_min,
        "median_relative_direction_error_max" => relative_max,
    )
    (; median_angle_degrees_max=median_max,
       p90_angle_degrees_max=p90_max,
       aligned_or_evaluable_coverage_min=coverage_min,
       one_sided_zero_fraction_max=one_sided_max,
       paired_median_improvement_over_lower_endpoint_degrees_min=paired_min,
       median_relative_direction_error_max=relative_max,
       retained_improvement_field=
           :median_improvement_over_native_J_C_degrees_min,
       retained_direction_screen)
end

function prepare_origin_row(pairing, identity, hashes, kernel_result,
                            direction_screen)
    schema = _nonempty_string(
        _field(kernel_result, :schema_version), :kernel_schema_version)
    schema == TARGET_KERNEL_SCHEMA || _fail(
        :kernel_schema_mismatch, "target kernel schema differs")

    record_id = _nonempty_string(_field(pairing, :record_id), :record_id)
    channel = _nonempty_string(_field(pairing, :channel), :channel)
    snr_db = _finite_float(_field(pairing, :snr_db), :snr_db)
    frame = _exact_integer(_field(pairing, :frame), :frame; minimum=0)
    frame_rank = _exact_integer(
        _field(pairing, :frame_rank), :frame_rank; minimum=1)
    origin_update = _exact_integer(
        _field(pairing, :origin_update), :origin_update; minimum=0)

    input_identity_sha256 = _canonical_hash(
        _field(identity, :input_identity_sha256), :input_identity_sha256)
    state_sha256 = _canonical_hash(
        _field(hashes, :state_sha256), :state_sha256)
    teacher_direction_sha256 = _canonical_hash(
        _field(hashes, :teacher_direction_sha256),
        :teacher_direction_sha256)
    candidate_direction_sha256 = _canonical_hash(
        _field(hashes, :candidate_direction_sha256),
        :candidate_direction_sha256)
    lower_endpoint_direction_sha256 = _canonical_hash(
        _field(hashes, :lower_endpoint_direction_sha256),
        :lower_endpoint_direction_sha256)
    lower_endpoint_returned_baseline_sha256 = _canonical_hash(
        _field(hashes, :lower_endpoint_returned_baseline_sha256),
        :lower_endpoint_returned_baseline_sha256)
    lower_endpoint_declared_baseline_sha256 = _canonical_hash(
        _field(hashes, :lower_endpoint_declared_baseline_sha256),
        :lower_endpoint_declared_baseline_sha256)
    metric_sha256 = _canonical_hash(
        _field(hashes, :metric_sha256), :metric_sha256)
    coefficient_sha256 = _canonical_hash(
        _field(hashes, :coefficient_sha256), :coefficient_sha256)

    candidate = _diagnostic_view(_field(kernel_result, :candidate), :candidate)
    lower_endpoint = _diagnostic_view(
        _field(kernel_result, :lower_endpoint), :lower_endpoint)
    condition = _condition_view(
        _field(kernel_result, :candidate_condition))
    exact_identity = _exact_bool(
        _field(kernel_result, :exact_zero_lower_endpoint_bit_exact),
        :exact_zero_lower_endpoint_bit_exact)
    local_gate = _exact_bool(
        _field(kernel_result, :local_candidate_gate_passed),
        :local_candidate_gate_passed)
    local_gate ==
        (candidate.strict_descent_passed && condition.condition_passed) ||
        _fail(:local_gate_mismatch,
              "target kernel local gate differs from its components")

    threshold_projection = project_thresholds(direction_screen)
    target_row = (;
        schema_version=SCHEMA_VERSION, record_id, channel, snr_db, frame,
        frame_rank, origin_update, input_identity_sha256, state_sha256,
        teacher_direction_sha256, candidate_direction_sha256,
        lower_endpoint_direction_sha256,
        lower_endpoint_returned_baseline_sha256,
        lower_endpoint_declared_baseline_sha256, metric_sha256,
        coefficient_sha256,
        candidate_angle_class=String(candidate.angle_class),
        candidate_angle_degrees=something(candidate.angle_degrees, 0.0),
        candidate_relative_direction_error=
            something(candidate.relative_direction_error, 0.0),
        candidate_direction_nonzero=candidate.strict_descent_applicable,
        candidate_strict_descent_passed=candidate.strict_descent_passed,
        lower_endpoint_angle_class=String(lower_endpoint.angle_class),
        lower_endpoint_angle_degrees=
            something(lower_endpoint.angle_degrees, 0.0),
        lower_endpoint_relative_direction_error=
            something(lower_endpoint.relative_direction_error, 0.0),
        candidate_guaranteed_lambda_min_A=condition.lambda_min,
        candidate_guaranteed_lambda_max_A=condition.lambda_max,
        candidate_relative_condition_bound=condition.relative,
        candidate_metric_condition=condition.metric,
        candidate_full_euclidean_condition_bound=condition.full,
        candidate_relative_condition_passed=condition.relative_passed,
        candidate_full_condition_passed=condition.full_passed,
        candidate_condition_passed=condition.condition_passed,
        exact_zero_lower_endpoint_bit_exact=exact_identity,
        finite_values_passed=true,
        local_candidate_gate_passed=local_gate,
    )

    retained_summary_view = (;
        channel, frame,
        angle_class=String(candidate.angle_class),
        angle_degrees=something(candidate.angle_degrees, 0.0),
        relative_direction_error=
            something(candidate.relative_direction_error, 0.0),
        baseline_angle_class=String(lower_endpoint.angle_class),
        baseline_angle_degrees=
            something(lower_endpoint.angle_degrees, 0.0),
        candidate_nonzero=candidate.strict_descent_applicable,
        strict_descent=candidate.strict_descent_passed,
        finite_values=true,
    )

    target_gate_view = (;
        record_id,
        candidate_guaranteed_lambda_min_A=condition.lambda_min,
        candidate_guaranteed_lambda_max_A=condition.lambda_max,
        candidate_relative_condition_bound=condition.relative,
        candidate_metric_condition=condition.metric,
        candidate_full_euclidean_condition_bound=condition.full,
        candidate_relative_condition_passed=condition.relative_passed,
        candidate_full_condition_passed=condition.full_passed,
        candidate_condition_passed=condition.condition_passed,
        lower_endpoint_direction_sha256,
        lower_endpoint_returned_baseline_sha256,
        lower_endpoint_declared_baseline_sha256,
        exact_zero_lower_endpoint_bit_exact=exact_identity,
        finite_values_passed=true,
        candidate_strict_descent_passed=candidate.strict_descent_passed,
        local_candidate_gate_passed=local_gate,
    )

    (; target_row, retained_summary_view, target_gate_view,
       threshold_projection)
end

function _pairing_key(prepared)
    row = _field(prepared, :target_row)
    (
        _field(row, :channel),
        _field(row, :frame),
        _field(row, :frame_rank),
        _field(row, :origin_update),
        _field(row, :state_sha256),
        _field(row, :teacher_direction_sha256),
    )
end

function _prove_unique_pairing(rows, channel::String)
    seen_keys = Set{Tuple}()
    seen_record_ids = Set{String}()
    for prepared in rows
        row = _field(prepared, :target_row)
        String(_field(row, :channel)) == channel || _fail(
            :level_channel_mismatch,
            "prepared origin belongs to a different channel")
        key = _pairing_key(prepared)
        key in seen_keys && _fail(
            :duplicate_pairing_key,
            "upstream pairing key is not unique")
        push!(seen_keys, key)
        record_id = String(_field(row, :record_id))
        record_id in seen_record_ids && _fail(
            :duplicate_record_id,
            "upstream record identifier is not unique")
        push!(seen_record_ids, record_id)
    end
    (; pairing_keys_unique=true, pairing_key_count=length(seen_keys),
       record_ids_unique=true, record_id_count=length(seen_record_ids))
end

function reduce_prepared_level(channel_value, prepared_rows;
                               summarize_channel,
                               reduce_target_specific_level)
    channel = _nonempty_string(channel_value, :channel)
    rows = collect(prepared_rows)
    isempty(rows) && _fail(
        :empty_population, "prepared level population is empty")

    uniqueness = _prove_unique_pairing(rows, channel)
    projection = _field(first(rows), :threshold_projection)
    for prepared in rows
        isequal(_field(prepared, :threshold_projection), projection) ||
            _fail(:threshold_projection_mismatch,
                  "prepared origins do not share one threshold projection")
    end

    retained_rows = [_field(row, :retained_summary_view) for row in rows]
    target_gate_rows = [_field(row, :target_gate_view) for row in rows]
    retained_config = Dict{String,Any}(
        "direction_screen" =>
            _field(projection, :retained_direction_screen))

    generic_summary = summarize_channel(
        channel, retained_rows, retained_config)
    target_specific_summary = reduce_target_specific_level(target_gate_rows)
    generic_denominator = Int(_field(generic_summary, :state_count))
    target_specific_denominator = Int(_field(
        target_specific_summary, :target_specific_denominator))
    generic_denominator == target_specific_denominator == length(rows) ||
        _fail(:denominator_mismatch,
              "generic and target-specific level denominators differ")

    generic_gate = _exact_bool(
        _field(generic_summary, :direction_screen_passed),
        :direction_screen_passed)
    target_gate = _exact_bool(
        _field(target_specific_summary, :level_target_specific_gate_passed),
        :level_target_specific_gate_passed)
    (; schema_version=SCHEMA_VERSION, channel,
       pairing_keys_unique=uniqueness.pairing_keys_unique,
       pairing_key_count=uniqueness.pairing_key_count,
       record_ids_unique=uniqueness.record_ids_unique,
       record_id_count=uniqueness.record_id_count,
       generic_denominator, target_specific_denominator,
       generic_summary, target_specific_summary,
       threshold_projection=projection,
       generic_direction_screen_passed=generic_gate,
       target_specific_level_passed=target_gate,
       level_combined_gate_passed=generic_gate && target_gate)
end

end # module
