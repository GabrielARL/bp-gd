#!/usr/bin/env julia

using LinearAlgebra
using Random
using Test

include(joinpath(@__DIR__, "two_hop_positive_metric.jl"))
using .RQ2TwoHopPositiveMetric001

const Core = RQ2TwoHopPositiveMetric001
const ARITHMETIC_ATOL = 3.0e-13
const ARITHMETIC_RTOL = 3.0e-13

repeated_path_graph() = EdgeGraph(
    [[1, 2, 3], [1, 2, 4], [3, 4, 5], [2, 5]], 5)

function ordered_product_excluding(graph, z, check, omitted::Tuple)
    product = 1.0
    for edge in graph.check_edges[check]
        edge in omitted && continue
        product *= Float64(z[edge])
    end
    product
end

function explicit_family_matrix(graph, pattern, z, llr, family)
    edges = edge_count(graph)
    matrix = zeros(Float64, edges, edges)
    for path in pattern.paths
        h_i = clamp(Float64(llr[path.output_variable]), -20.0, 20.0) / 20.0
        p_i_c = ordered_product_excluding(
            graph, z, path.source_check, (path.recipient_edge,))
        r_j_c_i = ordered_product_excluding(
            graph, z, path.source_check,
            (path.recipient_edge, path.source_edge))
        u = if family == 0
            1.0
        elseif family == 1
            h_i * p_i_c
        elseif family == 2
            Float64(z[path.output_edge]) * p_i_c
        elseif family == 3
            h_i * Float64(z[path.output_edge])
        else
            error("invalid test family")
        end
        weight = u * r_j_c_i
        matrix[path.output_edge, path.source_edge] += weight
        matrix[path.source_edge, path.output_edge] += weight
    end
    normalization = max(1.0, maximum(vec(sum(abs, matrix; dims=2))))
    matrix ./ normalization, normalization
end

function explicit_direction(graph, pattern, z, llr, gradient,
                            metric_diagonal, coefficients)
    edges = edge_count(graph)
    matrix = (1.0 + coefficients.theta0) .* Matrix{Float64}(I, edges, edges)
    families = Matrix{Float64}[]
    for family in 0:(FAMILY_COUNT - 1)
        family_matrix, _ = explicit_family_matrix(
            graph, pattern, z, llr, family)
        push!(families, family_matrix)
        matrix .+= coefficients.beta[family + 1] .* family_matrix
    end
    inverse_square_root = Diagonal(1.0 ./ sqrt.(metric_diagonal))
    direction = -(inverse_square_root * matrix * inverse_square_root) * gradient
    direction, matrix, families
end

function check_sparse_dense_case(graph, z, llr, value)
    pattern = TwoHopPattern(graph)
    for family in 0:(FAMILY_COUNT - 1)
        sparse = family_sparse_action(graph, pattern, z, llr, value, family)
        dense, normalization = explicit_family_matrix(
            graph, pattern, z, llr, family)
        @test sparse.normalization ≈ normalization atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
        @test sparse.action ≈ dense * value atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
        @test sparse.normalized_row_sum_bound <= 1.0 + 16eps(Float64)
        @test maximum(abs, dense - transpose(dense)) == 0.0
        @test all(diag(dense) .== 0.0)
        @test opnorm(Symmetric(dense), 2) <= 1.0 + 64eps(Float64)
    end
end

function patterned_coefficients(mask::Int)
    theta0 = (mask & 0x01) == 0 ? 0.0 : 0.25
    active = [family for family in 1:FAMILY_COUNT
              if (mask & (1 << family)) != 0]
    beta = zeros(Float64, FAMILY_COUNT)
    if !isempty(active)
        magnitude = 0.37 * RHO_MAX * (1.0 + theta0) / length(active)
        for family in active
            beta[family] = isodd(family) ? magnitude : -magnitude
        end
    end
    MetricCoefficients(theta0, beta)
end

