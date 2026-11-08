module ConvexParityDistanceLocalCurvature

import ConvexParityDistance

const CPD = ConvexParityDistance

export Problem, AdaptiveWorkspace, AdaptiveStepSummary,
       PARITY_WEIGHT, GLOBAL_CURVATURE, MINIMUM_CURVATURE,
       INITIAL_CURVATURE, BACKTRACK_FACTOR, MAXIMUM_TRIALS,
       MAJORIZATION_ULPS, initialize_state, adaptive_step!,
       checkpoint_evaluate!, readout!

const Problem = CPD.Problem
const PARITY_WEIGHT = CPD.PARITY_WEIGHT
const GLOBAL_CURVATURE = PARITY_WEIGHT * CPD.VARIABLE_DEGREE
const MINIMUM_CURVATURE = 1.0
const INITIAL_CURVATURE = 1.0
const BACKTRACK_FACTOR = 2.0
const MAXIMUM_TRIALS = 10
const MAJORIZATION_ULPS = 256.0

GLOBAL_CURVATURE == 288.0 || error("the frozen global curvature must be 288")

"""Reusable state for deterministic local-curvature projected gradient."""
mutable struct AdaptiveWorkspace
    current::CPD.SolverWorkspace
    trial::CPD.SolverWorkspace
    checkpoint::CPD.SolverWorkspace
    trial_state::Vector{Float64}
    cached_state::Vector{Float64}
    previous_state::Vector{Float64}
    previous_gradient::Vector{Float64}
    current_value::Float64
    current_normalized_value::Float64
    current_valid::Bool
    history_valid::Bool
    last_curvature::Float64
end

function AdaptiveWorkspace(problem::Problem)
    n = length(problem.llr)
    AdaptiveWorkspace(
        CPD.SolverWorkspace(problem), CPD.SolverWorkspace(problem),
        CPD.SolverWorkspace(problem), zeros(n), zeros(n), zeros(n), zeros(n),
        NaN, NaN, false, false, INITIAL_CURVATURE)
end

"""Scalar audit record for one accepted adaptive projected-gradient update."""
struct AdaptiveStepSummary
    objective_before::Float64
    objective_after::Float64
    normalized_objective_before::Float64
    normalized_objective_after::Float64
    seed_curvature::Float64
    secant_curvature::Float64
    seed_kind::Symbol
    accepted_curvature::Float64
    step_size::Float64
    trial_evaluations::Int
    objective_evaluations::Int
    backtracks::Int
    projected_mapping_inf::Float64
    displacement_norm_inf::Float64
    displacement_norm_squared::Float64
    gradient_dot_displacement::Float64
    projection_inequality::Float64
    model_upper_bound::Float64
    majorization_allowance::Float64
    stationary::Bool
end

initialize_state(problem::Problem) = CPD.initialize_state(problem)

@inline _float_bits(value::Float64) = reinterpret(UInt64, value)

function _same_state(first::Vector{Float64}, second::Vector{Float64})
    length(first) == length(second) || return false
    @inbounds for index in eachindex(first)
        _float_bits(first[index]) == _float_bits(second[index]) || return false
    end
    true
end

function _refresh_current!(workspace::AdaptiveWorkspace, problem::Problem,
                           state::Vector{Float64})
    if workspace.current_valid && _same_state(state, workspace.cached_state)
        return 0
    end
    workspace.current_valid && (workspace.history_valid = false)
    evaluated = CPD.evaluate!(workspace.current, problem, state)
    workspace.current_value = evaluated.value
    workspace.current_normalized_value = evaluated.normalized_value
    copyto!(workspace.cached_state, state)
    workspace.current_valid = true
    1
end

function _curvature_seed(workspace::AdaptiveWorkspace,
                         state::Vector{Float64})
    if !workspace.history_valid
        return (INITIAL_CURVATURE, NaN, :initial)
    end

    secant_numerator = 0.0
    secant_denominator = 0.0
    @inbounds for index in eachindex(state)
        state_change = state[index] - workspace.previous_state[index]
        gradient_change = workspace.current.gradient[index] -
            workspace.previous_gradient[index]
        secant_numerator += state_change * gradient_change
        secant_denominator += state_change * state_change
    end
    if secant_denominator > 0.0 && secant_numerator > 0.0
        secant = secant_numerator / secant_denominator
        if isfinite(secant)
            return (clamp(secant, MINIMUM_CURVATURE, GLOBAL_CURVATURE),
                    secant, :secant)
        end
    end

    fallback = clamp(workspace.last_curvature / BACKTRACK_FACTOR,
                     MINIMUM_CURVATURE, GLOBAL_CURVATURE)
    (fallback, NaN, :fallback)
end

