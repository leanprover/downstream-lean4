#!/usr/bin/env python3
import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater


def transitive_deps(graph: dict[str, set[str]], name: str) -> set[str]:
    result: set[str] = set()
    for dep in graph.get(name, set()):
        result.add(dep)
        result |= transitive_deps(graph, dep)
    return result


def indirect_deps(graph: dict[str, set[str]], name: str) -> set[str]:
    result: set[str] = set()
    for dep in graph.get(name, set()):
        result |= transitive_deps(graph, dep)
    return result


def attrs_str(**kwargs: str) -> str:
    if not kwargs:
        return ""
    return " [" + " ".join(f"{k}=<{v}>" for k, v in kwargs.items()) + "]"


class Args:
    downstream: Path
    prune: bool
    external: bool


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument(
        "-p",
        "--prune",
        action="store_true",
        help="omit edges already implied transitively",
    )
    parser.add_argument(
        "-e",
        "--external",
        action="store_true",
        help="also graph dependencies not listed in repos.toml",
    )
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    updater = Updater()
    graph = updater.dep_graph(external=args.external)

    external = {
        dep
        for deps in graph.values()
        for dep in deps
        if dep not in updater.subrepos_by_name
    }

    print("digraph G {")
    print("  rankdir=LR;")
    for subrepo in sorted(updater.subrepos, key=lambda r: r.name):
        indirect = indirect_deps(graph, subrepo.name) if args.prune else set()

        label = f'{subrepo.name}<BR/><FONT POINT-SIZE="8">{subrepo.rev}</FONT>'
        attrs = {"label": label}
        if subrepo.critical:
            attrs["style"] = "filled"
            attrs["color"] = "pink"
        print(f'  "{subrepo.name}"{attrs_str(**attrs)};')

        for dep in sorted(graph[subrepo.name]):
            comment = "// " if dep in indirect else ""
            print(f'  {comment}"{dep}" -> "{subrepo.name}";')

    for name in sorted(external):
        attrs = {"label": name, "style": "dashed", "color": "gray", "fontcolor": "gray"}
        print(f'  "{name}"{attrs_str(**attrs)};')

    print("}")


if __name__ == "__main__":
    main()
