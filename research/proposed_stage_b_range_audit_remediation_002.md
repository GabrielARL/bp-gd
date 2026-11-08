# Stage-B range-audit remediation 002

Status: approved and source-only complete on 7 November 2026

Approval ID:
`RQ2-TWO-HOP-POSITIVE-METRIC-001-STAGE-B-RANGE-AUDIT-REMEDIATION-002`

## Why this decision exists

The approved corrected v11 range audit completed its registered repository,
filesystem, and Git-ref scope but failed on two independent gates. The sole
collision was a mutable route-ledger sentence that repeated the interval
already pinned by the immutable campaign registration. That duplicate numeric
phrase has been removed from the mutable ledger without changing the campaign
registration. Independently, the result recorded a coordinator component of
6,140,592 KiB against the unchanged 2,097,152-KiB cap; waited-child and maximum
helper components were 269,780 and 252,660 KiB, with complete 32/32 helper
telemetry.

Targeted read-only checks show that the coordinator field is launch-contaminated,
not a measurement of scanner allocation. A direct no-work Python process in the
same execution shell reports exactly 6,140,592 KiB. The same route-ledger parser
in a freshly spawned child reports 54,668 KiB, and the 8,229,568-byte historical
CSV immediately below the current helper threshold reports 80,024 KiB. Five
other already scanned 4.5--7.3 MB documents report 31,760--74,168 KiB in fresh
children. A controlled 256-MiB allocation followed by `execve` preserves the
269,952-KiB pre-exec peak, confirming the mechanism: Linux lifetime
`ru_maxrss` survives `execve`. The terminal audit remains failed because its
registered field exceeded the cap, but that field cannot show that the scanner
itself used 5.86 GiB.

The process-boundary audit also found that an ordinary Python subprocess is not
a sufficient repair on this host. Python 3.11 reports that its subprocess path
uses `vfork`; after the parent acquired and released a 256-MiB allocation, the
default subprocess repeated a roughly 272-MiB peak. An explicit `fork()` followed
by `execve()` of the pinned interpreter instead started at 8--10 MiB. `execve()`
without the preceding `fork()` retained the old peak. Therefore "fresh worker"
below means an explicit true fork before any corpus read or sizable allocation,
not a renamed subprocess or an exec-only wrapper.

## Approved source-only action

1. Preserve the failed activation, progress, and result artifacts byte for
   byte. Do not create `MANIFEST.sha256` for that failed bundle.
2. Make a minimal launcher verify the exact scanner source and the pinned
   `/usr/bin/python3.11` interpreter, then call `fork()` before any corpus read,
   result parse, repository command, or sizable allocation. The child must use
   `execve()` with isolated `-I -B` execution. Ordinary `subprocess`,
   `posix_spawn`, `vfork`, and exec-only launch paths do not satisfy this gate.
3. Let only that worker perform traversal and result construction. Stabilize its
   `RUSAGE_SELF` value after the complete result has been serialized, and gate
   that final value together with the worker's waited children and document
   helpers. Use the same explicit-fork boundary for formal document helpers.
4. Have the worker write to a parent-retained unnamed inode and return one
   bounded, canonical receipt. After worker exit, the launcher must use
   `wait4()` to verify the final child peak, logical exit, interpreter and source
   identities, receipt, result digest, and result size. Only then may it link the
   result exclusively at the activated output path. A missing, malformed, or
   inconsistent receipt or peak leaves no published formal result.
5. Version the result schema because the process boundary and telemetry
   provenance change, while preserving the exact three-member range bundle.
   Record the parent/inherited peak only as diagnostic provenance in the closed
   worker-exit record. Exclude it from `scan_max_rss_kib`; missing or inconsistent
   worker telemetry must fail closed.
6. Reproduce the launch-contamination mechanism only against the hash-pinned
   terminal failed result and its already embedded four corpus inventories.
   Publish only a non-scientific rehearsal receipt: do not open an activation,
   traverse a live scientific provider, or publish a formal range-audit result.
7. Retain the existing 2,097,152-KiB cap, complete filesystem and Git-blob
   scope, exact collision semantics, frame reservation, source checks, support
   checks, snapshot checks, and dormant-Stage-C checks.
8. Add fail-closed unit and integration regressions in which a parent first
   acquires a peak above a scaled test cap: a clean low-memory worker must report
   its own peak, while a worker that actually exceeds the scaled cap must still
   fail. Also retain a regression for the same-campaign ledger self-reference.
   The production cap remains exactly 2,097,152 KiB; no test needs to allocate
   more than 2 GiB.
