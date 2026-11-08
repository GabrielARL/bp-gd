module CompoundBoxGD

using LinearAlgebra
using SHA
using TOML

export DecoderConfig, Problem, DecodeResult, load_config, decode,
       objective_gradient, finite_difference_maximum, bounded_mean_projection,
       hard_decision, syndrome, vector_sha256, edge_sha256

struct DecoderConfig
    parity_weight::Float64
    binary_weight::Float64
    maximum_updates::Int
    checkpoint_updates::Vector{Int}
    initial_step::Float64
    maximum_backtracks::Int
    lower::Float64
    upper::Float64
    finite_difference_updates::Set{Int}
    finite_difference_step::Float64
    finite_difference_tolerance::Float64
    mean_tolerance::Float64
    box_tolerance::Float64
end

function load_config(path::AbstractString=normpath(joinpath(
        @__DIR__, "..", "config", "compound_box.toml")))
    raw = TOML.parsefile(path)
    raw["schema_version"] == "compound-box-gd/v1" ||
        throw(ArgumentError("unsupported compound-box configuration"))
    objective = raw["objective"]
    solver = raw["solver"]
    validation = raw["validation"]
    checkpoints = Int.(solver["checkpoint_updates"])
    checkpoints == [1, 30, 90] ||
        throw(ArgumentError("the retained checkpoints are 1, 30, and 90"))
    DecoderConfig(
        Float64(objective["parity_weight"]),
        Float64(objective["binary_weight"]),
        Int(solver["maximum_update_attempts"]),
        checkpoints,
        Float64(solver["initial_step"]),
        Int(solver["maximum_backtracks"]),
        Float64(solver["box_lower"]),
        Float64(solver["box_upper"]),
        Set(Int.(validation["finite_difference_updates"])),
        Float64(validation["finite_difference_step"]),
        Float64(validation["finite_difference_tolerance"]),
        Float64(validation["mean_offset_tolerance"]),
        Float64(validation["box_tolerance"]),
    )
end

struct Problem
    check_vars::Vector{Vector{Int}}
    var_edges::Vector{Vector{Tuple{Int,Int}}}
    llr::Vector{Float64}
    parity_weight::Float64
    binary_weight::Float64
    curvature_bound::Vector{Float64}
end

function variable_edges(checks::Vector{Vector{Int}}, n::Int)
    edges = [Tuple{Int,Int}[] for _ in 1:n]
    for (check_index, check) in enumerate(checks), (slot, bit) in enumerate(check)
        1 <= bit <= n || throw(ArgumentError("bit index outside 1:$n"))
        push!(edges[bit], (check_index, slot))
    end
    all(!isempty, edges) || throw(ArgumentError("isolated bits are unsupported"))
    edges
end

function Problem(check_vars, llr::AbstractVector{<:Real};
                 parity_weight::Real=2.0, binary_weight::Real=0.2)
    checks = [Int.(check) for check in check_vars]
    n = length(llr)
    edges = variable_edges(checks, n)
    curvature = [
        (2Float64(parity_weight) * length(incident) +
         8Float64(binary_weight)) / n
        for incident in edges
    ]
    all(value -> isfinite(value) && value > 0.0, curvature) ||
        throw(ArgumentError("positive finite curvature bounds are required"))
    Problem(checks, edges, Float64.(llr), Float64(parity_weight),
            Float64(binary_weight), curvature)
end

mutable struct Workspace
    gradient::Vector{Float64}
    h::Vector{Float64}
    g_rows::Vector{Vector{Float64}}
    prefix::Vector{Float64}
end

zero_edge_rows(checks) = [zeros(Float64, length(check)) for check in checks]
copy_edge_rows(rows) = [Float64.(row) for row in rows]
flatten_edge_rows(rows) = Float64[value for row in rows for value in row]

function Workspace(problem::Problem)
    Workspace(zeros(length(problem.llr)), zeros(length(problem.llr)),
        zero_edge_rows(problem.check_vars),
        zeros(maximum(length, problem.check_vars)))
end

