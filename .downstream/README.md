# Downstream scripts

Scripts to maintain a "downstream" monorepo of lake packages. They all use the
same toolchain, and their dependencies point to each other instead of the
original repos.

Instead of `git subtree`, these scripts use a custom approach that's tailored to
this exact situation. This is in an effort to make the developer experience as
smooth as possible and not require external tools like `direnv` or runinng
scripts manually that can easily be forgotten.

## Getting started

These scripts are meant to be added to the monorepo in question using
`git subtree` using the command

```bash
git subtree add -P .downstream https://github.com/leanprover/downstream master -m "chore: add downstream"
```

and updated occasionally using the command

```bash
git subtree pull -P .downstream https://github.com/leanprover/downstream master -m "chore: update downstream"
```

To use one of the scripts, execute it with the first argument pointing to the
monorepo, e.g.

```bash
python .downstream/update.py . -pU
```

## Basic structure

A monorepo contains two special files at its root:

- `lean-toolchain` specifying the toolchain to be used repo-wide
- `repos.toml` listing the repos that should be part of the monorepo

In addition, the lake packages are embedded in subdirectories named via
`repos.toml`. Their full histories are **not** included, so as to keep the
monorepo small and to avoid GitHub from registering duplicate mentions on PRs or
issues mentioned by URL.

## Toolchains

In order for each package to use the repo-wide toolchain, any file called
`lean-toolchain` is replaced by a symlink to the `lean-toolchain` file in the
monorepo root.

When a PR branch is split off for a specific package, the `lean-toolchain` files
are restored to their last known state. If the PR requires changes to the
`lean-toolchain` files, they will have to be made manually after the branch is
split off.

## Dependencies

The original `lake-manifest.json` files of packages are not modified. Instead,
`package-overrides.json` files are added to the repository inside each repo's
normally-untracked `.lake` directories. Inside the override files, relative
paths to other repos inside the monorepo are provided, overriding the
corresponding package definitions in the manifest.

When a PR branch is split off for a specific package, the `.lake` directory
contents are ignored. The `lake-manifest.json` file inside the branch will
contain changes made to it inside the monorepo.