@testset "deterministic graph, path, and repeated-entry representation" begin
    graph = repeated_path_graph()
    first_pattern = TwoHopPattern(graph)
    second_pattern = TwoHopPattern(graph)
    @test first_pattern.paths == second_pattern.paths
    @test [(group.first_edge, group.second_edge, group.path_indices)
           for group in first_pattern.groups] ==
          [(group.first_edge, group.second_edge, group.path_indices)
           for group in second_pattern.groups]
    @test path_count(first_pattern) > length(first_pattern.groups)
    @test maximum(length(group.path_indices) for group in first_pattern.groups) >= 2

    for path in first_pattern.paths
        @test path.source_check != path.output_check
        @test path.output_variable in graph.checks[path.source_check]
        @test path.source_variable in graph.checks[path.source_check]
        @test path.source_variable != path.output_variable
        @test graph.edge_check[path.output_edge] == path.output_check
        @test graph.edge_check[path.source_edge] == path.source_check
        @test graph.edge_check[path.recipient_edge] == path.source_check
        @test graph.edge_variable[path.recipient_edge] == path.output_variable
    end

    keys = [(group.first_edge, group.second_edge) for group in first_pattern.groups]
    @test keys == sort(keys)
    @test length(keys) == length(unique(keys))

    @test_throws ArgumentError EdgeGraph([Int[]], 1)
    @test_throws ArgumentError EdgeGraph([[1, 1]], 1)
    @test_throws ArgumentError EdgeGraph([[1]], 2)
    @test_throws ArgumentError EdgeGraph([[2]], 1)
end

@testset "zero-safe prefix/suffix exclusion products" begin
    graph = EdgeGraph([[1, 2, 3, 4], [1, 4]], 4)
    tiny = nextfloat(0.0)
    z = [0.0, -0.0, tiny, -1.0, 1.0, -tiny]
    products = zero_safe_products(graph, z)
    @test all(isfinite, products.exclude_one)
    @test all(isfinite, products.exclude_two)

    for (check, range) in enumerate(graph.check_edges)
        for first_edge in range
            expected_one = ordered_product_excluding(
                graph, z, check, (first_edge,))
            @test exclude_one_product(products, first_edge) == expected_one
            for second_edge in range
                expected_two = first_edge == second_edge ? expected_one :
                    ordered_product_excluding(
                        graph, z, check, (first_edge, second_edge))
                @test exclude_two_product(
                    products, graph, first_edge, second_edge) == expected_two
            end
        end
    end

    @test exclude_two_product(products, graph, 1, 2) == -tiny
    @test exclude_two_product(products, graph, 1, 3) == 0.0
    @test_throws ArgumentError exclude_two_product(products, graph, 1, 5)

    bad = copy(z)
    bad[1] = NaN
    @test_throws DomainError zero_safe_products(graph, bad)
    bad[1] = nextfloat(1.0)
    @test_throws DomainError zero_safe_products(graph, bad)
end

@testset "sparse action agrees with explicit test-only matrices" begin
    rng = Xoshiro(0x74776f686f706d65)
    base_checks = [[1, 2, 3], [1, 2, 4], [3, 4, 5], [2, 5]]
    graph_variants = (
        EdgeGraph(base_checks, 5),
        EdgeGraph(reverse(base_checks), 5),
        EdgeGraph([reverse(check) for check in base_checks], 5),
        EdgeGraph([reverse(check) for check in reverse(base_checks)], 5),
    )

    for graph in graph_variants
        edges = edge_count(graph)
        llr = [20.0sin(0.47variable) for variable in 1:graph.n]
        value = [sin(0.31edge) - 0.2cos(0.19edge) for edge in 1:edges]
        tiny = nextfloat(0.0)
        states = (
            zeros(Float64, edges),
            fill(-0.0, edges),
            [((edge - 1) % 6 == 0 ? 0.0 :
              (edge - 1) % 6 == 1 ? -0.0 :
              (edge - 1) % 6 == 2 ? tiny :
              (edge - 1) % 6 == 3 ? -tiny :
              (edge - 1) % 6 == 4 ? 1.0 : -1.0)
             for edge in 1:edges],
            1.8 .* rand(rng, edges) .- 0.9,
        )
        for z in states
            check_sparse_dense_case(graph, z, llr, value)
        end
    end
end

