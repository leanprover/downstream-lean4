# Lean 4 downstream monorepo

A "downstream" monorepo of lake packages from GitHub, managed using
[downstream](https://github.com/leanprover/downstream). They all use the same
toolchain, and their dependencies point to each other instead of the original
repos.

It is recommended to set the environment variable `LAKE_ARTIFACT_CACHE=1` while
working in this repository to benefit from cross-project caching.
