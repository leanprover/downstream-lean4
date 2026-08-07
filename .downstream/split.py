#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater
from downstream.util import fprint, run

EXIT_EMPTY = 10
EXIT_REBASE_FAILED = 11


class Args:
    downstream: Path
    subrepo: str
    push: str | None
    branch: str
    ssh: bool
    message: str
    rebase: bool
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
        "-r",
        "--rebase",
        action="store_true",
        help="try to rebase onto the latest commit of the subrepo's source branch",
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

    if args.rebase:
        status = updater.update_subrepo(subrepo)
        if not status.empty:
            fprint("Failed to rebase the changes.")
            raise SystemExit(EXIT_REBASE_FAILED)

    committed = updater.split(subrepo, args.message)

    if args.push:
        prefix = "git@github.com:" if args.ssh else "https://github.com/"
        url = f"{prefix}{args.push}.git"
        run("git", "push", url, f"HEAD:{args.branch}")

    if args.fail_if_empty and committed.empty:
        raise SystemExit(EXIT_EMPTY)


if __name__ == "__main__":
    main()
