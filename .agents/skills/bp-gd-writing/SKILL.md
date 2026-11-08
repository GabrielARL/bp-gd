---
name: bp-gd-writing
description: Write or revise reader-visible BP–GD explanations in this repository. Use for notes, animations, slides, captions, reports, and research summaries. Present the mechanism before the performance consequence and keep verified results separate from active hypotheses.
---

# Mechanism-first BP–GD writing

Apply `bp-gd-terminology` whenever technical wording changes.

Use this order:

1. state the graph, channel evidence, cases, and work limits;
2. explain what each method retains;
3. show how one check acts on that state;
4. identify the first controlled operation that changes;
5. report the registered diagnostic or recovery effect; and
6. end with the bounded consequence and what remains untested.

Do not infer a causal mechanism from a native BP-versus-GD score alone. Do not
turn a local existence proof, retained fit, or successful direction screen into
a decoding claim. When a branch is pruned, state the exact family and gate that
failed rather than claiming that all gradient-based decoders are impossible.

For the current selected implementation, the strongest allowed sentence is:
the compound-box projected-gradient construction recovered 200/200 transmitted
words on the registered fresh 6-dB cases after 90 updates. Immediately state
that this is not a cross-SNR near-BP result.

Keep equations, executable code, tables, captions, visible states, and
narration synchronized. Preserve full precision internally and round only for
display. End with the compared methods, case set, signal-to-noise ratio, work
budget, metric, and denominator.