@testset "all coefficient patterns and exact-zero lower endpoint" begin
    graph = repeated_path_graph()
    pattern = TwoHopPattern(graph)
    edges = edge_count(graph)
    z = [0.79sin(0.37edge) - 0.08cos(0.29edge) for edge in 1:edges]
    llr = [23.0sin(0.41variable) for variable in 1:graph.n]
    gradient = [edge == 1 ? 0.0 : edge == 2 ? -0.0 :
                0.3sin(0.17edge) + cos(0.23edge) for edge in 1:edges]
    metric = [0.25 + 0.07edge for edge in 1:edges]

    zero_coefficients = MetricCoefficients(zeros(FAMILY_COUNT + 1))
    zero_result = generic_metric_action(
        graph, pattern, z, llr, gradient, metric, zero_coefficients)
    baseline = [-(gradient[index] / metric[index]) for index in eachindex(gradient)]
    @test reinterpret(UInt64, zero_result.direction) == reinterpret(UInt64, baseline)
    @test reinterpret(UInt64, zero_result.direction) ==
          reinterpret(UInt64, zero_result.baseline)

    # All 2^5 zero/nonzero physical-coefficient patterns execute the same
    # generic action and agree with the independently materialized test matrix.
    for mask in 0:31
        coefficients = patterned_coefficients(mask)
        sparse = generic_metric_action(
            graph, pattern, z, llr, gradient, metric, coefficients)
        dense, _, _ = explicit_direction(
            graph, pattern, z, llr, gradient, metric, coefficients)
        @test sparse.direction ≈ dense atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
        @test all(isfinite, sparse.direction)
        @test all(bound -> bound <= 1.0 + 16eps(Float64),
                  sparse.family_row_sum_bounds)
    end

    # Signed-l1 boundary cases, including both polarities and a mixed face.
    for theta0 in (0.0, 0.75)
        boundary = RHO_MAX * (1.0 + theta0)
        boundary_cases = (
            [boundary, 0.0, 0.0, 0.0],
            [-boundary, 0.0, 0.0, 0.0],
            [0.0, 0.0, boundary, 0.0],
            [0.25boundary, -0.25boundary, 0.25boundary, -0.25boundary],
        )
        for beta in boundary_cases
            coefficients = MetricCoefficients(theta0, beta)
            report = coefficient_admissibility(theta0, beta)
            @test report.admissible
            @test report.l1 <= report.bound
            sparse = generic_metric_action(
                graph, pattern, z, llr, gradient, metric, coefficients)
            dense, _, _ = explicit_direction(
                graph, pattern, z, llr, gradient, metric, coefficients)
            @test sparse.direction ≈ dense atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
        end
    end
end

@testset "positivity, descent, and registered condition bounds" begin
    rng = Xoshiro(0x737064636f6e6469)
    graph = repeated_path_graph()
    pattern = TwoHopPattern(graph)
    edges = edge_count(graph)

    for repetition in 1:20
        z = 1.9 .* rand(rng, edges) .- 0.95
        llr = 60.0 .* rand(rng, graph.n) .- 30.0
        gradient = 2.0 .* rand(rng, edges) .- 1.0
        metric = 0.2 .+ 1.8 .* rand(rng, edges)
        theta0 = 0.05 + 0.7rand(rng)
        raw_beta = 2.0 .* rand(rng, FAMILY_COUNT) .- 1.0
        raw_beta ./= sum(abs, raw_beta)
        fraction = repetition == 1 ? 1.0 : 0.97rand(rng)
        beta = raw_beta .* (fraction * RHO_MAX * (1.0 + theta0))
        coefficients = MetricCoefficients(theta0, beta)

        result = generic_metric_action(
            graph, pattern, z, llr, gradient, metric, coefficients)
        dense_direction, matrix_a, families = explicit_direction(
            graph, pattern, z, llr, gradient, metric, coefficients)
        eigenvalues_a = eigvals(Symmetric(matrix_a))
        @test minimum(eigenvalues_a) > 0.0
        @test maximum(eigenvalues_a) / minimum(eigenvalues_a) <=
              RELATIVE_CONDITION_LIMIT * (1.0 + 2.0e-10)
        @test result.direction ≈ dense_direction atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
        @test dot(gradient, result.direction) < 0.0

        diagonal_scale = Diagonal(1.0 ./ sqrt.(metric))
        matrix_p = diagonal_scale * matrix_a * diagonal_scale
        eigenvalues_p = eigvals(Symmetric(matrix_p))
        actual_full_condition = maximum(eigenvalues_p) / minimum(eigenvalues_p)
        @test actual_full_condition <=
              result.condition.full_euclidean_condition_bound * (1.0 + 2.0e-10)
        @test result.condition.relative_condition_bound <=
              RELATIVE_CONDITION_LIMIT * (1.0 + 2.0e-12)
        @test all(family -> opnorm(Symmetric(family), 2) <=
                            1.0 + 64eps(Float64), families)
    end
end

