# Lean 4 downstream repository

This repository is a tool for Lean developers to detect and fix breakage in
certain Lean packages caused by backwards-incompatible changes to Lean.

## How does it work?

This repository contains local copies of a hand-picked collection of Lean
packages. These copies are set up in such a way that they all use the same
toolchain, and their dependencies point to the local copies instead of the
original repos. This makes it easy to create and test changes across multiple
Lean packages at once. Essentially, you get the benefits of a monorepo without
forcing the individual packages to move to a monorepo.

This repo's `master` branch toolchain follows Lean's nightly releases, which are
created once a day off Lean's `master` branch. It is updated automatically by
CI.

A local copy of a Lean package follows a specific branch in the package's repo.
CI regularly merges any new changes from that branch into this repo's `master`
branch, resolving merge conflicts in favor of the original repo. Changes to the
local copy can be extracted into a branch based off of the original repo,
allowing them to either be pushed directly or PRed back into the original repo.

CI builds commits on `master` as well as in pull requests. If any of the
`lake build`, `lake test`, or `lake lint` steps of a Lake package marked as
"critical" in `repos.toml` fails, CI for that commit is red. If only noncritical
packages fail, CI for that commit is green. To view the CI build results in
detail, navigate to the "Build subrepos" job, and then click on the "Summary"
button to get to the "Build subrepos" workflow summary.

Regardless of whether CI is green or red, the build results are uploaded into a
public artifact cache. To download cached artifacts, execute the
`.meta/get-cache.sh` script.

For every toolchain, a branch `green-nightly-YYYY-MM-DD` points to the latest
green commit on `master` using said toolchain. In addition, the branch `green`
points to the latest green commit on `master` regardless of toolchain. In the
Lean repository, a corresponding branch `downstream-green` points to the commit
the toolchain used by `green` is based on.

It is recommended to set the following environment variables while working in
this repository to benefit from cross-project caching:

- `LAKE_ARTIFACT_CACHE=1` to enable global lake artifact caching.
- `LAKE_RESTORE_ARTIFACTS=1` to force lake to populate the `.lake` directories
  with artifacts from the global cache. Some repositories don't support the
  global artifact cache yet and may fail to build, test, or lint without this.

## I'm a Lean developer and want to use this repo.

If you suspect or know that a Lean PR will break downstream packages, tag the PR
with the label https://github.com/leanprover/lean4/labels/downstream. This will
cause CI to create an **adaptation PR** in this repository corresponding to your
Lean PR. You may need to modify your PR before the adaptation PR can be created;
the bot will tell you what to do.

The adaptation PR will have its toolchain automatically updated to the Lean PR's
latest successful CI run. In here, you can fix any packages that your original
PR breaks, or try out new features you added in your PR.

If you have a long-running PR, don't update it by merging `master`. Instead,
merge the `downstream-green` branch into your Lean PR, and at the same time,
merge the `green` branch into your adaptation PR. This way, your PR should not
break due to unrelated breakages from other PRs.

Once the original Lean PR is merged and has made its way into the nightly
release used by this repo's `master` branch, the adaptation PR will also be
automatically merged. If this is not possible due to merge conflicts, the bot
will yell at you to merge the adaptation PR manually.

## I'm a maintainer of a Lean package featured in this repo.

There are multiple ways you can receive fixes from this repository.

If your repo has **no nightly branch** and is **not part of the release
process**, then we can open a PR to your main branch whenever a new release of
Lean is published. This PR will contain all the changes made in this repository.

If your repo has **no nightly branch** and **is part of the release process**,
then the changes from this repository will be included in the toolchain bump PR.

If your repo **has a nightly branch**, you can either receive the changes as
pushes directly to the nightly branch, or as PRs against the nightly branch.
Note that your nightly branch needs to be actively maintained: It needs to pull
in changes from your repo's main branch and update its toolchain in regular
intervals. Our automated pushes or PRs won't replace these tasks.

Note that this "nightly branch" could be version-specific, e.g.
`nightly-v4.32.0` or `bump-v4.32.0`. The only requirement is that it is kept
up-to-date, else our copy of your repo will receive no updates either.

If you have any questions or concerns, please open an issue or contact Joscha
Mennicken on the [community zulip](https://leanprover.zulipchat.com/).
