module ConvexParityDistanceAccelerated

import ConvexParityDistance

const CPD = ConvexParityDistance

export Problem, AcceleratedWorkspace, AcceleratedStepSummary,
       PARITY_WEIGHT, GLOBAL_CURVATURE, initialize_state,
       accelerated_step!, checkpoint_evaluate!, readout!

const Problem = CPD.Problem
const PARITY_WEIGHT = CPD.PARITY_WEIGHT
const GLOBAL_CURVATURE = PARITY_WEIGHT * CPD.VARIABLE_DEGREE

GLOBAL_CURVATURE == 288.0 || error("the frozen global curvature must be 288")

"""
Persistent estimate-sequence state for constrained accelerated projected
gradient. The query, output, and mirror points remain in the box.
"""
mutable struct AcceleratedWorkspace
    evaluation::CPD.SolverWorkspace
    checkpoint::CPD.SolverWorkspace
    initial::Vector{Float64}
    query::Vector{Float64}
    output::Vector{Float64}
    mirror::Vector{Float64}
    gradient_sum::Vector{Float64}
    iteration::Int
end

function AcceleratedWorkspace(problem::Problem)
    initial = CPD.initialize_state(problem)
    AcceleratedWorkspace(
        CPD.SolverWorkspace(problem), CPD.SolverWorkspace(problem),
        initial, copy(initial), copy(initial), copy(initial), zeros(length(initial)),
        0)
end

"""Scalar audit record for one constrained accelerated update."""
struct AcceleratedStepSummary
    iteration::Int
    objective_at_query::Float64
    normalized_objective_at_query::Float64
    gradient_weight::Float64
    coupling_weight::Float64
    query_mapping_inf::Float64
    output_displacement_inf::Float64
    query_minimum::Float64
    query_maximum::Float64
    output_minimum::Float64
    output_maximum::Float64
    mirror_minimum::Float64
    mirror_maximum::Float64
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

"""
    accelerated_step!(workspace, problem, state)

Apply one iteration of the constrained estimate-sequence accelerated
projected-gradient method with global curvature 288. The caller-visible
`state` is the guaranteed output point `y_k`. The partial derivatives are
evaluated at `x_k`, a convex combination of the preceding output and mirror
points, so every query remains in `[0,1]^n`.

With `a_k=(k+1)/2`, the method is

```
y_k = project_box(x_k - gradient(x_k)/288)
p_k = sum_{i=0}^k a_i gradient(x_i)
z_k = project_box(b_0 - p_k/288)
x_{k+1} = (1 - 2/(k+3)) y_k + (2/(k+3)) z_k.
```

External mutation of `state` fails closed because it would invalidate the
estimate sequence.
"""
function accelerated_step!(workspace::AcceleratedWorkspace, problem::Problem,
                           state::Vector{Float64})
    length(state) == length(problem.llr) || throw(DimensionMismatch(
        "state length differs from the problem"))
    _same_state(state, workspace.output) || throw(ArgumentError(
        "caller state differs from the accelerated output; history is invalid"))

    k = workspace.iteration
    evaluated = CPD.evaluate!(workspace.evaluation, problem, workspace.query)
    gradient_weight = (k + 1) / 2.0
    coupling_weight = 2.0 / (k + 3.0)
    inverse_curvature = inv(GLOBAL_CURVATURE)
    output_displacement_inf = 0.0

    @inbounds for index in eachindex(state)
        query_value = workspace.query[index]
        gradient = workspace.evaluation.gradient[index]
        output_value = clamp(
            query_value - inverse_curvature * gradient, 0.0, 1.0)
        workspace.output[index] = output_value
        output_displacement_inf = max(
            output_displacement_inf, abs(output_value - query_value))
        workspace.gradient_sum[index] += gradient_weight * gradient
        mirror_value = clamp(
            workspace.initial[index] - inverse_curvature *
            workspace.gradient_sum[index], 0.0, 1.0)
        workspace.mirror[index] = mirror_value
        workspace.query[index] =
            (1.0 - coupling_weight) * output_value +
            coupling_weight * mirror_value
        state[index] = output_value
    end
    workspace.iteration += 1

    AcceleratedStepSummary(
        workspace.iteration, evaluated.value, evaluated.normalized_value,
        gradient_weight, coupling_weight,
        GLOBAL_CURVATURE * output_displacement_inf,
        output_displacement_inf,
        minimum(workspace.query), maximum(workspace.query),
        minimum(workspace.output), maximum(workspace.output),
        minimum(workspace.mirror), maximum(workspace.mirror))
end

"""Evaluate the unchanged fixed-`1/288` mapping at the output state."""
function checkpoint_evaluate!(workspace::AcceleratedWorkspace,
                              problem::Problem, state::Vector{Float64};
                              capture_hash::Bool=false)
    CPD.checkpoint_evaluate!(workspace.checkpoint, problem, state;
                             capture_hash=capture_hash)
end

"""Apply the unchanged hard-decision, tie, and syndrome rule."""
function readout!(workspace::AcceleratedWorkspace, problem::Problem,
                  state::Vector{Float64})
    CPD.readout!(workspace.checkpoint, problem, state)
end

end # module
