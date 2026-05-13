import os
from argparse import ArgumentParser
from pathlib import Path

from util import Repo


class Args:
    downstream: Path
    subrepo: str
    branch: str


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("subrepo", type=str)
    parser.add_argument("branch", type=str)
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Repo()

    subrepo = updater.subrepos_by_name[args.subrepo]
    updater.split_to_branch(subrepo, args.branch)


if __name__ == "__main__":
    main()
