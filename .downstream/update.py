import os
from argparse import ArgumentParser
from pathlib import Path

from util import Repo


class Args:
    downstream: Path
    prune: bool
    update: list[str]
    update_all: bool
    reset: list[str]
    reset_all: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("-p", "--prune", action="store_true")
    parser.add_argument("-u", "--update", action="append", default=[], metavar="REPO")
    parser.add_argument("-U", "--update-all", action="store_true")
    parser.add_argument("-r", "--reset", action="append", default=[], metavar="REPO")
    parser.add_argument("-R", "--reset-all", action="store_true")
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Repo()

    reset_names = set(args.reset)
    if args.reset_all:
        reset_names = {repo.name for repo in updater.subrepos}

    update_names = set(args.update)
    if args.update_all:
        update_names = {repo.name for repo in updater.subrepos}

    update_names -= reset_names

    update_repos = [updater.subrepos_by_name[name] for name in sorted(update_names)]
    reset_repos = [updater.subrepos_by_name[name] for name in sorted(reset_names)]

    if args.prune:
        updater.prune_subrepos()
    for subrepo in update_repos:
        updater.add_or_update_subrepo(subrepo)
    for subrepo in reset_repos:
        updater.reset_subrepo(subrepo)


if __name__ == "__main__":
    main()
