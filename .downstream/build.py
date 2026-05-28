import json
import os
from argparse import ArgumentParser
from graphlib import TopologicalSorter
from pathlib import Path

from downstream.updater import Updater
from downstream.util import Subrepo, normalize_url, run

SKIPPED = "⏭️"
SUCCESS = "✅"
FAILURE = "🟥"


def topo_subrepos(updater: Updater) -> list[Subrepo]:
    graph: dict[str, set[str]] = {}
    for subrepo in updater.subrepos:
        deps: set[str] = set()
        manifest = json.loads(subrepo.manifest_path.read_text())
        for package in manifest["packages"]:
            if package["type"] != "git":
                continue
            url = normalize_url(package["url"])
            if dep := updater.subrepos_by_url.get(url):
                deps.add(dep.name)
        graph[subrepo.name] = deps

    order = TopologicalSorter(graph).static_order()
    return [updater.subrepos_by_name[name] for name in order]


def check_cmd(subrepo: Subrepo, command: str) -> bool:
    result = run("lake", f"check-{command}", cwd=subrepo.path, check=False)
    return result.returncode == 0


def run_cmd(subrepo: Subrepo, command: str) -> bool | None:
    result = run("lake", command, cwd=subrepo.path, check=False)
    return result.returncode == 0


def do_phase(subrepos: list[Subrepo], report: list[str], command: str) -> None:
    print()
    print(f"## {command}")
    report.append("")
    report.append(f"## `lake {command}`")

    for subrepo in subrepos:
        if not check_cmd(subrepo, command):
            report.append(f"- {SKIPPED} {subrepo.name}")
            continue
        if run_cmd(subrepo, command):
            report.append(f"- {SUCCESS} {subrepo.name}")
        else:
            report.append(f"- {FAILURE} {subrepo.name}")


class Args:
    downstream: Path
    no_build: bool
    test: bool
    lint: bool
    report: Path | None


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument(
        "-B", "--no-build", action="store_true", help="disable building"
    )
    parser.add_argument("-t", "--test", action="store_true", help="enable testing")
    parser.add_argument("-l", "--lint", action="store_true", help="enable linting")
    parser.add_argument("--report", type=Path, help="write a markdown report to PATH")
    args = parser.parse_args(namespace=Args())

    report_path = None if args.report is None else args.report.resolve()

    os.chdir(args.downstream)
    updater = Updater()
    subrepos = topo_subrepos(updater)

    report = ["# Build report"]
    if not args.no_build:
        do_phase(subrepos, report, "build")
    if args.test:
        do_phase(subrepos, report, "test")
    if args.lint:
        do_phase(subrepos, report, "lint")

    if report_path is not None:
        report_path.write_text("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
