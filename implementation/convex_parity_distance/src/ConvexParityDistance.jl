module ConvexParityDistance

using LinearAlgebra
using SHA

export CHECK_DEGREE, VARIABLE_DEGREE, PARITY_WEIGHT, STEP_SIZE,
       TIE_TOLERANCE, DISTANCE_TOLERANCE, Problem, SolverWorkspace, initialize_state,
       parity_project_box, evaluate!, checkpoint_evaluate!, step!, audited_step!,
       objective_gradient,
       projected_gradient_mapping, projected_gradient_step,
       hard_decision, syndrome, readout!,
       readout_diagnostics, vector_sha256

const CHECK_DEGREE = 6
const VARIABLE_DEGREE = 3
const PARITY_WEIGHT = 96.0
const STEP_SIZE = 1.0 / (PARITY_WEIGHT * VARIABLE_DEGREE)
const TIE_TOLERANCE = 1.0e-12
const DISTANCE_TOLERANCE = 1.0e-10

"""
    Problem(checks, llr)

Construct the frozen degree-(3,6) problem seen by the candidate. `checks`
contains one-based bit indices. Positive channel LLR favours bit zero. The
constructor deliberately accepts no transmitted word, BP state, frame number,
or signal-to-noise-ratio field.
"""
struct Problem
    checks::Vector{Vector{Int}}
    llr::Vector{Float64}

    function Problem(checks::Vector{Vector{Int}}, llr::Vector{Float64},
                     ::Val{:validated})
        new(checks, llr)
    end
end

function Problem(checks, llr::AbstractVector{<:Real})
    llr64 = Float64.(llr)
    n = length(llr64)
    n > 0 || throw(ArgumentError("at least one channel LLR is required"))
    all(isfinite, llr64) ||
        throw(ArgumentError("channel LLRs must be finite"))

    converted = Vector{Vector{Int}}()
    degrees = zeros(Int, n)
    for (check_index, source) in enumerate(checks)
        check = Int.(source)
        length(check) == CHECK_DEGREE || throw(ArgumentError(
            "check $check_index has degree $(length(check)); " *
            "the frozen candidate requires degree $CHECK_DEGREE"))
        length(unique(check)) == CHECK_DEGREE || throw(ArgumentError(
            "check $check_index repeats a bit index"))
        for bit in check
            1 <= bit <= n || throw(ArgumentError(
                "check $check_index contains bit $bit outside 1:$n"))
            degrees[bit] += 1
        end
        push!(converted, check)
    end
    isempty(converted) && throw(ArgumentError("at least one check is required"))
    all(==(VARIABLE_DEGREE), degrees) || throw(ArgumentError(
        "the frozen candidate requires variable degree $VARIABLE_DEGREE"))
    Problem(converted, llr64, Val(:validated))
end

mutable struct ProjectionWorkspace
    permutation::Vector{Int}
    sorted::Vector{Float64}
    breakpoints::Vector{Float64}
end

ProjectionWorkspace() = ProjectionWorkspace(
    collect(1:CHECK_DEGREE), zeros(CHECK_DEGREE), zeros(CHECK_DEGREE))

"""
Reusable storage for objective evaluations and projected-gradient updates.

The arrays are owned by the workspace. In particular, the `gradient` returned
by `evaluate!` aliases `workspace.gradient` and is overwritten by the next
evaluation.
"""
mutable struct SolverWorkspace
    gradient::Vector{Float64}
    trial::Vector{Float64}
    local_state::Vector{Float64}
    local_projection::Vector{Float64}
    projection::ProjectionWorkspace
    hard::BitVector
    syndrome::BitVector
end

struct StepSummary
    objective_before::Float64
    normalized_objective_before::Float64
    mapping_norm_inf::Float64
end

struct ReadoutSummary
    syndrome_weight::Int
    tie_count::Int
    parity_valid::Bool
end

SolverWorkspace(problem::Problem) = SolverWorkspace(
    zeros(length(problem.llr)), zeros(length(problem.llr)),
    zeros(CHECK_DEGREE), zeros(CHECK_DEGREE), ProjectionWorkspace(),
    falses(length(problem.llr)), falses(length(problem.checks)))