function _projected_trial!(workspace::AdaptiveWorkspace,
                           state::Vector{Float64}, curvature::Float64)
    inverse_curvature = inv(curvature)
    displacement_norm_squared = 0.0
    displacement_norm_inf = 0.0
    gradient_dot_displacement = 0.0
    @inbounds for index in eachindex(state)
        before = state[index]
        after = clamp(before - inverse_curvature *
                      workspace.current.gradient[index], 0.0, 1.0)
        workspace.trial_state[index] = after
        displacement = after - before
        displacement_norm_squared += displacement * displacement
        displacement_norm_inf = max(displacement_norm_inf, abs(displacement))
        gradient_dot_displacement +=
            workspace.current.gradient[index] * displacement
    end
    (; displacement_norm_squared, displacement_norm_inf,
       gradient_dot_displacement)
end

@inline function _roundoff_allowance(values::Float64...)
    scale = 1.0
    @inbounds for value in values
        scale = max(scale, abs(value))
    end
    MAJORIZATION_ULPS * eps(Float64) * scale
end

"""
    adaptive_step!(workspace, problem, state)

Apply one deterministic projected-gradient update to the unchanged convex
parity-distance objective. A local secant curvature seeds a monotone
majorization backtrack. The accepted curvature never exceeds the proven global
bound 288, so every accepted step is at least as large as the predecessor's
fixed `1/288` step.

The caller-owned `state` is changed only after a trial passes both the smooth
majorization test and a monotonicity check. A Float64 roundoff allowance is
reported in the returned summary.
"""
function adaptive_step!(workspace::AdaptiveWorkspace, problem::Problem,
                        state::Vector{Float64})
    length(state) == length(problem.llr) || throw(DimensionMismatch(
        "state length differs from the problem"))
    current_evaluations = _refresh_current!(workspace, problem, state)
    objective_before = workspace.current_value
    normalized_before = workspace.current_normalized_value
    seed, secant, seed_kind = _curvature_seed(workspace, state)
    curvature = seed

    for trial_index in 1:MAXIMUM_TRIALS
        displacement = _projected_trial!(workspace, state, curvature)
        mapping_inf = curvature * displacement.displacement_norm_inf
        projection_inequality = displacement.gradient_dot_displacement +
            curvature * displacement.displacement_norm_squared

        if displacement.displacement_norm_squared == 0.0
            workspace.last_curvature = curvature
            return AdaptiveStepSummary(
                objective_before, objective_before,
                normalized_before, normalized_before,
                seed, secant, seed_kind, curvature, inv(curvature),
                0, current_evaluations, 0, 0.0, 0.0, 0.0, 0.0,
                projection_inequality, objective_before, 0.0, true)
        end

        trial_evaluation = CPD.evaluate!(
            workspace.trial, problem, workspace.trial_state)
        model = objective_before + displacement.gradient_dot_displacement +
            0.5 * curvature * displacement.displacement_norm_squared
        allowance = _roundoff_allowance(
            objective_before, trial_evaluation.value, model)
        majorized = trial_evaluation.value <= model + allowance
        monotone = trial_evaluation.value <= objective_before + allowance

        if majorized && monotone
            copyto!(workspace.previous_state, state)
            copyto!(workspace.previous_gradient, workspace.current.gradient)
            copyto!(state, workspace.trial_state)
            current_workspace = workspace.current
            workspace.current = workspace.trial
            workspace.trial = current_workspace
            copyto!(workspace.cached_state, state)
            workspace.current_value = trial_evaluation.value
            workspace.current_normalized_value =
                trial_evaluation.normalized_value
            workspace.current_valid = true
            workspace.history_valid = true
            workspace.last_curvature = curvature
            return AdaptiveStepSummary(
                objective_before, trial_evaluation.value,
                normalized_before, trial_evaluation.normalized_value,
                seed, secant, seed_kind, curvature, inv(curvature),
                trial_index, current_evaluations + trial_index,
                trial_index - 1, mapping_inf,
                displacement.displacement_norm_inf,
                displacement.displacement_norm_squared,
                displacement.gradient_dot_displacement,
                projection_inequality, model, allowance, false)
        end

        curvature == GLOBAL_CURVATURE && error(
            "global-curvature trial failed the frozen majorization check")
        curvature = min(GLOBAL_CURVATURE,
                        BACKTRACK_FACTOR * curvature)
    end
    error("adaptive projected-gradient search exhausted its frozen trials")
end

"""Evaluate the predecessor's fixed-`1/288` stationarity mapping at `state`."""
function checkpoint_evaluate!(workspace::AdaptiveWorkspace, problem::Problem,
                              state::Vector{Float64};
                              capture_hash::Bool=false)
    CPD.checkpoint_evaluate!(workspace.checkpoint, problem, state;
                             capture_hash=capture_hash)
end

"""Apply the unchanged hard-decision, tie, and syndrome rule."""
function readout!(workspace::AdaptiveWorkspace, problem::Problem,
                  state::Vector{Float64})
    CPD.readout!(workspace.checkpoint, problem, state)
end

end # module
