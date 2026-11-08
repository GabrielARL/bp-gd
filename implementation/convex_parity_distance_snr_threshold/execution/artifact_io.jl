# Keep the packet, candidate, and scorer on the already tested byte and CSV
# conventions used by the preceding convex-parity-distance experiment.  The
# guard permits several execution modules to include this shim in one process.
if !isdefined(@__MODULE__, :ConvexParityDistanceArtifactIO)
    include(normpath(joinpath(
        @__DIR__, "..", "..", "convex_parity_distance", "execution",
        "artifact_io.jl")))
end
