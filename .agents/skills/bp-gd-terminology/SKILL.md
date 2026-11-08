---
name: bp-gd-terminology
description: Audit reader-visible terminology for BP and gradient-based decoding in this repository. Use when editing HTML, TeX, captions, labels, tables, reports, or explanations. Do not use for code identifiers or styling-only changes.
---

# BP and gradient-decoder terminology

- BP retains directed variable-to-check and check-to-variable messages. Call a
  completed round a message-passing iteration.
- A projected gradient decoder computes partial derivatives of its declared
  objective function, applies its stated direction and step rule, and projects
  onto its stated set. Do not call this message passing.
- Describe the ordinary GD state as `one scalar per bit`, or as `x_i for bit
  i`. Do not use `bit-indexed relaxed values` in reader-visible text.
- A check-specific offset, derivative contribution, or matrix coupling is not
  a BP message unless the algorithm actually retains and updates it as such.
- Direct application of a recurrence is a fixed-point update, not a gradient
  step merely because the recurrence can be compared with a gradient.
- Use `hard-decision estimate` for a thresholded state. Reserve `codeword` for
  a binary vector satisfying every parity check.
- Distinguish parity validity, transmitted-word recovery, coded-bit BER, and
  frame or word recovery.

State exactly what a comparison holds fixed: for example, the parity-check
matrix, transmitted word, noise realization, and vector of channel LLRs. A
shared Tanner graph does not imply a shared state, calculation, update, memory
cost, or objective.

Do not introduce a new decoder name or acronym without user approval. Do not
call an unvalidated coefficient or direction fit a decoder, and do not call a
single-SNR result BP-like performance across SNR.

Before finalizing reader-visible changes, search for ambiguous wording:

```bash
rg -n -i 'bit-indexed|gradient messages?|edge transfers?|same inputs|matched inputs|identical inputs|near[- ]BP|BP-like' FILE...
```

Review every match in context; equations, literal identifiers, and explicit
scope qualifications may be legitimate.