function _validate_box_state(state::AbstractVector{<:Real}, expected::Int)
    length(state) == expected || throw(DimensionMismatch(
        "state length $(length(state)) differs from expected length $expected"))
    for value in state
        isfinite(value) || throw(ArgumentError("state values must be finite"))
        0.0 <= value <= 1.0 || throw(ArgumentError(
            "the parity projector requires inputs in the closed interval [0,1]"))
    end
    nothing
end

function _stable_descending_permutation!(workspace::ProjectionWorkspace,
                                         input)
    permutation = workspace.permutation
    @inbounds for index in 1:CHECK_DEGREE
        permutation[index] = index
    end
    @inbounds for position in 2:CHECK_DEGREE
        index = permutation[position]
        value = Float64(input[index])
        cursor = position - 1
        while cursor >= 1 && Float64(input[permutation[cursor]]) < value
            permutation[cursor + 1] = permutation[cursor]
            cursor -= 1
        end
        permutation[cursor + 1] = index
    end
    @inbounds for position in 1:CHECK_DEGREE
        workspace.sorted[position] = Float64(input[permutation[position]])
    end
    nothing
end

function _sort_ascending!(values::Vector{Float64})
    @inbounds for position in 2:length(values)
        value = values[position]
        cursor = position - 1
        while cursor >= 1 && values[cursor] > value
            values[cursor + 1] = values[cursor]
            cursor -= 1
        end
        values[cursor + 1] = value
    end
    values
end

"""
    parity_project_box(input)

Return the Euclidean projection of a six-entry vector in `[0,1]^6` onto the
convex hull of the even-parity binary vectors. The implementation is the
degree-six, box-input specialization of the parity-polytope cut search: after
one stable sort it solves a one-dimensional piecewise-linear equation by
walking at most six breakpoints.

This function is intentionally not a general projector for points outside the
box. Projected-gradient states satisfy the precondition by construction.
"""
function parity_project_box(input::AbstractVector{<:Real})
    output = Vector{Float64}(undef, CHECK_DEGREE)
    _parity_project_box!(output, input, ProjectionWorkspace())
end

function _parity_project_box!(output::Vector{Float64},
                              input::AbstractVector{<:Real},
                              workspace::ProjectionWorkspace)
    _validate_box_state(input, CHECK_DEGREE)
    length(output) == CHECK_DEGREE ||
        throw(DimensionMismatch("projection output must have six entries"))
    _parity_project_box_unchecked!(output, input, workspace)
end

function _parity_project_box_unchecked!(output::Vector{Float64},
                                        input::AbstractVector{<:Real},
                                        workspace::ProjectionWorkspace)
    _stable_descending_permutation!(workspace, input)
    v = workspace.sorted

    total = 0.0
    @inbounds for value in v
        total += value
    end
    r = min(CHECK_DEGREE, 2 * floor(Int, total / 2.0))

    # In exact arithmetic a box vector has sum six only when every entry is
    # one. Guard the boundary explicitly so a rounded sum cannot misclassify a
    # nearby nonvertex input as the all-one vertex.
    if r == CHECK_DEGREE
        if all(==(1.0), v)
            copyto!(output, input)
            return output
        end
        r = CHECK_DEGREE - 2
    end

    violation = -Float64(r)
    @inbounds for position in 1:(r + 1)
        violation += v[position]
    end
    @inbounds for position in (r + 2):CHECK_DEGREE
        violation -= v[position]
    end

    # For a sorted box vector with constituent parity r, this is the only
    # forbidden-set inequality that can be violated.
    if violation <= 0.0
        copyto!(output, input)
        return output
    end

    breakpoints = workspace.breakpoints
    cursor = 1
    @inbounds for position in 1:(r + 1)
        breakpoints[cursor] = v[position]       # plus entry reaches zero
        cursor += 1
    end
    @inbounds for position in (r + 2):CHECK_DEGREE
        breakpoints[cursor] = 1.0 - v[position] # minus entry reaches one
        cursor += 1
    end
    _sort_ascending!(breakpoints)

    h = violation
    beta_left = 0.0
    active = CHECK_DEGREE
    beta = NaN
    @inbounds for breakpoint in breakpoints
        width = breakpoint - beta_left
        if width > 0.0
            decrease = active * width
            if h <= decrease
                beta = beta_left + h / active
                break
            end
            h -= decrease
            beta_left = breakpoint
        end
        active -= 1
    end
    if isnan(beta)
        roundoff = 128eps(Float64) * max(1.0, abs(violation))
        abs(h) <= roundoff || error(
            "parity-polytope cut search failed to bracket its root")
        beta = beta_left
    end

    permutation = workspace.permutation
    @inbounds for position in 1:(r + 1)
        output[permutation[position]] = clamp(v[position] - beta, 0.0, 1.0)
    end
    @inbounds for position in (r + 2):CHECK_DEGREE
        output[permutation[position]] = clamp(v[position] + beta, 0.0, 1.0)
    end
    output
