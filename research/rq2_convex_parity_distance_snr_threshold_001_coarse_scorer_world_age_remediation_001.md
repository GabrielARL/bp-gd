# Coarse scorer world-age remediation

Remediation ID:
`RQ2-CONVEX-PARITY-DISTANCE-SNR-THRESHOLD-001-COARSE-SCORER-WORLD-AGE-REMEDIATION-001`

Registration date: 8 November 2026

Status: **registered and authorized under the user's instruction to proceed;
written before a transmitted word, BP output, score row, or SNR recovery count
was opened**

## Trigger and scope

The coarse packet and candidate completed under activation SHA-256
`5707a96e0335bf3f7a0bf011883ad47d7d92bd12256cbdd42a262cfd43808e5d`.
Primary and replay candidate traces agreed at
`a181af8be06fd8a059d2943ea3e92085da3b12e4be79cf93f42660000ca0dda8`.

The post-commit scorer then stopped while loading the immutable adapter. Julia
1.12 raised `MethodError: no method matching load_config(::String)` because
the dynamically included method was newer than the caller's world. The failure
occurred before the backend constructed a transmitted word, regenerated a
case, called BP, created a score directory, or exposed any recovery count.

This remediation changes only how the trusted scorer crosses that dynamic-load
boundary. Calls and module-field reads defined by the included adapter are made
through `Base.invokelatest`. The adapter source, generator, graph, cases, SNR
grid, candidate objective, initialization, 30-update recurrence, readout,
scoring rules, and BP comparator remain unchanged.

## Prospective replay rule

After source-only tests pass, mint a new coarse activation with the repaired
scorer hash and rerun the complete packet, candidate, and scorer sequence into
new artifact roots. Do not select or omit a case.

Before the repaired scorer may open truth or BP, the replay must satisfy:

- LLR binary SHA-256 equals
  `b20d3fc0912f2145a9fd967aa8419d9d3d8f512ee8bf2fccebd12cbbed49f84f`;
- case-index SHA-256 equals
  `161381790117fc2cb14b7b1db6f6733b7f3b31ac3503df66d289e917e7ba7c1e`;
- candidate scientific trace SHA-256 equals
  `a181af8be06fd8a059d2943ea3e92085da3b12e4be79cf93f42660000ca0dda8`;
- candidate cases CSV SHA-256 equals
  `532db38a44efdae9a8ebc284d16a342dd4b22eb67c97894a7e515accbecd1def`;
- candidate trace CSV SHA-256 equals
  `b503a3a9bd74a5d6020cce21d480d44b8861cd7c83c35c04c31ab497c4f6e7cc`.

Packet and candidate manifests are expected to change because their activation
binding changes. Any scientific-identity mismatch stops the repair before
scoring. Passing this remediation is infrastructure evidence only; recovery
counts retain the interpretation of the original threshold card.
