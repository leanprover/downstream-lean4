# Lean 4 downstream monorepo

A "downstream" monorepo of lake packages from GitHub, managed using
[downstream](https://github.com/leanprover/downstream). They all use the same
toolchain, and their dependencies point to each other instead of the original
repos.

It is recommended to set the following environment variables while working in
this repository to benefit from cross-project caching:

- `LAKE_ARTIFACT_CACHE=1` to enable global lake artifact caching.
- `LAKE_RESTORE_ARTIFACTS=1` to force lake to populate the `.lake` directories
  with artifacts from the global cache. Some repositories don't support the
  global artifact cache yet and may fail to build, test, or lint without this.

## Branches

Inside this repository, the following branches exist:

- `master`: Follows lean4 nightly releases. Both the toolchain and the subrepos
  are kept up-to-date by CI.
- `green-nightly-YYYY-MM-DD`: For every nightly release, a branch of this form
  points to the latest commit with green CI on `master` using this release.
- `green`: Points to the latest commit with green CI on `master`.

In the [Lean 4 repository](https://github.com/leanprover/lean4), the following
branch exists:

- `downstream-green`: Points to the latest commit tagged with
  `nightly-YYYY-MM-DD` for which this repository has a commit with green CI.
