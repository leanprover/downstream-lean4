# hex-basic

The lowest-level Mathlib-free helper library for the `hex` project: small,
general-purpose lemmas and utilities that clearly belong in the Lean standard
library and are reproduced here only until they migrate upstream.

It currently provides the shared `List.foldl` algebra (`HexBasic.Fold`), the
`Batteries` list-lemma reproductions (`HexBasic.ListShim`), and the
`Vector.modify` update helper. Depends only on the Lean toolchain's `Std`.

Developed in the [`hex-dev`](https://github.com/kim-em/hex-dev) monorepo and
published here by its release sync; do not edit directly.
