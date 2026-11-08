# Differentiable convex-parity SNR threshold audit

This directory implements the registered
`RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001` audit.  It keeps the three
scientific roles separate:

1. `execution/activation_gate.jl` verifies a prospective stage activation
   before any population packet is loaded or generated.  The activation binds
   the experiment, stage, exact ordered SNR grid, exact frame endpoints,
   30-update cap, and the SHA-256 identities of the objective, accelerated
   solver, activation gate, preparer, candidate, scorer, shared artifact
   helper, local artifact shim, project, manifest, and registration card.
2. `execution/prepare_packet.jl` is trusted input preparation.  It generates
   the registered graph and LLRs but writes no transmitted word or BP field to
   the candidate packet.
3. `execution/candidate_runner.jl` performs exactly 30 frozen accelerated
   updates, latches the first tie-free parity-valid hard estimate, and commits
   a bit-for-bit scientific replay before any scorer runs.
4. `execution/score_candidate.jl` first verifies the same prospective
   activation, including every activation-bound source hash.  It then
   cross-binds that activation to the packet marker/configuration and the
   candidate configuration/commit, verifies manifests, replay equality, the
   exact activated stage/grid/frames, and the 30-update cap.  Only then does
   it load the immutable generator, regenerate and hash-check every LLR, open
   the transmitted word, and run exact flooding sum-product BP (first zero
   syndrome or 80 message-passing iterations).  It never reruns or modifies
   the candidate.

The scorer writes `scored_cases.csv`, `snr_summary.csv`,
`threshold_summary.txt`, a source receipt, and a hash manifest.  For each SNR,
`count_pass` records only the BP-minus-margin test.  `target_pass` additionally
requires zero wrong parity-valid latches and zero trace readout ties.  The
stable threshold is the lowest SNR in a suffix for which every tested higher
level passes all three conditions.

## Completed exposed-development result

The registered coarse and fine sweeps completed on 8 November 2026. The fine
population used all 200 frames `30001:30200` at each 0.1-dB level from 4.0 to
5.0 dB. Exact sum-product BP recovered 200/200 at every level. The candidate
first met the registered `candidate >= BP - 30` target at **4.4 dB**, with
177/200 recoveries, and every higher tested level also passed. It first reached
190/200 at **4.5 dB** and first reached 200/200 at **4.8 dB**. No fine-grid
level produced a wrong parity-valid word or a readout tie.

This is an exposed-development threshold for this exact objective, solver, and
30-update budget, not an untouched confirmation or a general code threshold.
The complete result and integrity identities are in
[`RESULT.md`](../../results/rq2_convex_parity_distance_snr_threshold_001/2026-11-08_v2/RESULT.md).

## Source-only tests

These tests do not generate or open a scientific population:

```bash
julia --project=. test/packet_tests.jl
julia --project=. test/candidate_tests.jl
julia --project=. test/scorer_tests.jl
```

The scorer tests use a six-bit synthetic regular graph, a controlled synthetic
activation binding, and an injected fake BP backend.  They also verify that an
activation mismatch, invalid replay, or invalid update cap is rejected before
the backend loader is called.  Packet and candidate tests construct temporary
activation files and temporary copies of every bound source; a bad source pin
or SNR grid must fail before their generation and update counters can advance.

## Prospective stage activation

No activation is shipped as a source file because it must be written only
after all bound files have their final hashes.  A coarse activation has this
exact TOML shape (each digest is 64 lowercase hexadecimal characters):

```toml
schema = "rq2-convex-parity-distance-snr-threshold-001/stage-activation-v1"
experiment_id = "RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001"
stage = "coarse"
snr_grid_db = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0, 10.5, 11.0, 11.5, 12.0]
frame_first = 20001
frame_last = 20024
update_cap = 30

[hashes]
objective_source_sha256 = "..."
accelerated_source_sha256 = "..."
activation_gate_source_sha256 = "..."
preparer_source_sha256 = "..."
candidate_runner_source_sha256 = "..."
scorer_source_sha256 = "..."
artifact_helper_source_sha256 = "..."
local_artifact_shim_source_sha256 = "..."
project_toml_sha256 = "..."
manifest_toml_sha256 = "..."
card_sha256 = "..."
```

A fine activation uses frames `30001:30200`, the exact ordered eleven-level
grid `s_c-0.5:0.1:s_c+0.5`, and adds this table.  The two artifact digests bind
the already committed coarse score used to select `s_c`:

```toml
[coarse_result]
crossing_s_c_db = 7.0
score_commit_sha256 = "..."
score_manifest_sha256 = "..."
```

The coarse schema rejects `coarse_result`; the fine schema requires it.  Both
packet and candidate commands independently rehash every listed source before
they open their scientific input.  The verified activation digest is then
bound into the packet marker/configuration and candidate
configuration/commit.

## Registered stage commands

Run from this directory with the registered single-thread environment.  Use a
new empty directory for every artifact root.

```bash
export JULIA_NUM_THREADS=1
export OMP_NUM_THREADS=1

julia --project=. execution/prepare_packet.jl \
  --activation /absolute/path/coarse_activation.toml \
  --stage coarse \
  --snr-grid 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0,9.5,10.0,10.5,11.0,11.5,12.0 \
  --output-root /absolute/path/coarse_packet

julia --project=. execution/candidate_runner.jl \
  --activation /absolute/path/coarse_activation.toml \
  --packet-root /absolute/path/coarse_packet \
  --output-root /absolute/path/coarse_candidate

julia --project=. execution/score_candidate.jl \
  /absolute/path/coarse_activation.toml \
  /absolute/path/coarse_packet \
  /absolute/path/coarse_candidate \
  /absolute/path/coarse_score
```

The fine grid is not guessed in advance.  After the first coarse crossing is
known, freeze the registered eleven levels from `s_c-0.5` through `s_c+0.5`
in 0.1 dB steps, hash that activation, and then repeat the three phases with
`--stage fine`.  The exposed development frames are `20001:20024` for coarse
and `30001:30200` for fine.  Reserved Stage-B ranges are not used.
