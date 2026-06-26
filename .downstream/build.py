import os
from argparse import ArgumentParser
from pathlib import Path

from downstream.updater import Updater
from downstream.util import Subrepo, run

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
    report: list[str],
    command: str,
    mappings_dir: Path | None = None,
) -> bool:
    report.append("")
    report.append(f"## `lake {command}`")
    critical_failed = False

    for subrepo in subrepos:
        # https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#grouping-log-lines
        print(f"::group::{command} {subrepo.name}", flush=True)

        args: list[str] = []
        if mappings_dir is not None:
            args += ["-o", str(mappings_dir / f"{subrepo.name}.jsonl")]

        noncritical = "" if subrepo.critical else " (non-critical)"
        if not check_cmd(subrepo, command):
            report.append(f"- {SKIPPED} {subrepo.name}{noncritical}")
            continue
        if run_cmd(subrepo, command, *args):
            report.append(f"- {SUCCESS} {subrepo.name}{noncritical}")
        else:
            report.append(f"- {FAILURE} {subrepo.name}{noncritical}")
            critical_failed |= subrepo.critical

        print("::endgroup::", flush=True)

    return critical_failed


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

    report = ["# Build report"]
    critical_failed = False

    if not args.no_build:
        critical_failed |= do_phase(subrepos, report, "build", mappings_dir)
    if args.test:
        critical_failed |= do_phase(subrepos, report, "test")
    if args.lint:
        critical_failed |= do_phase(subrepos, report, "lint")

    if report_path is not None:
        report_path.write_text("\n".join(report) + "\n")

    if critical_failed:
        raise SystemExit("At least one critical repo failed.")


if __name__ == "__main__":
    main()