@testset "valid-codeword sign covariance" begin
    graph = EdgeGraph([[1, 2, 3], [1, 2, 4]], 4)
    pattern = TwoHopPattern(graph)
    sigma = [-1.0, 1.0, -1.0, -1.0]
    edge_sigma = edge_signs(graph, sigma)
    @test edge_signs(graph, ones(graph.n)) == ones(edge_count(graph))

    z = [0.7sin(0.31edge) for edge in 1:edge_count(graph)]
    llr = [-7.0, 2.0, -1.5, 3.2]
    gradient = [0.4sin(0.19edge) + 0.2cos(0.37edge)
                for edge in 1:edge_count(graph)]
    value = [sin(0.43edge) for edge in 1:edge_count(graph)]
    metric = [0.4 + 0.11edge for edge in 1:edge_count(graph)]
    transformed = sign_transform(graph, z, llr, value, sigma)
    @test transformed.z == edge_sigma .* z
    @test transformed.llr == sigma .* llr
    @test transformed.value == edge_sigma .* value

    for family in 0:(FAMILY_COUNT - 1)
        original = family_sparse_action(
            graph, pattern, z, llr, value, family)
        changed = family_sparse_action(
            graph, pattern, transformed.z, transformed.llr,
            transformed.value, family)
        @test changed.normalization ≈ original.normalization atol=2.0e-14 rtol=2.0e-14
        @test changed.action ≈ edge_sigma .* original.action atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL

        original_matrix, _ = explicit_family_matrix(
            graph, pattern, z, llr, family)
        changed_matrix, _ = explicit_family_matrix(
            graph, pattern, transformed.z, transformed.llr, family)
        sign_matrix = Diagonal(edge_sigma)
        @test changed_matrix ≈ sign_matrix * original_matrix * sign_matrix atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL
    end

    coefficients = MetricCoefficients(0.2, [0.11, -0.07, 0.09, -0.05])
    original = generic_metric_action(
        graph, pattern, z, llr, gradient, metric, coefficients)
    changed = generic_metric_action(
        graph, pattern, transformed.z, transformed.llr,
        edge_sigma .* gradient, metric, coefficients)
    @test changed.direction ≈ edge_sigma .* original.direction atol=ARITHMETIC_ATOL rtol=ARITHMETIC_RTOL

    @test_throws ArgumentError edge_signs(graph, [1.0, 1.0, 1.0, -1.0])
    @test_throws ArgumentError edge_signs(graph, [1.0, 0.0, 1.0, 1.0])
end

@testset "coefficient, finite-input, and production-density failures" begin
    @test coefficient_admissibility(0.0, zeros(4)).admissible
    @test !coefficient_admissibility(-eps(Float64), zeros(4)).admissible
    @test !coefficient_admissibility(0.0, fill(0.3, 4)).admissible
    @test !coefficient_admissibility(NaN, zeros(4)).admissible
    @test_throws ArgumentError MetricCoefficients(-1.0, zeros(4))
    @test_throws ArgumentError MetricCoefficients(0.0, fill(0.3, 4))
    @test_throws ArgumentError MetricCoefficients(0.0, [0.0, NaN, 0.0, 0.0])
    @test_throws DimensionMismatch MetricCoefficients(zeros(4))

    positive_zero_bits = reinterpret(UInt64, 0.0)
    negative_zero_bits = reinterpret(UInt64, -0.0)
    @test reinterpret(UInt64, plus0(0.0, -0.0)) == positive_zero_bits
    @test reinterpret(UInt64, plus0(-0.0, 0.0)) == negative_zero_bits
    @test plus0(1.25, 0.5) == 1.75

    graph = repeated_path_graph()
    pattern = TwoHopPattern(graph)
    edges = edge_count(graph)
    z = zeros(edges)
    llr = zeros(graph.n)
    value = ones(edges)
    metric = ones(edges)
    coefficients = MetricCoefficients(zeros(5))

    bad_z = copy(z); bad_z[1] = Inf
    @test_throws DomainError family_sparse_action(
        graph, pattern, bad_z, llr, value, 0)
    bad_llr = copy(llr); bad_llr[1] = NaN
    @test_throws DomainError family_sparse_action(
        graph, pattern, z, bad_llr, value, 0)
    bad_value = copy(value); bad_value[1] = Inf
    @test_throws DomainError family_sparse_action(
        graph, pattern, z, llr, bad_value, 0)
    @test_throws ArgumentError family_sparse_action(
        graph, pattern, z, llr, value, 4)
    bad_metric = copy(metric); bad_metric[1] = 0.0
    @test_throws DomainError generic_metric_action(
        graph, pattern, z, llr, value, bad_metric, coefficients)
    bad_metric[1] = nextfloat(0.0)
    huge_gradient = copy(value); huge_gradient[1] = floatmax(Float64)
    @test_throws DomainError generic_metric_action(
        graph, pattern, z, llr, huge_gradient, bad_metric, coefficients)

    # Dense edge-by-edge construction is confined to this test file.
    production_source = read(joinpath(@__DIR__, "two_hop_positive_metric.jl"), String)
    @test !occursin("Matrix{Float64}(I", production_source)
    @test !occursin("zeros(Float64, edge_count(graph), edge_count(graph))",
                    production_source)
    @test !occursin("zeros(Float64, edges, edges)", production_source)
end

