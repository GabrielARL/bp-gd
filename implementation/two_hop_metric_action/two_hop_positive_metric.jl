module RQ2TwoHopPositiveMetric001

using LinearAlgebra

const FAMILY_COUNT = 4
const RELATIVE_CONDITION_LIMIT = 1.0e4
const RHO_MAX = (RELATIVE_CONDITION_LIMIT - 1.0) /
                (RELATIVE_CONDITION_LIMIT + 1.0)

export EdgeGraph, TwoHopPath, SparsePairGroup, TwoHopPattern,
       ZeroSafeProducts, MetricCoefficients,
       FAMILY_COUNT, RELATIVE_CONDITION_LIMIT, RHO_MAX,
       edge_count, path_count, zero_safe_products, exclude_one_product,
       exclude_two_product, family_sparse_action, baseline_direction,
       generic_metric_action, plus0, coefficient_admissibility,
       condition_diagnostics, edge_signs, sign_transform

"""Deterministic Tanner-graph indexing with one coordinate per check edge."""
struct EdgeGraph
    n::Int
    checks::Vector{Vector{Int}}
    check_edges::Vector{UnitRange{Int}}
    variable_edges::Vector{Vector{Int}}
    edge_variable::Vector{Int}
    edge_check::Vector{Int}
    edge_local::Vector{Int}
    check_pair_offsets::Vector{Int}
    check_pair_value_count::Int
end

function EdgeGraph(checks::Vector{<:AbstractVector{<:Integer}}, n::Integer)
    n > 0 || throw(ArgumentError("the graph must contain a variable"))
    isempty(checks) && throw(ArgumentError("the graph must contain a check"))

    copied_checks = Vector{Vector{Int}}()
    check_edges = UnitRange{Int}[]
    variable_edges = [Int[] for _ in 1:Int(n)]
    edge_variable = Int[]
    edge_check = Int[]
    edge_local = Int[]
    check_pair_offsets = Int[]
    next_edge = 1
    next_pair = 1

    for (check_index, raw_members) in enumerate(checks)
        members = Int.(raw_members)
        isempty(members) && throw(ArgumentError("check $check_index is empty"))
        length(unique(members)) == length(members) || throw(ArgumentError(
            "check $check_index repeats a variable"))
        push!(check_pair_offsets, next_pair)
        next_pair += length(members)^2

        first_edge = next_edge
        for (local_index, variable) in enumerate(members)
            1 <= variable <= n || throw(ArgumentError(
                "variable $variable lies outside 1:$n"))
            push!(edge_variable, variable)
            push!(edge_check, check_index)
            push!(edge_local, local_index)
            push!(variable_edges[variable], next_edge)
            next_edge += 1
        end
        push!(copied_checks, members)
        push!(check_edges, first_edge:(next_edge - 1))
    end

    for variable in 1:Int(n)
        isempty(variable_edges[variable]) && throw(ArgumentError(
            "variable $variable is isolated"))
    end

    EdgeGraph(Int(n), copied_checks, check_edges, variable_edges,
              edge_variable, edge_check, edge_local, check_pair_offsets,
              next_pair - 1)
end

edge_count(graph::EdgeGraph) = length(graph.edge_variable)

"""One registered ordered path `(j,c) -> c -> i -> (i,a)`."""
struct TwoHopPath
    output_edge::Int
    source_edge::Int
    output_variable::Int
    output_check::Int
    source_check::Int
    recipient_edge::Int
    source_variable::Int
    exclusion_pair_index::Int
end

"""All ordered paths contributing to one symmetric matrix entry."""
struct SparsePairGroup
    first_edge::Int
    second_edge::Int
    path_indices::Vector{Int}
end

"""Frozen sparse support and fixed summation order for the four families."""
struct TwoHopPattern
    n::Int
    checks::Vector{Vector{Int}}
    edge_variable::Vector{Int}
    edge_check::Vector{Int}
    paths::Vector{TwoHopPath}
    groups::Vector{SparsePairGroup}
end

@inline function _pair_index(graph::EdgeGraph, check::Int,
                             first_local::Int, second_local::Int)
    degree = length(graph.check_edges[check])
    graph.check_pair_offsets[check] + (first_local - 1) * degree +
        (second_local - 1)
end

