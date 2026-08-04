#!/usr/bin/env python3
import os
import sys
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater
from downstream.util import run


class Args:
    downstream: Path
    subrepo: str
    branch: str
    push: str | None
    ssh: bool
    message: str
    fail_if_empty: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("subrepo", type=str)
    parser.add_argument("branch", type=str)
    parser.add_argument(
        "-p",
        "--push",
        type=str,
        metavar="OWNER/REPO",
        help="push the branch to this GitHub repo, given by its full name",
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
        "-E",
        "--fail-if-empty",
        action="store_true",
        help="exit with a nonzero exit code if there were no adaptations to commit",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()

    subrepo = updater.subrepos_by_name[args.subrepo]
    committed = updater.split_to_branch(subrepo, args.branch, args.message)

    if args.push:
        prefix = "git@github.com:" if args.ssh else "https://github.com/"
        url = f"{prefix}{args.push}.git"
        run("git", "push", url, args.branch)

    if args.fail_if_empty and not committed:
        sys.exit(1)


if __name__ == "__main__":
    main()