9. Publish source-only validation and the non-scientific, no-result rehearsal
   receipt. Stop if the rehearsal exceeds either the RSS or elapsed-time cap.

## Explicitly not authorized

- no formal repository range-audit result;
- no activation or reuse of a consumed activation;
- no registered Stage-B or Stage-C input;
- no retained-wall benchmark, capsule, scientific runner, decoder, recovery
  score, coded-bit BER/FER score, retuning, or performance claim;
- no higher RSS/time cap, skipped file, narrowed root/ref scope, broad path
  exemption, or conversion of a failed result into a pass.

## Acceptance boundary

This remediation is complete only if the source checks and synthetic tests
pass, a true-fork worker resets inherited launch history, its final
`wait4()`-checked process-tree peak equals
`max(worker self, worker waited child)` after result serialization, each
version-3 helper applies the analogous self-versus-waited-child maximum, the
non-scientific rehearsal stays within both registered caps, the four pinned
corpus inventories remain complete, and independent review confirms that
collision admission was not broadened. Completion would permit a new exact
support-source closure proposal. It would not authorize another formal scan;
that later one-use activation requires its own stable ID and approval.

## Completion evidence

The approved repair is implemented at generator SHA-256
`a3e40cc9d31f5853894a5cfff218bf70ab8f20fbccceb0f6565614ff477fa9e0`.
Its test source has SHA-256
`11a39395b546d23c7136fc5639bd0ca79db97e4445af479a30278296c7dec279`
and passes 79/79 synthetic tests. Its independent source validator has SHA-256
`f2d521f1e29d1f686a0eb313015f6e8b7df3209064f8f33541b8f141bc0ce23b`
and passes 13/13 checks.

The repaired accounting follows process boundaries. After complete result
serialization, the final `wait4()`-checked process-tree peak must equal the
maximum of the worker self peak and the worker's waited-child peak, not their
sum. Version-3 document helpers use the same rule: each helper peak is the
maximum of that helper's self and waited-child peaks.
The parent launcher peak remains diagnostic only. The prospective publisher
completes all validation and `fsync` operations before an exclusive link makes
the result visible; that link is the final publication commit. The source does
not claim a separate post-link crash-durability acknowledgement.

The canonical no-result rehearsal receipt has SHA-256
`e2f33286897e7d56c07401274f2c19b865670e8c59c27dd235faa017dc0f494c`
at
`/home/gabiel/Documents/GitHub/sp_gd_admm-runs/rq2-two-hop-positive-metric-001/stage-b-range-audit-remediation-002-no-result-rehearsal-20261107-v1/no_result_rehearsal_receipt.json`.
The inherited parent peak was 6,140,592 KiB and remained diagnostic only. The
worker self peak and independent `wait4()` peak were both 210,828 KiB; its
waited-child and helper peaks were both zero. The resulting process-tree peak
was therefore 210,828 KiB, below the unchanged 2,097,152-KiB cap. Elapsed time
was 6,923 ms, below the 1,800,000-ms cap.

The rehearsal rechecked all four inventories embedded in the pinned failed
result: 15 worktrees at
`ae9a88034cf51d18c1a4dabd82254846a7d86cc436047fe610b2be026cebd23c`,
17 refs at
`66928e038e54b6205be08834e319ece8ab6604361db46fc89e47697cd1664ff5`,
36,319 filesystem entries at
`c638b2037e7b4c58bd3478ee9a4ebe791bc6e43007bafddc934188994d28ffe5`,
and 35,543 Git blobs at
`505dc22cabe794436d2bd089407e78f1f761f2b4bf307f69def5d545d36d8f94`.
It opened no formal activation, traversed no live provider, and published no
formal result. The v11 terminal result remains failed and byte-unchanged at
SHA-256
`10618db46e510ed1c3260f553f8ee72d2ebddaf52b59c0ef7675e043eaa9f5ff`;
its bundle still has no manifest.

This completion is source and process-accounting evidence only. It is not a
formal collision scan, scientific input, decoder run, recovery result, or
performance claim. Activation-002 and closure-002 are consumed and cannot be
reused. The next permitted sequence is to separately review, approve, and
materialize a new source rebind and exact support-source closure, then approve
a new one-use version-12 activation. No new approval ID has been introduced.