function TwoHopPattern(graph::EdgeGraph)
    paths = TwoHopPath[]

    # The order is part of the experiment: output edge, other incident check,
    # then source edge in that check's declared member order.
    for output_edge in 1:edge_count(graph)
        variable = graph.edge_variable[output_edge]
        output_check = graph.edge_check[output_edge]
        for recipient_edge in graph.variable_edges[variable]
            source_check = graph.edge_check[recipient_edge]
            source_check == output_check && continue
            recipient_local = graph.edge_local[recipient_edge]
            for source_edge in graph.check_edges[source_check]
                source_variable = graph.edge_variable[source_edge]
                source_variable == variable && continue
                source_local = graph.edge_local[source_edge]
                push!(paths, TwoHopPath(
                    output_edge,
                    source_edge,
                    variable,
                    output_check,
                    source_check,
                    recipient_edge,
                    source_variable,
                    _pair_index(graph, source_check,
                                recipient_local, source_local),
                ))
            end
        end
    end

    # Group repeated ordered paths by the actual symmetric matrix entry.
    # A dictionary is used only for lookup; neither its iteration order nor
    # its hash order enters the retained arithmetic order.
    group_lookup = Dict{Tuple{Int,Int},Int}()
    unsorted_groups = SparsePairGroup[]
    for (path_index, path) in enumerate(paths)
        key = minmax(path.output_edge, path.source_edge)
        group_index = get(group_lookup, key, 0)
        if group_index == 0
            push!(unsorted_groups,
                  SparsePairGroup(key[1], key[2], Int[path_index]))
            group_lookup[key] = length(unsorted_groups)
        else
            push!(unsorted_groups[group_index].path_indices, path_index)
        end
    end
    groups = sort(unsorted_groups;
                  by=group -> (group.first_edge, group.second_edge))

    TwoHopPattern(graph.n, deepcopy(graph.checks), copy(graph.edge_variable),
                  copy(graph.edge_check), paths, groups)
end

path_count(pattern::TwoHopPattern) = length(pattern.paths)

function _require_pattern(graph::EdgeGraph, pattern::TwoHopPattern)
    pattern.n == graph.n &&
        pattern.checks == graph.checks &&
        pattern.edge_variable == graph.edge_variable &&
        pattern.edge_check == graph.edge_check || throw(ArgumentError(
            "the sparse path pattern does not belong to this graph"))
    nothing
end

function _require_finite_vector(value, expected::Int, label::AbstractString)
    length(value) == expected || throw(DimensionMismatch(
        "$label has length $(length(value)); expected $expected"))
    all(isfinite, value) || throw(DomainError(value, "$label must be finite"))
    nothing
end

function _require_state(graph::EdgeGraph, z)
    _require_finite_vector(z, edge_count(graph), "edge state")
    all(value -> -1.0 <= value <= 1.0, z) || throw(DomainError(
        z, "edge state must lie in [-1,1]"))
    nothing
end

function _require_llr(graph::EdgeGraph, llr)
    _require_finite_vector(llr, graph.n, "channel LLR vector")
    nothing
end

function _require_positive_diagonal(graph::EdgeGraph, metric_diagonal)
    _require_finite_vector(metric_diagonal, edge_count(graph),
                           "metric diagonal")
    all(value -> value > 0.0, metric_diagonal) || throw(DomainError(
        metric_diagonal, "metric diagonal must be strictly positive"))
    nothing
end

"""Prefix/suffix products with no division by an edge state."""
struct ZeroSafeProducts
    exclude_one::Vector{Float64}
    exclude_two::Vector{Float64}
end

function zero_safe_products(graph::EdgeGraph, z)
    _require_state(graph, z)
    exclude_one = Vector{Float64}(undef, edge_count(graph))
    exclude_two = ones(Float64, graph.check_pair_value_count)

    for (check, range) in enumerate(graph.check_edges)
        degree = length(range)
        for first_local in 1:degree
            recipient_edge = first(range) + first_local - 1
            prefix = 1.0

            # Prefix values for all possible second exclusions.
            for second_local in 1:degree
                second_local == first_local && continue
                index = _pair_index(graph, check, first_local, second_local)
                exclude_two[index] = prefix
                source_edge = first(range) + second_local - 1
                prefix *= Float64(z[source_edge])
                isfinite(prefix) || throw(DomainError(prefix,
                    "nonfinite prefix product"))
            end
            exclude_one[recipient_edge] = prefix

            # Multiply by suffix values, again skipping the first exclusion.
            suffix = 1.0
            for second_local in degree:-1:1
                second_local == first_local && continue
                index = _pair_index(graph, check, first_local, second_local)
                exclude_two[index] *= suffix
                isfinite(exclude_two[index]) || throw(DomainError(
                    exclude_two[index], "nonfinite two-edge exclusion product"))
                source_edge = first(range) + second_local - 1
                suffix *= Float64(z[source_edge])
                isfinite(suffix) || throw(DomainError(suffix,
                    "nonfinite suffix product"))
            end

            # The diagonal entry is not a registered path. Keeping the
            # corresponding one-edge exclusion product makes the cache fully
            # finite and gives it an unambiguous diagnostic meaning.
            diagonal_index = _pair_index(
                graph, check, first_local, first_local)
            exclude_two[diagonal_index] = exclude_one[recipient_edge]
        end
    end

    all(isfinite, exclude_one) || throw(DomainError(
        exclude_one, "nonfinite one-edge exclusion product"))
    all(isfinite, exclude_two) || throw(DomainError(
        exclude_two, "nonfinite two-edge exclusion product"))
    ZeroSafeProducts(exclude_one, exclude_two)
