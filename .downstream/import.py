#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater


class Args:
    downstream: Path
    subrepo: str
    repo: str
    rev: str
    ssh: bool


def main() -> None:
    parser = ArgumentParser(
        description="Replace a subrepo with the contents of an arbitrary repo and rev, "
        "like `update.py --reset`, but without recording a new base commit."
    )
    parser.add_argument("downstream", type=Path)
    parser.add_argument("subrepo", type=str)
    parser.add_argument(
        "repo",
        type=str,
        metavar="OWNER/REPO",
        help="GitHub repo to import from, given by its full name",
    )
    parser.add_argument("rev", type=str, help="branch, tag or sha to import")
    parser.add_argument(
        "-s",
        "--ssh",
        action="store_true",
        help="fetch using SSH instead of HTTPS",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()
    subrepo = updater.subrepos_by_name[args.subrepo]

    prefix = "git@github.com:" if args.ssh else "https://github.com/"
    url = f"{prefix}{args.repo}.git"
    source = f"{args.repo} {args.rev!r}"

    updater.import_subrepo(subrepo, url, args.rev, source=source)


if __name__ == "__main__":
    main()
