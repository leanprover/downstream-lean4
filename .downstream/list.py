#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater


class Args:
    downstream: Path
    topo: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument(
        "-t",
        "--topo",
        action="store_true",
        help="topologically sort by dependencies",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()

    subrepos = updater.subrepos
    if args.topo:
        subrepos = updater.topo_subrepos()

    for subrepo in subrepos:
        print(subrepo.name)


if __name__ == "__main__":
    main()