end

"""Map the retained soft-sign initialization into `b in [0,1]^n`."""
function initialize_state(problem::Problem)
    # If x=tanh(L/2), then b=(1-x)/2. This form is stable for the finite LLRs
    # supplied by the problem and preserves the retained sign convention.
    0.5 .* (1.0 .- tanh.(problem.llr ./ 2.0))
end

function _evaluate!(workspace::SolverWorkspace, problem::Problem,
                    state::AbstractVector{<:Real})
    n = length(problem.llr)
    _validate_box_state(state, n)
    copyto!(workspace.gradient, problem.llr)
    signal = dot(problem.llr, state)
    squared_distance_sum = 0.0
    maximum_check_distance_squared = 0.0
    infeasible_checks = 0
    checks_above_distance_tolerance = 0

    @inbounds for check in problem.checks
        for slot in 1:CHECK_DEGREE
            workspace.local_state[slot] = Float64(state[check[slot]])
        end
        _parity_project_box_unchecked!(workspace.local_projection,
                                       workspace.local_state,
                                       workspace.projection)
        check_distance_squared = 0.0
        for slot in 1:CHECK_DEGREE
            residual = workspace.local_state[slot] -
                workspace.local_projection[slot]
            check_distance_squared += residual * residual
            workspace.gradient[check[slot]] += PARITY_WEIGHT * residual
        end
        squared_distance_sum += check_distance_squared
        maximum_check_distance_squared = max(
            maximum_check_distance_squared, check_distance_squared)
        infeasible_checks += check_distance_squared > 0.0
        checks_above_distance_tolerance +=
            check_distance_squared > DISTANCE_TOLERANCE^2
    end

    parity = 0.5 * PARITY_WEIGHT * squared_distance_sum
    value = signal + parity
    (; value, normalized_value=value / n, signal,
       normalized_signal=signal / n, parity,
       normalized_parity=parity / n, squared_distance_sum,
       maximum_check_distance=sqrt(maximum_check_distance_squared),
       infeasible_checks, checks_above_distance_tolerance)
end

"""
    evaluate!(workspace, problem, state)

Evaluate the frozen unscaled objective and its partial derivatives without
allocating a new gradient. The returned `gradient` aliases workspace storage
and remains valid only until the next call using that workspace.
"""
function evaluate!(workspace::SolverWorkspace, problem::Problem,
                   state::AbstractVector{<:Real})
    scalars = _evaluate!(workspace, problem, state)
    (; scalars..., gradient=workspace.gradient)
end

"""
    objective_gradient(problem, state)

Evaluate the unscaled convex objective

`L' * b + (96/2) * sum_c dist(S_c*b, P_c)^2`

and its partial derivatives. `normalized_value` and normalized term fields
divide the same objective by the block length; this does not change its
minimizers. The returned `gradient` is for the unscaled objective, matching
the frozen step `STEP_SIZE == 1/288`.
"""
function objective_gradient(problem::Problem,
                            state::AbstractVector{<:Real})
    workspace = SolverWorkspace(problem)
    scalars = _evaluate!(workspace, problem, state)
    (; scalars..., gradient=copy(workspace.gradient),
       normalized_gradient=workspace.gradient ./ length(problem.llr))