function evaluate!(workspace::Workspace, problem::Problem,
                   x::AbstractVector{<:Real}, delta_rows)
    n = length(problem.llr)
    length(x) == n || throw(DimensionMismatch("state length differs from LLRs"))
    fill!(workspace.gradient, 0.0)
    fill!(workspace.h, 0.0)
    for row in workspace.g_rows
        fill!(row, 0.0)
    end

    count_checks = length(problem.check_vars)
    scale = 1.0 / count_checks
    parity_loss = 0.0
    @inbounds for (check_index, check) in enumerate(problem.check_vars)
        product = 1.0
        for (slot, bit) in enumerate(check)
            workspace.prefix[slot] = product
            product *= Float64(x[bit]) + Float64(delta_rows[check_index][slot])
        end
        residual = 1.0 - product
        parity_loss += scale * residual^2
        coefficient = -2.0 * scale * residual
        suffix = 1.0
        for slot in length(check):-1:1
            bit = check[slot]
            contribution = coefficient * workspace.prefix[slot] * suffix
            workspace.gradient[bit] += contribution
            workspace.g_rows[check_index][slot] = contribution
            suffix *= Float64(x[bit]) + Float64(delta_rows[check_index][slot])
        end
    end
    factor = problem.parity_weight * count_checks / n
    workspace.gradient .*= factor
    for row in workspace.g_rows
        row .*= factor
    end
    parity = factor * parity_loss

    binary = 0.0
    @inbounds for bit in eachindex(x)
        value = Float64(x[bit])
        binary_contribution =
            4problem.binary_weight * value * (value^2 - 1.0) / n
        binary += problem.binary_weight * (1.0 - value^2)^2 / n
        workspace.gradient[bit] += binary_contribution
        workspace.h[bit] = -problem.llr[bit] / (2n) + binary_contribution
    end
    channel = -dot(problem.llr, x) / (2n)
    @inbounds for bit in eachindex(x)
        workspace.gradient[bit] -= problem.llr[bit] / (2n)
    end
    (; loss=channel + (parity + binary),
       terms=(; channel, parity, binary),
       gradient=workspace.gradient, h=workspace.h, g_rows=workspace.g_rows)
end

function objective_gradient(problem::Problem, x, delta_rows)
    evaluated = evaluate!(Workspace(problem), problem, x, delta_rows)
    (; evaluated.loss, evaluated.terms, gradient=copy(evaluated.gradient))
end

function bounded_mean_projection(q::AbstractVector{<:Real}, target::Real;
                                 lower::Float64=-1.0, upper::Float64=1.0,
                                 tolerance::Float64=2.0e-12)
    d = length(q)
    d > 0 || throw(ArgumentError("bounded mean projection requires values"))
    lower <= target <= upper || throw(ArgumentError("target mean is outside box"))
    qf = Float64.(q)
    target_sum = d * Float64(target)
    if all(lower .<= qf .<= upper) && abs(sum(qf) - target_sum) <= tolerance
        return qf
    end
    target == lower && return fill(lower, d)
    target == upper && return fill(upper, d)

    lo = minimum(qf .- upper)
    hi = maximum(qf .- lower)
    for _ in 1:160
        shift = (lo + hi) / 2
        total = sum(clamp(value - shift, lower, upper) for value in qf)
        if total > target_sum
            lo = shift
        else
            hi = shift
        end
    end
    shift = (lo + hi) / 2
    z = clamp.(qf .- shift, lower, upper)
    residual = target_sum - sum(z)
    if residual > 0.0
        for index in eachindex(z)
            addition = min(residual, upper - z[index])
            z[index] += addition
            residual -= addition
            residual <= tolerance && break
        end
    elseif residual < 0.0
        for index in eachindex(z)
            subtraction = min(-residual, z[index] - lower)
            z[index] -= subtraction
            residual += subtraction
            -residual <= tolerance && break
        end
    end
    abs(sum(z) - target_sum) <= tolerance ||
        error("bounded mean projection failed its sum constraint")
    all(lower - tolerance .<= z .<= upper + tolerance) ||
        error("bounded mean projection left its box")
    z
end