end

exclude_one_product(products::ZeroSafeProducts, edge::Integer) =
    products.exclude_one[Int(edge)]

function exclude_two_product(products::ZeroSafeProducts, graph::EdgeGraph,
                             first_edge::Integer, second_edge::Integer)
    first = Int(first_edge)
    second = Int(second_edge)
    1 <= first <= edge_count(graph) || throw(BoundsError(graph.edge_check, first))
    1 <= second <= edge_count(graph) || throw(BoundsError(graph.edge_check, second))
    check = graph.edge_check[first]
    graph.edge_check[second] == check || throw(ArgumentError(
        "the two excluded edges must belong to the same check"))
    products.exclude_two[_pair_index(
        graph, check, graph.edge_local[first], graph.edge_local[second])]
end

struct MetricCoefficients
    theta0::Float64
    beta::NTuple{FAMILY_COUNT,Float64}
end

function coefficient_admissibility(theta0::Real, beta;
                                   rho_max::Real=RHO_MAX)
    length(beta) == FAMILY_COUNT || return (
        admissible=false, reason="coefficient count", l1=NaN, bound=NaN)
    theta = Float64(theta0)
    converted = ntuple(index -> Float64(beta[index]), FAMILY_COUNT)
    rho = Float64(rho_max)
    if !isfinite(theta) || !all(isfinite, converted) || !isfinite(rho)
        return (admissible=false, reason="nonfinite coefficient", l1=NaN,
                bound=NaN)
    end
    if theta < 0.0
        return (admissible=false, reason="negative identity coefficient",
                l1=sum(abs, converted), bound=rho * (1.0 + theta))
    end
    if !(0.0 <= rho < 1.0)
        return (admissible=false, reason="invalid spectral-radius fraction",
                l1=sum(abs, converted), bound=NaN)
    end
    l1 = sum(abs, converted)
    bound = rho * (1.0 + theta)
    (admissible=l1 <= bound,
     reason=l1 <= bound ? "admissible" : "signed-l1 bound",
     l1, bound)
end

function MetricCoefficients(theta0::Real, beta)
    report = coefficient_admissibility(theta0, beta)
    report.admissible || throw(ArgumentError(
        "inadmissible metric coefficients: $(report.reason)"))
    MetricCoefficients(Float64(theta0),
        ntuple(index -> Float64(beta[index]), FAMILY_COUNT))
end

MetricCoefficients(values) = begin
    length(values) == FAMILY_COUNT + 1 || throw(DimensionMismatch(
        "expected $(FAMILY_COUNT + 1) physical coefficients"))
    MetricCoefficients(values[1], values[2:end])
end

@inline function plus0(a::Float64, b::Float64)
    b == 0.0 ? a : a + b
end

@inline function _path_family_weight(path::TwoHopPath, family::Int,
                                    graph::EdgeGraph, z, llr,
                                    products::ZeroSafeProducts)
    h_i = clamp(Float64(llr[path.output_variable]), -20.0, 20.0) / 20.0
    p_i_c = products.exclude_one[path.recipient_edge]
    # The path already stores the flattened recipient/source pair index.
    r_j_c_i = products.exclude_two[path.exclusion_pair_index]
    u = if family == 0
        1.0
    elseif family == 1
        h_i * p_i_c
    elseif family == 2
        Float64(z[path.output_edge]) * p_i_c
    elseif family == 3
        h_i * Float64(z[path.output_edge])
    else
        throw(ArgumentError("family must be one of 0, 1, 2, or 3"))
    end
    weight = u * r_j_c_i
    isfinite(weight) || throw(DomainError(weight,
        "nonfinite registered-path weight"))
    weight
end