end

function _trial_from_gradient(state, gradient)
    trial = Vector{Float64}(undef, length(state))
    @inbounds for bit in eachindex(state)
        trial[bit] = clamp(
            Float64(state[bit]) - STEP_SIZE * Float64(gradient[bit]),
            0.0, 1.0)
    end
    trial
end

function _trial_from_gradient!(trial::Vector{Float64}, state, gradient)
    length(trial) == length(state) == length(gradient) ||
        throw(DimensionMismatch("state, gradient, and trial lengths differ"))
    mapping_norm_inf = 0.0
    @inbounds for bit in eachindex(state)
        before = Float64(state[bit])
        after = clamp(before - STEP_SIZE * Float64(gradient[bit]), 0.0, 1.0)
        trial[bit] = after
        mapping_norm_inf = max(
            mapping_norm_inf, abs(before - after) / STEP_SIZE)
    end
    mapping_norm_inf
end

"""
    checkpoint_evaluate!(workspace, problem, state; capture_hash=false)

Evaluate the objective, parity-distance diagnostics, partial derivatives, and
projected-gradient mapping norm from the same supplied state. The function
writes only to workspace scratch arrays and never changes `state`. The returned
count uses the frozen Euclidean check-distance threshold
`DISTANCE_TOLERANCE`; stationarity and integrality thresholds belong to the
caller.
"""
function checkpoint_evaluate!(workspace::SolverWorkspace, problem::Problem,
                              state::AbstractVector{<:Real};
                              capture_hash::Bool=false)
    scalars = _evaluate!(workspace, problem, state)
    mapping_norm_inf = _trial_from_gradient!(
        workspace.trial, state, workspace.gradient)
    state_hash = capture_hash ? vector_sha256(state) : nothing
    (; scalars..., mapping_norm_inf, state_sha256=state_hash,
       gradient=workspace.gradient)
end

"""
    step!(workspace, problem, state)

Evaluate the current state once, form the frozen projected-gradient update in
preallocated storage, and replace `state` in place. The returned immutable
summary contains only the before-state objective and mapping norm. The
next-state objective, hashes, and a copied gradient are deliberately absent
from this per-update path. `workspace.gradient` remains bound to the state
before the update.
"""
function step!(workspace::SolverWorkspace, problem::Problem,
               state::Vector{Float64})
    before = _evaluate!(workspace, problem, state)
    mapping_norm_inf = _trial_from_gradient!(
        workspace.trial, state, workspace.gradient)
    copyto!(state, workspace.trial)
    StepSummary(before.value, before.normalized_value, mapping_norm_inf)
end

"""Apply one update while optionally calculating audit-only outputs."""
function audited_step!(workspace::SolverWorkspace, problem::Problem,
                       state::Vector{Float64}; evaluate_after::Bool=false,
                       capture_hashes::Bool=false,
                       capture_gradient::Bool=false)
    before = _evaluate!(workspace, problem, state)
    gradient = capture_gradient ? copy(workspace.gradient) : nothing
    mapping_norm_inf = _trial_from_gradient!(
        workspace.trial, state, workspace.gradient)
    before_hash = capture_hashes ? vector_sha256(state) : nothing
    copyto!(state, workspace.trial)
    after_hash = capture_hashes ? vector_sha256(state) : nothing
    after = evaluate_after ? _evaluate!(workspace, problem, state) : nothing
    (; objective_before=before.value,
       normalized_objective_before=before.normalized_value,
       objective_after=after === nothing ? nothing : after.value,
       normalized_objective_after=
           after === nothing ? nothing : after.normalized_value,
       mapping_norm_inf, gradient,
       state_before_sha256=before_hash,
       state_after_sha256=after_hash)
end