function construct_offsets!(delta_next, q_rows, problem::Problem,
                            x_before, x_after, step, evaluation;
                            tolerance::Float64=2.0e-12)
    maximum_mean_error = 0.0
    for bit in eachindex(problem.var_edges)
        incident = problem.var_edges[bit]
        degree = length(incident)
        total_g = sum(evaluation.g_rows[check_index][slot]
                      for (check_index, slot) in incident; init=0.0)
        q = Vector{Float64}(undef, degree)
        for (position, (check_index, slot)) in enumerate(incident)
            g_tilde = if degree == 1
                evaluation.gradient[bit]
            else
                evaluation.h[bit] + degree / (degree - 1) *
                    (total_g - evaluation.g_rows[check_index][slot])
            end
            value = Float64(x_before[bit]) - step * g_tilde /
                problem.curvature_bound[bit]
            q[position] = value
            q_rows[check_index][slot] = value
        end
        z = bounded_mean_projection(q, Float64(x_after[bit]);
                                    tolerance=tolerance)
        offset_sum = 0.0
        for (position, (check_index, slot)) in enumerate(incident)
            offset = z[position] - Float64(x_after[bit])
            delta_next[check_index][slot] = offset
            offset_sum += offset
        end
        maximum_mean_error = max(maximum_mean_error, abs(offset_sum))
    end
    maximum_mean_error
end

function local_objective(problem::Problem, x, delta_rows, bit::Int,
                         replacement::Float64)
    n = length(x)
    value = -problem.llr[bit] * replacement / (2n) +
        problem.binary_weight * (1.0 - replacement^2)^2 / n
    for (check_index, _) in problem.var_edges[bit]
        product = 1.0
        for (slot, other_bit) in enumerate(problem.check_vars[check_index])
            scalar = other_bit == bit ? replacement : Float64(x[other_bit])
            product *= scalar + Float64(delta_rows[check_index][slot])
        end
        value += problem.parity_weight * (1.0 - product)^2 / n
    end
    value
end

function finite_difference_maximum(problem::Problem, x, delta_rows,
                                   analytic_gradient;
                                   step::Float64=1.0e-6)
    maximum_error = 0.0
    maximum_bit = 0
    for bit in eachindex(x)
        center = Float64(x[bit])
        objective(replacement) =
            local_objective(problem, x, delta_rows, bit, replacement)
        numerical = (objective(center - 2step) - 8objective(center - step) +
                     8objective(center + step) - objective(center + 2step)) /
                    (12step)
        error = abs(numerical - Float64(analytic_gradient[bit]))
        if error > maximum_error
            maximum_error = error
            maximum_bit = bit
        end
    end
    (; maximum_error, maximum_bit)
end

hard_decision(x) = BitVector(Float64(value) < 0.0 for value in x)

function syndrome(check_vars, bits)
    BitVector(isodd(sum(bits[bit] for bit in check)) for check in check_vars)
end

function vector_sha256(values::AbstractVector)
    io = IOBuffer()
    if eltype(values) <: Bool
        write(io, UInt8.(values))
    else
        contiguous = collect(values)
        write(io, reinterpret(UInt8, contiguous))
    end
    bytes2hex(sha256(take!(io)))
end

function edge_sha256(rows)
    io = IOBuffer()
    for row in rows
        write(io, reinterpret(UInt8, Float64.(row)))
    end
    bytes2hex(sha256(take!(io)))
end

struct DecodeResult
    x::Vector{Float64}
    delta::Vector{Vector{Float64}}
    hard::BitVector
    syndrome::BitVector
    accepted_steps::Int
    last_effective_update::Int
    status::String
    snapshots::Dict{Int,NamedTuple}
    trace::Vector{NamedTuple}
    maximum_finite_difference_error::Float64
    all_strict_decrease::Bool
    maximum_offset_mean_error::Float64
end

function save_snapshot!(snapshots, update, problem::Problem, x, delta,
                        accepted_objective)
    # `objective` is retained as the historical accepted-step value.  At
    # update 1 that value was calculated before the newly constructed offsets
    # replaced the zero offsets, so also bind an explicit objective to the
    # x/delta pair stored in this snapshot.
    stored_state_objective =
        evaluate!(Workspace(problem), problem, x, delta).loss
    accepted = Float64(accepted_objective)
    snapshots[update] = (
        x=copy(x), delta=copy_edge_rows(delta), objective=accepted,
        accepted_objective=accepted,
        stored_state_objective=Float64(stored_state_objective),
        x_sha256=vector_sha256(x), delta_sha256=edge_sha256(delta),
        hard_sha256=vector_sha256(hard_decision(x)),
    )
end