function _normalized_sparse_entries(graph::EdgeGraph,
                                    pattern::TwoHopPattern,
                                    z, llr, products::ZeroSafeProducts,
                                    family::Int)
    0 <= family < FAMILY_COUNT || throw(ArgumentError(
        "family must be one of 0, 1, 2, or 3"))
    weights = Vector{Float64}(undef, length(pattern.groups))
    row_sums = zeros(Float64, edge_count(graph))

    for (group_index, group) in enumerate(pattern.groups)
        weight = 0.0
        # This is the registered fixed path order for repeated contributions.
        for path_index in group.path_indices
            weight += _path_family_weight(
                pattern.paths[path_index], family, graph, z, llr, products)
            isfinite(weight) || throw(DomainError(weight,
                "nonfinite accumulated sparse entry"))
        end
        weights[group_index] = weight
        magnitude = abs(weight)
        row_sums[group.first_edge] += magnitude
        row_sums[group.second_edge] += magnitude
    end
    all(isfinite, row_sums) || throw(DomainError(
        row_sums, "nonfinite sparse row sum"))

    maximum_row_sum = isempty(row_sums) ? 0.0 : maximum(row_sums)
    normalization = max(1.0, maximum_row_sum)
    normalized = weights ./ normalization
    all(isfinite, normalized) || throw(DomainError(
        normalized, "nonfinite normalized sparse entry"))
    (; normalized, normalization, maximum_row_sum)
end

"""Apply one normalized `S_r` using only the registered sparse paths."""
function family_sparse_action(graph::EdgeGraph, pattern::TwoHopPattern,
                              z, llr, value, family::Integer;
                              products::Union{Nothing,ZeroSafeProducts}=nothing)
    _require_pattern(graph, pattern)
    _require_state(graph, z)
    _require_llr(graph, llr)
    _require_finite_vector(value, edge_count(graph), "sparse-action input")
    cache = isnothing(products) ? zero_safe_products(graph, z) : products
    length(cache.exclude_one) == edge_count(graph) || throw(DimensionMismatch(
        "product cache does not match graph"))
    length(cache.exclude_two) == graph.check_pair_value_count ||
        throw(DimensionMismatch("product cache does not match graph"))

    entries = _normalized_sparse_entries(
        graph, pattern, z, llr, cache, Int(family))
    action = zeros(Float64, edge_count(graph))
    for (group_index, group) in enumerate(pattern.groups)
        weight = entries.normalized[group_index]
        action[group.first_edge] += weight * Float64(value[group.second_edge])
        action[group.second_edge] += weight * Float64(value[group.first_edge])
    end
    all(isfinite, action) || throw(DomainError(
        action, "nonfinite sparse family action"))
    (; action,
       normalization=entries.normalization,
       maximum_row_sum=entries.maximum_row_sum,
       normalized_row_sum_bound=entries.maximum_row_sum /
                                entries.normalization,
       pair_count=length(pattern.groups),
       path_count=length(pattern.paths))
end

function baseline_direction(gradient, metric_diagonal)
    length(gradient) == length(metric_diagonal) || throw(DimensionMismatch(
        "gradient and metric diagonal lengths differ"))
    all(isfinite, gradient) || throw(DomainError(
        gradient, "partial derivatives must be finite"))
    all(value -> isfinite(value) && value > 0.0, metric_diagonal) ||
        throw(DomainError(metric_diagonal,
            "metric diagonal must be finite and strictly positive"))
    result = [-(Float64(gradient[index]) /
                Float64(metric_diagonal[index]))
              for index in eachindex(gradient)]
    all(isfinite, result) || throw(DomainError(
        result, "nonfinite lower-endpoint direction"))
    result
end

function condition_diagnostics(coefficients::MetricCoefficients,
                               metric_diagonal)
    isempty(metric_diagonal) && throw(ArgumentError(
        "metric diagonal must be nonempty"))
    all(value -> isfinite(value) && value > 0.0, metric_diagonal) ||
        throw(DomainError(metric_diagonal,
            "metric diagonal must be finite and strictly positive"))
    scale = 1.0 + coefficients.theta0
    radius = sum(abs, coefficients.beta)
    lower = scale - radius
    upper = scale + radius
    lower > 0.0 || throw(DomainError(lower,
        "coefficient bound did not produce a positive matrix"))
    relative_bound = upper / lower
    metric_condition = maximum(metric_diagonal) / minimum(metric_diagonal)
    full_bound = relative_bound * metric_condition
    all(isfinite, (lower, upper, relative_bound, metric_condition, full_bound)) ||
        throw(DomainError(full_bound, "nonfinite condition diagnostic"))
    (; guaranteed_lambda_min_A=lower,
       guaranteed_lambda_max_A=upper,
       relative_condition_bound=relative_bound,
       metric_condition,
       full_euclidean_condition_bound=full_bound)