"""Return the frozen projected-gradient mapping at `state`."""
function projected_gradient_mapping(problem::Problem,
                                    state::AbstractVector{<:Real})
    evaluated = objective_gradient(problem, state)
    trial = _trial_from_gradient(state, evaluated.gradient)
    mapping = (Float64.(state) .- trial) ./ STEP_SIZE
    (; mapping, norm_inf=maximum(abs, mapping), trial,
       objective=evaluated.value, state_sha256=vector_sha256(state),
       trial_sha256=vector_sha256(trial))
end

"""
    projected_gradient_step(problem, state)

Apply one frozen projected-gradient update with `lambda=96`, step `1/288`,
and componentwise projection onto `[0,1]^n`. No line search, BP quantity, or
transmitted-word field is consulted.
"""
function projected_gradient_step(problem::Problem,
                                 state::AbstractVector{<:Real})
    current = Float64.(state)
    next_state = copy(current)
    workspace = SolverWorkspace(problem)
    result = audited_step!(workspace, problem, next_state;
                           evaluate_after=true, capture_hashes=true,
                           capture_gradient=true)
    mapping = (current .- next_state) ./ STEP_SIZE
    diagnostics = readout_diagnostics(problem, next_state)
    (; state=next_state, objective_before=result.objective_before,
       objective_after=result.objective_after,
       normalized_objective_before=result.normalized_objective_before,
       normalized_objective_after=result.normalized_objective_after,
       gradient=result.gradient, mapping,
       mapping_norm_inf=maximum(abs, mapping), diagnostics,
       state_before_sha256=result.state_before_sha256,
       state_after_sha256=result.state_after_sha256,
       hard_sha256=vector_sha256(diagnostics.hard))
end

function hard_decision(state::AbstractVector{<:Real})
    all(isfinite, state) ||
        throw(ArgumentError("hard-decision input must be finite"))
    BitVector(Float64(value) > 0.5 for value in state)
end

function syndrome(checks, bits::AbstractVector{Bool})
    BitVector(isodd(sum(bits[bit] for bit in check)) for check in checks)
end

"""
    readout!(workspace, problem, state)

Update the workspace's hard-decision and syndrome buffers without allocating
new vectors. The returned immutable summary contains the syndrome weight, tie
count, and tie-free parity-valid flag. Copy `workspace.hard` only when a caller
needs to retain that estimate beyond the next readout.
"""
function readout!(workspace::SolverWorkspace, problem::Problem,
                  state::AbstractVector{<:Real})
    n = length(problem.llr)
    _validate_box_state(state, n)
    length(workspace.hard) == n || throw(DimensionMismatch(
        "workspace hard-decision buffer has the wrong length"))
    length(workspace.syndrome) == length(problem.checks) ||
        throw(DimensionMismatch("workspace syndrome buffer has the wrong length"))

    tie_count = 0
    @inbounds for bit in 1:n
        value = Float64(state[bit])
        workspace.hard[bit] = value > 0.5
        tie_count += abs(value - 0.5) <= TIE_TOLERANCE
    end

    syndrome_weight = 0
    @inbounds for (check_index, check) in enumerate(problem.checks)
        parity = false
        for bit in check
            parity = xor(parity, workspace.hard[bit])
        end
        workspace.syndrome[check_index] = parity
        syndrome_weight += parity
    end
    ReadoutSummary(syndrome_weight, tie_count,
                   syndrome_weight == 0 && tie_count == 0)
end

function readout_diagnostics(problem::Problem,
                             state::AbstractVector{<:Real})
    workspace = SolverWorkspace(problem)
    summary = readout!(workspace, problem, state)
    hard = copy(workspace.hard)
    syn = copy(workspace.syndrome)
    ties = BitVector(abs(Float64(value) - 0.5) <= TIE_TOLERANCE
                     for value in state)
    (; hard, syndrome=syn, syndrome_weight=summary.syndrome_weight,
       ties, tie_count=summary.tie_count,
       parity_valid=summary.parity_valid)
end

function vector_sha256(values::AbstractVector)
    io = IOBuffer()
    if eltype(values) <: Bool
        write(io, UInt8.(values))
    else
        contiguous = Float64.(values)
        write(io, reinterpret(UInt8, contiguous))
    end
    bytes2hex(sha256(take!(io)))
end

end # module
