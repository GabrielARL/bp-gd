# Result-publication boundary

This repository versions the compact scientific record for each completed
experiment: the prospective card and activations, implementation and tests,
post-commit score tables and manifests, result interpretation, and the hashes
that identify candidate execution and replay.

Raw packet and candidate directories are retained locally but excluded from
Git. They contain reproducible channel-LLR buffers, continuous state arrays,
packed hard decisions, and complete candidate traces; several individual
buffers exceed GitHub's 100 MB per-object limit. Their omission from Git does
not alter the local artifacts or the committed result. Exact regeneration and
scoring commands are documented beside each implementation.

The public threshold record is
[`rq2_convex_parity_distance_snr_threshold_001/2026-11-08_v2/RESULT.md`](rq2_convex_parity_distance_snr_threshold_001/2026-11-08_v2/RESULT.md).