end

"""The single generic production action, including the exact-zero case."""
function generic_metric_action(graph::EdgeGraph, pattern::TwoHopPattern,
                               z, llr, gradient, metric_diagonal,
                               coefficients::MetricCoefficients)
    _require_pattern(graph, pattern)
    _require_state(graph, z)
    _require_llr(graph, llr)
    _require_finite_vector(gradient, edge_count(graph),
                           "partial derivatives")
    _require_positive_diagonal(graph, metric_diagonal)

    products = zero_safe_products(graph, z)
    square_root_metric = sqrt.(Float64.(metric_diagonal))
    scaled_gradient = Float64.(gradient) ./ square_root_metric
    all(isfinite, scaled_gradient) || throw(DomainError(
        scaled_gradient, "nonfinite scaled partial derivatives"))

    # These four actions are calculated unconditionally, including for an
    # exact-zero coefficient. There is no coefficient-dependent family skip.
    sparse_results = ntuple(family_index -> family_sparse_action(
        graph, pattern, z, llr, scaled_gradient, family_index - 1;
        products), FAMILY_COUNT)
    family_directions = ntuple(family_index -> begin
        direction = -sparse_results[family_index].action ./ square_root_metric
        all(isfinite, direction) || throw(DomainError(
            direction, "nonfinite family direction"))
        direction
    end, FAMILY_COUNT)

    d0 = baseline_direction(gradient, metric_diagonal)
    direction = copy(d0)

    # Fixed combination order from the prospective card. `plus0` preserves
    # every already-calculated d0 bit when a contribution is exact zero.
    for edge in eachindex(direction)
        contribution = coefficients.theta0 * d0[edge]
        isfinite(contribution) || throw(DomainError(
            contribution, "nonfinite identity contribution"))
        direction[edge] = plus0(direction[edge], contribution)
    end
    for family_index in 1:FAMILY_COUNT
        beta = coefficients.beta[family_index]
        family_direction = family_directions[family_index]
        for edge in eachindex(direction)
            contribution = beta * family_direction[edge]
            isfinite(contribution) || throw(DomainError(
                contribution, "nonfinite family contribution"))
            direction[edge] = plus0(direction[edge], contribution)
        end
    end
    all(isfinite, direction) || throw(DomainError(
        direction, "nonfinite metric direction"))

    condition = condition_diagnostics(coefficients, metric_diagonal)
    (; direction,
       baseline=d0,
       family_directions,
       family_normalizations=ntuple(
           index -> sparse_results[index].normalization, FAMILY_COUNT),
       family_row_sum_bounds=ntuple(
           index -> sparse_results[index].normalized_row_sum_bound,
           FAMILY_COUNT),
       products,
       condition,
       descent_inner_product=dot(Float64.(gradient), direction))
end

function edge_signs(graph::EdgeGraph, sigma; require_valid::Bool=true)
    length(sigma) == graph.n || throw(DimensionMismatch(
        "sign vector has length $(length(sigma)); expected $(graph.n)"))
    signs = Vector{Float64}(undef, graph.n)
    for variable in 1:graph.n
        value = Float64(sigma[variable])
        (value == -1.0 || value == 1.0) || throw(ArgumentError(
            "every sign must equal -1 or +1"))
        signs[variable] = value
    end
    if require_valid
        for (check, members) in enumerate(graph.checks)
            product = 1.0
            for variable in members
                product *= signs[variable]
            end
            product == 1.0 || throw(ArgumentError(
                "sign pattern violates check $check"))
        end
    end
    [signs[graph.edge_variable[edge]] for edge in 1:edge_count(graph)]
end

"""Apply a valid-codeword sign transformation to inference inputs."""
function sign_transform(graph::EdgeGraph, z, llr, value, sigma)
    _require_state(graph, z)
    _require_llr(graph, llr)
    _require_finite_vector(value, edge_count(graph), "edge-coordinate value")
    edge_sigma = edge_signs(graph, sigma)
    variable_sigma = Float64.(sigma)
    (; z=edge_sigma .* Float64.(z),
       llr=variable_sigma .* Float64.(llr),
       value=edge_sigma .* Float64.(value),
       edge_signs=edge_sigma)
end

end # module
