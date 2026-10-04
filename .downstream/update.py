#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater


class Args:
    downstream: Path
    prune: bool
    fixup: list[str]
    fixup_all: bool
    update: list[str]
    update_all: bool
    update_to: list[list[str]]
    reset: list[str]
    reset_all: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("-p", "--prune", action="store_true")
    parser.add_argument("-f", "--fixup", action="append", default=[], metavar="REPO")
    parser.add_argument("-F", "--fixup-all", action="store_true")
    parser.add_argument("-u", "--update", action="append", default=[], metavar="REPO")
    parser.add_argument("-U", "--update-all", action="store_true")
    parser.add_argument(
        "--update-to", nargs=2, action="append", default=[], metavar=("REPO", "SHA")
    )
    parser.add_argument("-r", "--reset", action="append", default=[], metavar="REPO")
    parser.add_argument("-R", "--reset-all", action="store_true")
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()

    reset_names = set(args.reset)
    if args.reset_all:
        reset_names = {repo.name for repo in updater.subrepos}

    update_shas = {name: sha for name, sha in args.update_to}
    update_names = set(args.update)
    if args.update_all:
        update_names = {repo.name for repo in updater.subrepos}

    fixup_names = set(args.fixup)
    if args.fixup_all:
        fixup_names = {repo.name for repo in updater.subrepos}

    update_names -= reset_names
    fixup_names -= update_names | reset_names

    update_repos = [updater.subrepos_by_name[name] for name in sorted(update_names)]
    reset_repos = [updater.subrepos_by_name[name] for name in sorted(reset_names)]
    fixup_repos = [updater.subrepos_by_name[name] for name in sorted(fixup_names)]

    updater.reset()
    if args.prune:
        updater.prune_subrepos()
    for subrepo in fixup_repos:
        updater.add_or_fixup_subrepo(subrepo)
    for subrepo in update_repos:
        updater.add_or_update_subrepo(subrepo, update_shas.get(subrepo.name))
    for subrepo in reset_repos:
        updater.add_or_reset_subrepo(subrepo)


if __name__ == "__main__":
    main()
