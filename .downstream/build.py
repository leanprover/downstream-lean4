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


def do_subrepo(subrepo: Subrepo, command: str, args: list[str] | None = None) -> Status:
    args = args or []
    fprint(f"::group::{command} {subrepo.name}")

    if not check_cmd(subrepo, command):
        result = Status.SKIPPED
    elif run_cmd(subrepo, command, *args):
        result = Status.SUCCESS
    else:
        result = Status.FAILURE

    fprint("::endgroup::")
    return result


def do_build(
    subrepos: list[Subrepo],
    graph: dict[str, set[str]],
    mappings_dir: Path | None,
) -> dict[str, Status]:
    print_banner("build")
    report = {}

    for subrepo in subrepos:
        deps = graph.get(subrepo.name, set())
        failed = {dep for dep in deps if report.get(dep) != Status.SUCCESS}
        failed_str = ", ".join(sorted(failed))
        if failed:
            fprint(f"{subrepo.name}: skipped, no build for {failed_str}")
            report[subrepo.name] = Status.SKIPPED
            continue

        args = []
        if mappings_dir is not None:
            args = ["-o", str(mappings_dir / f"{subrepo.name}.jsonl")]

        report[subrepo.name] = do_subrepo(subrepo, "build", args=args)

    return report


def do_test(
    subrepos: list[Subrepo],
    graph: dict[str, set[str]],
    build_report: dict[str, Status],
) -> dict[str, Status]:
    print_banner("test")
    report = {}

    for subrepo in subrepos:
        if build_report.get(subrepo.name) != Status.SUCCESS:
            fprint(f"{subrepo.name}: skipped, no build")
            report[subrepo.name] = Status.SKIPPED
            continue

        report[subrepo.name] = do_subrepo(subrepo, "test")

    return report


def do_lint(
    subrepos: list[Subrepo],
    graph: dict[str, set[str]],
    build_report: dict[str, Status],
) -> dict[str, Status]:
    print_banner("lint")
    report = {}

    for subrepo in subrepos:
        if build_report.get(subrepo.name) != Status.SUCCESS:
            fprint(f"{subrepo.name}: skipped, no build")
            report[subrepo.name] = Status.SKIPPED
            continue

        report[subrepo.name] = do_subrepo(subrepo, "lint")

    return report


class Args:
    downstream: Path
    no_build: bool
    test: bool
    lint: bool
    report: Path | None
    mappings: Path | None
    gh_repo: str | None
    gh_run_id: str | None
    gh_run_attempt: str | None


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
    parser.add_argument(
        "--gh-repo",
        metavar="OWNER/NAME",
        help="GitHub repo full name, used in the build report",
    )
    parser.add_argument(
        "--gh-run-id",
        help="GitHub Actions run ID, used to link to the run in the build report",
    )
    parser.add_argument(
        "--gh-run-attempt",
        help="GitHub Actions run attempt, appended to the run link if given",
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

    report_build = {}
    if not args.no_build:
        report_build = do_build(subrepos, graph, mappings_dir)

    report_test = {}
    if args.test:
        report_test = do_test(subrepos, graph, report_build)

    report_lint = {}
    if args.lint:
        report_lint = do_lint(subrepos, graph, report_build)

    # Sorted by name, but all critical repos first
    subrepos.sort(key=lambda subrepo: (-subrepo.critical, subrepo.name))

    report = []
    report.append("# Build Report")
    report.append("")

    if args.gh_repo is not None:
        commit_url = f"https://github.com/{args.gh_repo}/commit/{commit_sha}"
        report.append(f"For commit **[{commit_message}]({commit_url})**")
    else:
        report.append(f"For commit **{commit_message}** (`{commit_sha}`)")

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

    if args.gh_run_id is not None:
        run_url = f"https://github.com/{args.gh_repo}/actions/runs/{args.gh_run_id}"
        if args.gh_run_attempt is not None:
            run_url += f"/attempts/{args.gh_run_attempt}"
        report.append("")
        report.append(f"[View run]({run_url})")

    if report_path is not None:
        report_path.write_text("\n".join(report) + "\n")

    critical_failed = False
    for subrepo in subrepos:
        if not subrepo.critical:
            continue
        if report_build.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            fprint(f"Critical repo {subrepo.name} failed to build.")
        if report_test.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            fprint(f"Critical repo {subrepo.name} failed to test.")
        if report_lint.get(subrepo.name) == Status.FAILURE:
            critical_failed = True
            fprint(f"Critical repo {subrepo.name} failed to lint.")

    if critical_failed:
        raise SystemExit("At least one critical repo failed.")


if __name__ == "__main__":
    main()
