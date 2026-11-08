module RQ2RetainedDirectionPopulationSummary

using Statistics

export summarize_channel, SCHEMA_VERSION,
       RETAINED_CONTRACT_SHA256, RETAINED_SLICE_SHA256

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/retained-direction-population-summary-v1"
const RETAINED_CONTRACT_SHA256 =
    "a96aa44aadf183d48b8db8aa5a9250b0f25552dcd61b37e6aaadd438f9be3f86"
const RETAINED_SLICE_SHA256 =
    "951be06490d6c215e05c0e7ac698ffa5b1cdb806c27207dfcde34d658c283b1f"

function _nearest_rank(values, probability::Real)
    isempty(values) && return nothing
    ordered = sort(Float64.(values))
    ordered[max(1, ceil(Int, Float64(probability) * length(ordered)))]
end

function _finite_statistic(value)
    value !== nothing && isfinite(Float64(value))
end

"""
Reduce already-materialized per-origin direction diagnostics for one channel.

This is the retained Stage-B summary arithmetic extracted from the historical
contract. It performs no pairing, case generation, recurrence calculation,
state update, file I/O, or result writing.
"""
function summarize_channel(channel::AbstractString, rows, config)
    selected = [row for row in rows if String(row.channel) == channel]
    isempty(selected) && error("empty Stage-B state population for $channel")
    defined = [Float64(row.angle_degrees) for row in selected
               if String(row.angle_class) == "defined"]
    baseline_defined = [Float64(row.baseline_angle_degrees) for row in selected
                        if String(row.baseline_angle_class) == "defined"]
    both_zero = count(row -> String(row.angle_class) == "both_zero", selected)
    candidate_zero = count(
        row -> String(row.angle_class) == "candidate_zero_only", selected)
    teacher_zero = count(
        row -> String(row.angle_class) == "teacher_zero_only", selected)
    jointly = [row for row in selected
               if String(row.angle_class) == "defined" &&
                  String(row.baseline_angle_class) == "defined"]
    improvements = [Float64(row.baseline_angle_degrees) -
                    Float64(row.angle_degrees) for row in jointly]
    relative = [String(row.angle_class) == "candidate_zero_only" ? 1.0 :
                Float64(row.relative_direction_error) for row in selected
                if String(row.angle_class) in
                   ("defined", "candidate_zero_only")]
    state_count = length(selected)
    aligned_count = length(defined) + both_zero
    one_sided = candidate_zero + teacher_zero
    coverage = aligned_count / state_count
    one_sided_fraction = one_sided / state_count
    candidate_median = isempty(defined) ? nothing : median(defined)
    candidate_p90 = _nearest_rank(defined, 0.90)
    baseline_median = isempty(baseline_defined) ? nothing :
        median(baseline_defined)
    improvement = isempty(improvements) ? nothing : median(improvements)
    relative_median = isempty(relative) ? nothing : median(relative)
    nonzero_count = count(row -> Bool(row.candidate_nonzero), selected)
    descent_count = count(row -> Bool(row.candidate_nonzero) &&
                           Bool(row.strict_descent), selected)
    finite_values = all(row -> Bool(row.finite_values), selected)
    summary_finite = all(_finite_statistic, (
        candidate_median, candidate_p90, baseline_median, improvement,
        relative_median, coverage, one_sided_fraction))
    screen = config["direction_screen"]
    checks = (;
        median_angle=_finite_statistic(candidate_median) &&
            candidate_median <= Float64(screen["median_angle_degrees_max"]),
        p90_angle=_finite_statistic(candidate_p90) &&
            candidate_p90 <= Float64(screen["p90_angle_degrees_max"]),
        aligned_or_evaluable_coverage=coverage >= Float64(
            screen["aligned_or_evaluable_coverage_min"]),
        one_sided_zero=one_sided_fraction <= Float64(
            screen["one_sided_zero_fraction_max"]),
        median_paired_improvement=_finite_statistic(improvement) &&
            improvement >= Float64(screen[
                "median_improvement_over_native_J_C_degrees_min"]),
        median_relative_direction_error=_finite_statistic(relative_median) &&
            relative_median <= Float64(screen[
                "median_relative_direction_error_max"]),
        strict_descent=descent_count == nonzero_count,
        finite_values=finite_values && summary_finite,
    )
    (; channel=String(channel),
       frame_count=length(unique(Int(row.frame) for row in selected)),
       state_count, defined_count=length(defined), both_zero_count=both_zero,
       candidate_zero_only_count=candidate_zero,
       teacher_zero_only_count=teacher_zero,
       aligned_or_evaluable_count=aligned_count,
       aligned_or_evaluable_coverage=coverage,
       one_sided_zero_count=one_sided,
       one_sided_zero_fraction=one_sided_fraction,
       candidate_median_angle_defined=candidate_median !== nothing,
       candidate_median_angle_degrees=something(candidate_median, 0.0),
       candidate_p90_angle_defined=candidate_p90 !== nothing,
       candidate_p90_angle_degrees=something(candidate_p90, 0.0),
       baseline_median_angle_defined=baseline_median !== nothing,
       baseline_median_angle_degrees=something(baseline_median, 0.0),
       jointly_defined_angle_count=length(jointly),
       median_angle_improvement_defined=improvement !== nothing,
       median_angle_improvement_degrees=something(improvement, 0.0),
       relative_error_evaluable_count=length(relative),
       median_relative_direction_error_defined=relative_median !== nothing,
       candidate_median_relative_direction_error=
           something(relative_median, 0.0),
       nonzero_candidate_direction_count=nonzero_count,
       strict_descent_count=descent_count,
       finite_state_count=count(row -> Bool(row.finite_values), selected),
       median_angle_gate_passed=checks.median_angle,
       p90_angle_gate_passed=checks.p90_angle,
       aligned_or_evaluable_coverage_gate_passed=
           checks.aligned_or_evaluable_coverage,
       one_sided_zero_gate_passed=checks.one_sided_zero,
       median_paired_improvement_gate_passed=
           checks.median_paired_improvement,
       median_relative_direction_error_gate_passed=
           checks.median_relative_direction_error,
       strict_descent_gate_passed=checks.strict_descent,
       finite_values_gate_passed=checks.finite_values,
       direction_screen_passed=all(values(checks)))
end

end # module
