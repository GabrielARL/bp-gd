module RQ2CompoundObjectiveJC

using LinearAlgebra

export ObjectiveEvaluationError, evaluate_objective,
       fixed_metric_diagonal, SCHEMA_VERSION,
       PARITY_WEIGHT, BINARY_WEIGHT

const SCHEMA_VERSION =
    "rq2-two-hop-positive-metric-001/compound-objective-jc-v1"
const PARITY_WEIGHT = 2.0
const BINARY_WEIGHT = 0.2

struct ObjectiveEvaluationError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::ObjectiveEvaluationError) =
    print(io, error.code, ": ", error.detail)

_fail(code::Symbol, detail::AbstractString) =
    throw(ObjectiveEvaluationError(code, String(detail)))

function _graph_shape(graph)
    for name in (:n, :checks, :variable_edges, :edge_variable)
        hasproperty(graph, name) || _fail(
            :invalid_graph, "graph lacks required field $(name)")
    end
    variables = Int(getproperty(graph, :n))
    variables > 0 || _fail(
        :invalid_graph, "graph contains no variable")
    checks = getproperty(graph, :checks)
    isempty(checks) && _fail(
        :invalid_graph, "graph contains no check")
    variable_edges = getproperty(graph, :variable_edges)
    length(variable_edges) == variables || _fail(
        :invalid_graph, "variable-edge table has the wrong length")
    all(!isempty, variable_edges) || _fail(
        :invalid_graph, "graph contains an isolated variable")
    edges = length(getproperty(graph, :edge_variable))
    edges > 0 || _fail(:invalid_graph, "graph contains no edge")
    (; variables, edges, checks, variable_edges,
       edge_variable=getproperty(graph, :edge_variable))
end

function _finite_vector(value, expected::Int, name::Symbol)
    value isa AbstractVector || _fail(
        :invalid_vector, "$(name) must be an abstract vector")
    length(value) == expected || _fail(
        :dimension_mismatch,
        "$(name) has length $(length(value)); expected $(expected)")
    converted = try
        Float64.(value)
    catch error
        _fail(:invalid_vector,
              "$(name) cannot be represented as Float64: " *
              sprint(showerror, error))
    end
    all(isfinite, converted) || _fail(
        :nonfinite_input, "$(name) contains a nonfinite value")
    converted
end

function _centered_incident_mean(shape, state::Vector{Float64})
    mean_state = Vector{Float64}(undef, shape.variables)
    @inbounds for variable in 1:shape.variables
        incident = shape.variable_edges[variable]
        anchor = state[first(incident)]
        anchor_bits = reinterpret(UInt64, anchor)
        exact = true
        displacement = 0.0
        for edge in incident
            value = state[edge]
            exact &= reinterpret(UInt64, value) == anchor_bits
            displacement += value - anchor
        end
        mean_state[variable] = exact ? anchor :
            anchor + displacement / length(incident)
    end
    mean_state
end

"""
Evaluate the unchanged compound objective `J_C` in directed-edge coordinates.

The function clips the supplied channel LLRs to `[-20,20]`, calculates the
incident-edge mean, objective value, and partial derivatives, and does not
advance or project the state.
"""
function evaluate_objective(graph, llr, state)
    shape = _graph_shape(graph)
    state64 = _finite_vector(state, shape.edges, :state)
    all(value -> -1.0 <= value <= 1.0, state64) || _fail(
        :state_out_of_range, "state must lie in [-1,1]")
    llr64 = _finite_vector(llr, shape.variables, :llr)
    clipped_llr = clamp.(llr64, -20.0, 20.0)
    mean_state = _centered_incident_mean(shape, state64)

    scalar_partial_derivatives = zeros(Float64, shape.variables)
    check_count = length(shape.checks)
    scale = 1.0 / check_count
    parity_loss = 0.0
    @inbounds for members in shape.checks
        degree = length(members)
        prefix = Vector{Float64}(undef, degree)
        product = 1.0
        for slot in 1:degree
            prefix[slot] = product
            product *= mean_state[members[slot]]
        end
        residual = 1.0 - product
        parity_loss += scale * residual^2
        coefficient = -2.0 * scale * residual
        suffix = 1.0
        for slot in degree:-1:1
            variable = members[slot]
            scalar_partial_derivatives[variable] +=
                coefficient * prefix[slot] * suffix
            suffix *= mean_state[variable]
        end
    end
    parity_factor = PARITY_WEIGHT * check_count / shape.variables
    scalar_partial_derivatives .*= parity_factor
    parity = parity_factor * parity_loss

    binary = 0.0
    @inbounds for variable in 1:shape.variables
        value = mean_state[variable]
        binary += BINARY_WEIGHT * (1.0 - value^2)^2 / shape.variables
        scalar_partial_derivatives[variable] +=
            4.0 * BINARY_WEIGHT * value * (value^2 - 1.0) /
            shape.variables
    end
    channel = -dot(clipped_llr, mean_state) / (2shape.variables)
    scalar_partial_derivatives .-= clipped_llr ./ (2shape.variables)

    partial_derivatives = Vector{Float64}(undef, shape.edges)
    @inbounds for edge in eachindex(partial_derivatives)
        variable = shape.edge_variable[edge]
        partial_derivatives[edge] =
            scalar_partial_derivatives[variable] /
            length(shape.variable_edges[variable])
    end
    all(isfinite, partial_derivatives) || _fail(
        :nonfinite_output, "partial derivatives are nonfinite")
    value = channel + (parity + binary)
    isfinite(value) || _fail(
        :nonfinite_output, "objective value is nonfinite")

    (; schema_version=SCHEMA_VERSION, value, partial_derivatives,
       scalar_partial_derivatives, mean_state,
       terms=(; channel, parity, binary), clipped_llr)
end

"""Calculate the registered fixed positive diagonal matrix in edge order."""
function fixed_metric_diagonal(graph)
    shape = _graph_shape(graph)
    metric = Vector{Float64}(undef, shape.edges)
    @inbounds for variable in 1:shape.variables
        degree = length(shape.variable_edges[variable])
        curvature_bound =
            (2.0 * PARITY_WEIGHT * degree + 8.0 * BINARY_WEIGHT) /
            shape.variables
        edge_value = curvature_bound / degree
        isfinite(edge_value) && edge_value > 0.0 || _fail(
            :invalid_metric, "fixed diagonal entry is not positive and finite")
        for edge in shape.variable_edges[variable]
            metric[edge] = edge_value
        end
    end
    metric
end

end # module
