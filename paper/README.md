# Projected-gradient landscape paper

The standalone source is
[`jc_landscape_and_parity_polytope.tex`](jc_landscape_and_parity_polytope.tex).
It is a scoped explanatory synthesis, not a new decoder or performance result.
The retained compiled artifact is
[`jc_landscape_and_parity_polytope.pdf`](jc_landscape_and_parity_polytope.pdf).

Build from this directory with:

```bash
latexmk -xelatex -interaction=nonstopmode -halt-on-error \
  jc_landscape_and_parity_polytope.tex
```

The build uses `biber` through `latexmk` and writes
`jc_landscape_and_parity_polytope.pdf` in this directory.
