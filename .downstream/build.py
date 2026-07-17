#!/usr/bin/env python3
import dataclasses
import json
import os
import time
from argparse import ArgumentParser
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from downstream.updater import Updater
from downstream.util import Subrepo, run


@dataclass(frozen=True)
class Phase:
    success: bool | None = None  # None == skipped
    duration: float | None = None


def fprint(*args, **kwargs) -> None:
    print(*args, **kwargs, flush=True)


def check_cmd(subrepo: Subrepo, command: str) -> bool:
    result = run("lake", f"check-{command}", cwd=subrepo.path, check=False)
    return result.returncode == 0


def run_cmd(subrepo: Subrepo, command: str, *args: str) -> bool | None:
    result = run("lake", command, *args, cwd=subrepo.path, check=False)
    return result.returncode == 0


def print_banner(text: str) -> None:
    fprint("#" * (len(text) + 6))
    fprint(f"## {text} ##")
    fprint("#" * (len(text) + 6))


def do_subrepo(subrepo: Subrepo, command: str, args: list[str] | None = None) -> Phase:
    args = args or []
    fprint(f"::group::{command} {subrepo.name}")
    start = time.time()

    if not check_cmd(subrepo, command):
        success = None
    elif run_cmd(subrepo, command, *args):
        success = True
    else:
        success = False

    end = time.time()
    fprint(f"Took {end - start:.2f}s")
    fprint("::endgroup::")
    return Phase(success=success, duration=end - start)


def do_build(
    subrepos: list[Subrepo],
    report: defaultdict[str, Phase],
    graph: dict[str, set[str]],
    mappings_dir: Path | None,
) -> None:
    print_banner("build")

    for subrepo in subrepos:
        # Only attempt build if all dependencies built
        deps = graph.get(subrepo.name, set())
        failed = {dep for dep in deps if not report[dep].success}
        if failed:
            fprint(f"{subrepo.name}: skipped, no build for {', '.join(sorted(failed))}")
            continue

        args = []
        if mappings_dir is not None:
            args = ["-o", str(mappings_dir / f"{subrepo.name}.jsonl")]

        report[subrepo.name] = do_subrepo(subrepo, "build", args=args)


def do_test(
    subrepos: list[Subrepo],
    report: defaultdict[str, Phase],
    report_build: dict[str, Phase],
) -> None:
    print_banner("test")

    for subrepo in subrepos:
        if not report_build[subrepo.name].success:
            fprint(f"{subrepo.name}: skipped, no build")
            continue

        args = ["--", *subrepo.test_args] if subrepo.test_args else []
        report[subrepo.name] = do_subrepo(subrepo, "test", args=args)


def do_lint(
    subrepos: list[Subrepo],
    report: defaultdict[str, Phase],
    report_build: dict[str, Phase],
) -> None:
    print_banner("lint")

    for subrepo in subrepos:
        if not report_build[subrepo.name].success:
            fprint(f"{subrepo.name}: skipped, no build")
            continue

        args = ["--", *subrepo.lint_args] if subrepo.lint_args else []
        report[subrepo.name] = do_subrepo(subrepo, "lint", args=args)


class Args:
    downstream: Path
    no_build: bool
    test: bool
    lint: bool
    report: Path | None
    mappings: Path | None


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument(
        "-B", "--no-build", action="store_true", help="disable building"
    )
    parser.add_argument("-t", "--test", action="store_true", help="enable testing")
    parser.add_argument("-l", "--lint", action="store_true", help="enable linting")
    parser.add_argument(
        "--report",
        type=Path,
        metavar="PATH",
        help="write a markdown report to PATH",
    )
    parser.add_argument(
        "--mappings",
        type=Path,
        metavar="DIR",
        help="write build mappings to DIR",
    )
    args = parser.parse_args(namespace=Args())

    report_path = None if args.report is None else args.report.resolve()

    mappings_dir = None
    if args.mappings is not None:
        mappings_dir = args.mappings.resolve()
        mappings_dir.mkdir(parents=True, exist_ok=True)

    os.chdir(args.downstream)
    updater = Updater()
    subrepos = updater.topo_subrepos()
    graph = updater.dep_graph()

    commit_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()
    commit_message = run("git", "log", "-1", "--format=%s", capture=True).stdout.strip()

    run("lake", "--version")

    report_build = defaultdict(Phase)
    report_test = defaultdict(Phase)
    report_lint = defaultdict(Phase)
    if not args.no_build:
        do_build(subrepos, report_build, graph, mappings_dir)
    if args.test:
        do_test(subrepos, report_test, report_build)
    if args.lint:
        do_lint(subrepos, report_lint, report_build)

    # A repo is considered green if there are no failures
    green_repos = {
        sub.name
        for sub in subrepos
        if report_build[sub.name].success is not False
        and report_test[sub.name].success is not False
        and report_lint[sub.name].success is not False
    }

    # The report is considered green if all critical repos are green
    critical_repos = {sub.name for sub in subrepos if sub.critical}
    green = critical_repos.issubset(green_repos)

    # Sorted by name, but all critical repos first
    subrepos.sort(key=lambda subrepo: (-subrepo.critical, subrepo.name.lower()))
    report = {
        "commit_sha": commit_sha,
        "commit_message": commit_message,
        "green": green,
        "repos": [
            {
                "name": sub.name,
                "critical": sub.critical,
                "green": sub.name in green_repos,
                "build": dataclasses.asdict(report_build[sub.name]),
                "test": dataclasses.asdict(report_test[sub.name]),
                "lint": dataclasses.asdict(report_lint[sub.name]),
            }
            for sub in subrepos
        ],
    }

    if report_path is not None:
        report_path.write_text(json.dumps(report))


if __name__ == "__main__":
    main()
