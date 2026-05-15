import json
import os
from argparse import ArgumentParser
from collections.abc import Generator
from graphlib import TopologicalSorter
from pathlib import Path
from typing import Any

import yaml12

from util import Repo, Subrepo, normalize_url


def get_subrepos(repo: Repo) -> Generator[tuple[Subrepo, list[Subrepo]]]:
    for subrepo in repo.subrepos:
        dependencies = []
        manifest = json.loads(subrepo.manifest_path.read_text())
        for package in manifest["packages"]:
            if package["type"] != "git":
                continue
            url = normalize_url(package["url"])
            if dep := repo.subrepos_by_url.get(url):
                dependencies.append(dep)
        yield subrepo, dependencies


def get_subrepos_dicts(
    repo: Repo,
) -> tuple[dict[str, Subrepo], dict[str, list[Subrepo]]]:
    subrepo_by_name = {}
    deps_by_name = {}
    for subrepo, dependencies in get_subrepos(repo):
        subrepo_by_name[subrepo.name] = subrepo
        deps_by_name[subrepo.name] = dependencies
    return subrepo_by_name, deps_by_name


def subrepo_names_topo(deps_by_name: dict[str, list[Subrepo]]) -> list[str]:
    graph = {name: {dep.name for dep in deps} for name, deps in deps_by_name.items()}
    return list(TopologicalSorter(graph).static_order())


def gh_expr(expr: str) -> str:
    return "${{ " + expr + " }}"


def gh_emoji_case(outcome: str) -> str:
    emoji = {
        "success": "✅",
        "failure": "🟥",
        "cancelled": "⏹️",
        "skipped": "⏭️",
    }

    caselist = []
    for key, value in emoji.items():
        caselist.append(f"{outcome} == '{key}'")
        caselist.append(f"'{value}'")
    caselist.append("'❓'")

    return f"case({', '.join(caselist)})"


def configure_steps(repo: Repo) -> list[Any]:
    subrepos_by_name, deps_by_name = get_subrepos_dicts(repo)

    steps: list[Any] = []

    # Initialize
    steps.append({
        "name": "Checkout",
        "uses": "actions/checkout@v6",
    })

    # Check all the subrepos
    for name in subrepo_names_topo(deps_by_name):
        subrepo = subrepos_by_name[name]
        deps = deps_by_name[name]
        steps.append({
            "id": f"check-{subrepo.name}",
            "if": " && ".join(
                f"steps.check-{dep.name}.outcome == 'success'" for dep in deps
            ),
            "name": f"Check {subrepo.name}",
            "uses": "leanprover/lean-action@120037de21d990cb66a6d592fa9b7fe64b1279e1",
            "with": {"lake-package-directory": subrepo.name},
            "continue-on-error": True,
        })

    # Generate report
    lines = []
    lines.append("echo '# Build results' >> $GITHUB_STEP_SUMMARY")
    for subrepo in repo.subrepos:
        outcome = f"steps.check-{subrepo.name}.outcome"
        emoji = gh_emoji_case(outcome)
        md_line = f"- {gh_expr(emoji)} `{subrepo.name}` ({gh_expr(outcome)})"
        lines.append(f"echo '{md_line}' >> $GITHUB_STEP_SUMMARY")
    steps.append({
        "name": "Generate report",
        "run": "\n".join(lines),
    })

    return steps


class Args:
    downstream: Path
    name: str


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("name", type=str)
    args = parser.parse_args(namespace=Args())

    os.chdir(args.downstream)
    repo = Repo()

    template_path = Path(f".github/workflows/{args.name}.template")
    output_path = Path(f".github/workflows/{args.name}")

    workflow: Any = yaml12.read_yaml(template_path)
    main = workflow.setdefault("jobs", {}).setdefault("main", {})
    main["steps"] = configure_steps(repo)
    yaml12.write_yaml(workflow, output_path)


if __name__ == "__main__":
    main()
