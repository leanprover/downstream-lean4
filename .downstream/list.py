#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater


def add_transitive_deps(mask: set[str], graph: dict[str, set[str]], name: str) -> None:
    mask.add(name)
    for dep in graph.get(name, set()):
        add_transitive_deps(mask, graph, dep)


class Args:
    downstream: Path
    topo: bool
    deps: bool
    repo: list[str]


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument(
        "-t",
        "--topo",
        action="store_true",
        help="topologically sort by dependencies",
    )
    parser.add_argument(
        "-d",
        "--deps",
        action="store_true",
        help="transitively include dependencies of filtered repos as well",
    )
    parser.add_argument(
        "repo",
        nargs="*",
        help="filter by repo name",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()

    all_subrepos = [s.name for s in updater.subrepos]
    if args.topo:
        all_subrepos = [s.name for s in updater.topo_subrepos()]

    mask = set(all_subrepos)
    if args.repo:
        mask = set(args.repo)
    if args.deps:
        graph = updater.dep_graph()
        for name in list(mask):  # Don't iterate over set while modifying it
            add_transitive_deps(mask, graph, name)

    for name in all_subrepos:
        if name in mask:
            print(name)


if __name__ == "__main__":
    main()
