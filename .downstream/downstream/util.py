import re
import shlex
import subprocess
import tomllib
from collections.abc import Generator
from dataclasses import dataclass
from os import PathLike
from pathlib import Path
from subprocess import CompletedProcess

type Arg = str | bytes | PathLike[str] | PathLike[bytes]


def run(
    *args: Arg,
    check: bool = True,
    cwd: Path | None = None,
    capture: bool = False,
    env: dict[str, str] | None = None,
) -> CompletedProcess[str]:
    print(f"$ {' '.join(shlex.quote(str(arg)) for arg in args)}", flush=True)
    return subprocess.run(
        args,
        check=check,
        cwd=cwd,
        capture_output=capture,
        text=True,
        env=env,
    )


def github_full_name(url: str) -> str | None:
    if m := re.fullmatch(
        r"(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/.]+?)(?:\.git)?/?",
        url,
    ):
        return m.group(1)
    return None


def normalize_url(url: str) -> str:
    if full_name := github_full_name(url):
        return f"https://github.com/{full_name}"
    return url


@dataclass
class Subrepo:
    name: str
    url: str
    rev: str
    aliases: list[str]
    critical: bool
    override_only: bool
    build_targets: list[str]
    build_options: list[str]
    test_options: list[str]
    test_args: list[str]
    lint_options: list[str]
    lint_args: list[str]

    @property
    def path(self) -> Path:
        return Path(self.name)

    @property
    def manifest_path(self) -> Path:
        return self.path / "lake-manifest.json"

    @property
    def override_path(self) -> Path:
        return self.path / ".lake" / "package-overrides.json"


def load_subrepos(path: Path) -> Generator[Subrepo]:
    for name, data in tomllib.loads(path.read_text()).items():
        yield Subrepo(
            name=name,
            url=normalize_url(data["url"]),
            rev=data["rev"],
            aliases=[normalize_url(url) for url in data.get("aliases", [])],
            critical=data.get("critical", True),
            override_only=data.get("override_only", False),
            build_targets=data.get("build_targets", []),
            build_options=data.get("build_options", []),
            test_options=data.get("test_options", []),
            test_args=data.get("test_args", []),
            lint_options=data.get("lint_options", []),
            lint_args=data.get("lint_args", []),
        )
