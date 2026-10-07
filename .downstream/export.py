#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater
from downstream.util import run

EXIT_EMPTY = 10


class Args:
    downstream: Path
    subrepo: str
    push: str | None
    branch: str
    ssh: bool
    message: str
    onto: str | None
    update_toolchains: bool
    edit_lakefile: list[list[str]] | None
    update_manifests: bool
    fail_if_empty: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("subrepo", type=str)
    parser.add_argument(
        "-p",
        "--push",
        type=str,
        metavar="OWNER/REPO",
        help="push the changes to this GitHub repo, given by its full name",
    )
    parser.add_argument(
        "-b",
        "--branch",
        type=str,
        default="downstream-export",
        help="branch to push to (requires --push)",
    )
    parser.add_argument(
        "-s",
        "--ssh",
        action="store_true",
        help="push using SSH instead of HTTPS (requires --push)",
    )
    parser.add_argument(
        "-m",
        "--message",
        type=str,
        default="chore: nightly adaptations",
        help="commit message for the changes",
    )
    parser.add_argument(
        "-o",
        "--onto",
        type=str,
        metavar="SHA",
        help="create the export commit on top of this commit instead of the base commit (must be available locally)",
    )
    parser.add_argument(
        "-t",
        "--update-toolchains",
        action="store_true",
        help="set lean-toolchain files to the downstream toolchain used at time of export",
    )
    parser.add_argument(
        "-e",
        "--edit-lakefile",
        nargs=2,
        action="append",
        metavar=("PATTERN", "REPLACEMENT"),
        help="""
        replace a regex in all lakefiles (can be given multiple times).
        '<REPO sha>' in the replacement is replaced by REPO's last known sha
        """,
    )
    parser.add_argument(
        "-u",
        "--update-manifests",
        action="store_true",
        help="run `lake update` for every manifest",
    )
    parser.add_argument(
        "-E",
        "--fail-if-empty",
        action="store_true",
        help="exit with a nonzero exit code if there were no adaptations to commit",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()
    subrepo = updater.subrepos_by_name[args.subrepo]

    run("git", "switch", "--detach", "HEAD")

    committed = updater.export(
        subrepo,
        args.message,
        onto=args.onto,
        update_toolchains=args.update_toolchains,
        lakefile_edits=[(p, r) for p, r in args.edit_lakefile or []],
        update_manifests=args.update_manifests,
    )

    if args.push:
        prefix = "git@github.com:" if args.ssh else "https://github.com/"
        url = f"{prefix}{args.push}.git"
        run("git", "push", url, f"HEAD:{args.branch}")

    if args.fail_if_empty and committed.empty:
        raise SystemExit(EXIT_EMPTY)


if __name__ == "__main__":
    main()
