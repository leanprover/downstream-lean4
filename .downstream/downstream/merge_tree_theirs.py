#!/usr/bin/env python3
"""
Merge three trees like

    git merge-tree --write-tree -Xtheirs --merge-base=<base> <ours> <theirs>

but additionally resolve *every* remaining conflict in favour of theirs.

`-Xtheirs` only settles the textual hunks of three-way content merges. Anything
structural (file/directory clashes, modify/delete, add/add of binaries, rename
tangles, ...) is left conflicted in the tree merge-tree produces. This script
takes merge-tree's result and, for each path git still reports as conflicted,
overwrites that location with whatever theirs holds there: a blob, a subtree, or
nothing at all.
"""

import os
import sys
import tempfile

from downstream.util import run


def parse_merge_output(output: str) -> tuple[str, list[str]]:
    """Split `merge-tree -z` output into (tree oid, conflicted paths)."""
    fields = output.split("\0")
    tree = fields[0].strip()

    # The "Conflicted file info" records follow the tree oid and run until the
    # empty field that begins the informational-messages section.
    paths: list[str] = []
    for record in fields[1:]:
        if record == "":
            break
        # "<mode> <object> <stage>\t<path>"; a path may recur at several stages.
        _meta, _, path = record.partition("\t")
        if path not in paths:
            paths.append(path)
    return tree, paths


def real_path(path: str, ours: str, theirs: str) -> str:
    """Undo the `<name>~<branch>` rename merge-tree uses to dodge file/dir
    clashes, recovering the path theirs actually cares about. We pass <ours> and
    <theirs> as the branch names, so those are the only possible suffixes."""
    for branch in (ours, theirs):
        suffix = f"~{branch}"
        if path.endswith(suffix) and len(path) > len(suffix):
            return path[: -len(suffix)]
    return path


def merge_tree_theirs(base: str, ours: str, theirs: str) -> str:
    merged = run(
        *("git", "merge-tree", "--write-tree", "-z", "-Xtheirs"),
        *(f"--merge-base={base}", ours, theirs),
        check=False,
        capture=True,
    )
    if merged.returncode == 0:
        return merged.stdout.split("\0", 1)[0].strip()  # clean merge
    if merged.returncode != 1:
        sys.stderr.write(merged.stderr)
        raise SystemExit(f"git merge-tree failed with status {merged.returncode}")

    tree, paths = parse_merge_output(merged.stdout)

    # Patch the conflicts in a throwaway index so the real one is left untouched.
    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "index")}
        run("git", "read-tree", tree, env=env)

        for path in paths:
            real = real_path(path, ours, theirs)

            # Clear merge-tree's leftovers at this location: the conflicted
            # entry, the file renamed out of the way, and any directory now
            # sitting where theirs wants a file (or vice versa).
            run("git", "rm", "-rf", "--cached", "--ignore-unmatch", "--", path, env=env)
            run("git", "rm", "-rf", "--cached", "--ignore-unmatch", "--", real, env=env)

            # Reinstate exactly what theirs holds there.
            entry = run(
                *("git", "ls-tree", "-z", theirs, "--", real),
                capture=True,
                env=env,
            ).stdout
            if not entry:
                continue  # theirs has nothing here -> stay deleted
            meta, _, _name = entry.rstrip("\0").partition("\t")
            mode, kind, oid = meta.split(" ")
            if kind == "tree":
                run("git", "read-tree", f"--prefix={real}/", oid, env=env)
            else:  # blob or commit (submodule)
                run(
                    *("git", "update-index", "--add"),
                    *("--cacheinfo", f"{mode},{oid},{real}"),
                    env=env,
                )

        return run("git", "write-tree", capture=True, env=env).stdout.strip()