function decode(check_vars, llr::AbstractVector{<:Real};
                config::DecoderConfig=load_config(),
                validate_derivatives::Bool=true)
    problem = Problem(check_vars, llr;
        parity_weight=config.parity_weight,
        binary_weight=config.binary_weight)
    x = clamp.(tanh.(problem.llr ./ 2.0), config.lower, config.upper)
    trial = similar(x)
    raw_trial = similar(x)
    direction = similar(x)
    delta = zero_edge_rows(problem.check_vars)
    q_rows = zero_edge_rows(problem.check_vars)
    before_workspace = Workspace(problem)
    trial_workspace = Workspace(problem)
    snapshots = Dict{Int,NamedTuple}()
    trace = NamedTuple[]
    accepted_steps = 0
    last_effective_update = 0
    status = "steps_completed"
    maximum_fd_error = 0.0
    all_strict_decrease = true
    maximum_offset_mean_error = 0.0

    for update in 1:config.maximum_updates
        before = evaluate!(before_workspace, problem, x, delta)
        fd = if validate_derivatives && update in config.finite_difference_updates
            finite_difference_maximum(problem, x, delta, before.gradient;
                                      step=config.finite_difference_step)
        else
            (; maximum_error=0.0, maximum_bit=0)
        end
        maximum_fd_error = max(maximum_fd_error, fd.maximum_error)
        fd.maximum_error <= config.finite_difference_tolerance || error(
            "finite-difference gate failed at update $update: " *
            "$(fd.maximum_error) > $(config.finite_difference_tolerance)")

        @inbounds for bit in eachindex(x)
            direction[bit] = -before.gradient[bit] /
                problem.curvature_bound[bit]
        end
        accepted = false
        accepted_step = 0.0
        accepted_loss = before.loss
        trial_count = 0
        for backtrack in 0:config.maximum_backtracks
            step = config.initial_step * 0.5^backtrack
            @inbounds for bit in eachindex(x)
                raw_trial[bit] = x[bit] + step * direction[bit]
                trial[bit] = clamp(raw_trial[bit], config.lower, config.upper)
            end
            trial_count += 1
            evaluated = evaluate!(trial_workspace, problem, trial, delta)
            if isfinite(evaluated.loss) && evaluated.loss < before.loss
                accepted = true
                accepted_step = step
                accepted_loss = evaluated.loss
                break
            end
        end

        if !accepted
            status = "line_search_stalled"
            push!(trace, (
                update, accepted=false, loss_before=before.loss,
                loss_after=before.loss, accepted_step=0.0, trial_count,
                finite_difference_maximum_error=fd.maximum_error,
                x_sha256=vector_sha256(x), delta_sha256=edge_sha256(delta),
            ))
            break
        end

        all_strict_decrease &= accepted_loss < before.loss
        if update == 1
            delta_next = zero_edge_rows(problem.check_vars)
            maximum_offset_mean_error = construct_offsets!(
                delta_next, q_rows, problem, x, trial, accepted_step, before;
                tolerance=config.mean_tolerance)
            maximum_offset_mean_error <= config.mean_tolerance || error(
                "offset mean gate failed: $maximum_offset_mean_error")
            delta = delta_next
        end
        x, trial = trial, x
        accepted_steps += 1
        last_effective_update = update
        push!(trace, (
            update, accepted=true, loss_before=before.loss,
            loss_after=accepted_loss, accepted_step, trial_count,
            finite_difference_maximum_error=fd.maximum_error,
            x_sha256=vector_sha256(x), delta_sha256=edge_sha256(delta),
        ))
        if update in config.checkpoint_updates
            save_snapshot!(snapshots, update, problem, x, delta, accepted_loss)
        end
    end

    all_strict_decrease || error("an accepted step did not decrease the objective")
    maximum(abs, x) <= config.upper + config.box_tolerance ||
        error("state exceeded the upper box bound")
    minimum(x) >= config.lower - config.box_tolerance ||
        error("state exceeded the lower box bound")
    hard = hard_decision(x)
    syn = syndrome(problem.check_vars, hard)
    DecodeResult(copy(x), copy_edge_rows(delta), hard, syn, accepted_steps,
        last_effective_update, status, snapshots, trace, maximum_fd_error,
        all_strict_decrease, maximum_offset_mean_error)
end

end # module
