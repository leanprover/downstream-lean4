import os
from argparse import ArgumentParser
from enum import StrEnum
from pathlib import Path

from downstream.updater import Updater
from downstream.util import Subrepo, run


class Status(StrEnum):
    SKIPPED = "⏭️"
    SUCCESS = "✅"
    FAILURE = "🟥"


def check_cmd(subrepo: Subrepo, command: str) -> bool:
    result = run("lake", f"check-{command}", cwd=subrepo.path, check=False)
    return result.returncode == 0


def run_cmd(subrepo: Subrepo, command: str, *args: str) -> bool | None:
    result = run("lake", command, *args, cwd=subrepo.path, check=False)
    return result.returncode == 0


def do_phase(
    subrepos: list[Subrepo],
    command: str,
    mappings_dir: Path | None = None,
) -> dict[str, Status]:
    report = {}

    print("#" * (len(command) + 4), flush=True)
    print(f"# {command} #", flush=True)
    print("#" * (len(command) + 4), flush=True)
    for subrepo in subrepos:
        # https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#grouping-log-lines
        print(f"::group::{command} {subrepo.name}", flush=True)

        args: list[str] = []
        if mappings_dir is not None:
            args += ["-o", str(mappings_dir / f"{subrepo.name}.jsonl")]

        if not check_cmd(subrepo, command):
            report[subrepo.name] = Status.SKIPPED
            continue
        if run_cmd(subrepo, command, *args):
            report[subrepo.name] = Status.SUCCESS
        else:
            report[subrepo.name] = Status.FAILURE

        print("::endgroup::", flush=True)

    return report


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

    run("lake", "--version")

    report_build = {}
    if not args.no_build:
        report_build = do_phase(subrepos, "build", mappings_dir)

    report_test = {}
    if args.test:
        report_test = do_phase(subrepos, "test")

    report_lint = {}
    if args.lint:
        report_lint = do_phase(subrepos, "lint")

    # Sorted by name, but all critical repos first
    subrepos.sort(key=lambda subrepo: (-subrepo.critical, subrepo.name))

    report = []
    report.append("# Build Report")
    report.append("")
    report.append("| Repo | Critical | Build | Test | Lint |")
    report.append("|------|----------|-------|------|------|")
    for subrepo in subrepos:
        name = subrepo.name
        critical = "✅" if subrepo.critical else ""
        build = report_build.get(subrepo.name, Status.SKIPPED)
        test = report_test.get(subrepo.name, Status.SKIPPED)
        lint = report_lint.get(subrepo.name, Status.SKIPPED)
        report.append(f"| {name} | {critical} | {build} | {test} | {lint} |")

    if report_path is not None:
        report_path.write_text("\n".join(report) + "\n")

    critical_failed = False
    for subrepo in subrepos:
        if not subrepo.critical:
            continue
        if report_build.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            print(f"Critical repo {subrepo.name} failed to build.", flush=True)
        if report_test.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            print(f"Critical repo {subrepo.name} failed to test.", flush=True)
        if report_lint.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            print(f"Critical repo {subrepo.name} failed to lint.", flush=True)

    if critical_failed:
        raise SystemExit("At least one critical repo failed.")


if __name__ == "__main__":
    main()
