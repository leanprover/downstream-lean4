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
    print(f"$ {' '.join(shlex.quote(str(arg)) for arg in args)}")
    return subprocess.run(
        args,
        check=check,
        cwd=cwd,
        capture_output=capture,
        text=True,
        env=env,
    )


def normalize_url(url: str) -> str:
    # GitHub URLs
    if match := re.fullmatch(
        r"(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/.]+?)(?:\.git)?/?",
        url,
    ):
        full_name = match.group(1)
        return f"https://github.com/{full_name}"

    return url


@dataclass
class Subrepo:
    name: str
    url: str
    rev: str
    override_only: bool

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
        url = normalize_url(data["url"])
        rev = data["rev"]
        override_only = data.get("override_only", False)
        yield Subrepo(name=name, url=url, rev=rev, override_only=override_only)
