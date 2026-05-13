import json
import re
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from os import PathLike
from pathlib import Path
from subprocess import CompletedProcess
from typing import Generator

import tomllib

type Arg = str | bytes | PathLike[str] | PathLike[bytes]


def run(
    *args: Arg, check: bool = True, cwd: Path | None = None, capture: bool = False
) -> CompletedProcess[str]:
    print(f"$ {' '.join(shlex.quote(str(arg)) for arg in args)}")
    return subprocess.run(args, check=check, cwd=cwd, capture_output=capture, text=True)


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


def load_subrepos(path: Path) -> Generator[Subrepo]:
    for name, data in tomllib.loads(path.read_text()).items():
        url = normalize_url(data["url"])
        rev = data["rev"]
        override_only = data.get("override_only", False)
        yield Subrepo(name=name, url=url, rev=rev, override_only=override_only)


class Repo:
    def __init__(self) -> None:
        self.toolchain = Path("lean-toolchain").read_text().strip()
        subrepos = list(load_subrepos(Path("repos.toml")))

        self.overrides = [r for r in subrepos if r.override_only]
        self.overrides_by_name = {r.name: r for r in self.overrides}
        self.overrides_by_url = {r.url: r for r in self.overrides}

        self.subrepos = [r for r in subrepos if not r.override_only]
        self.subrepos_by_name = {r.name: r for r in self.subrepos}
        self.subrepos_by_url = {r.url: r for r in self.subrepos}

    def reset(self) -> None:
        run("git", "clean", "-dffx")
        run("git", "restore", "--staged", "--worktree", ".")

    def fetch_sha_tree(self, url: str, rev: str) -> tuple[str, str]:
        run("git", "fetch", "--depth=1", url, rev)
        sha = run("git", "rev-parse", "FETCH_HEAD", capture=True).stdout.strip()
        tree = run("git", "rev-parse", "FETCH_HEAD^{tree}", capture=True).stdout.strip()
        return sha, tree

    def restore_tree_to(self, tree: str, path: Path) -> None:
        path.mkdir(parents=True, exist_ok=True)
        run(
            *("git", f"--work-tree={path}"),
            *("restore", "--worktree", f"--source={tree}", "."),
        )

    def fixup_subrepo_toolchain(self, subrepo: Subrepo) -> None:
        for file in subrepo.path.glob("**/lean-toolchain"):
            file.unlink()
            relative = Path("lean-toolchain").relative_to(file.parent, walk_up=True)
            file.symlink_to(relative)

    def fixup_subrepo_dependencies(self, subrepo: Subrepo) -> None:
        manifest_path = subrepo.path / "lake-manifest.json"
        override_path = subrepo.path / ".lake" / "package-overrides.json"

        manifest = json.loads(manifest_path.read_text())

        packages = []
        for package in manifest["packages"]:
            if package["type"] != "git":
                continue
            url = normalize_url(package["url"])

            if repo := self.overrides_by_url.get(url):
                sha, _ = self.fetch_sha_tree(repo.url, repo.rev)
                package["input_rev"] = repo.rev
                package["rev"] = sha
                packages.append(package)
            elif repo := self.subrepos_by_url.get(url):
                package["type"] = "path"
                package["dir"] = f"../{repo.name}"
                package["scope"] = ""
                del package["url"]
                del package["rev"]
                del package["inputRev"]
                packages.append(package)

        overrides = {"version": manifest["version"], "packages": packages}
        override_path.parent.mkdir(parents=True, exist_ok=True)
        override_path.write_text(json.dumps(overrides, indent=2))

    def commit(self, msg: str) -> None:
        result = run("git", "diff", "--staged", "--quiet", "--exit-code", check=False)
        if result.returncode == 0:
            return
        run("git", "commit", "-m", msg)

    def fixup_subrepo_and_commit(self, subrepo: Subrepo, sha: str, msg: str) -> None:
        self.fixup_subrepo_toolchain(subrepo)
        self.fixup_subrepo_dependencies(subrepo)

        message = "\n".join(
            [
                f"downstream: {msg}",
                "",
                f"downstream-repo: {subrepo.name}",
                f"downstream-url: {subrepo.url}",
                f"downstream-rev: {subrepo.rev}",
                f"downstream-sha: {sha}",
            ]
        )

        run("git", "add", subrepo.path)
        run("git", "add", "--force", subrepo.path / ".lake" / "package-overrides.json")
        self.commit(message)

    def find_latest_subrepo_sha(self, subrepo: Subrepo) -> str:
        message = run(
            *("git", "log", "-1", "-E"),
            f"--grep=^downstream-repo: {re.escape(subrepo.name)}$",
            "--format=%B",
            capture=True,
        ).stdout

        for line in message.splitlines():
            if match := re.fullmatch(r"downstream-sha: (.+)", line):
                return match.group(1).strip()

        raise ValueError(f"no previous commit found for subrepo {subrepo.name}")

    def get_tree_in_head(self, path: str) -> str:
        return run("git", "rev-parse", f"HEAD:{path}", capture=True).stdout.strip()

    def merge_trees_preferring_theirs(self, base: str, ours: str, theirs: str) -> str:
        return run(
            *("git", "merge-tree", "--write-tree"),
            *(f"--merge-base={base}", "-Xtheirs", ours, theirs),
            capture=True,
        ).stdout.strip()

    def add_subrepo(self, subrepo: Subrepo) -> None:
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
        self.restore_tree_to(rev_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"add repo {subrepo.name}")

    def reset_subrepo(self, subrepo: Subrepo) -> None:
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
        shutil.rmtree(subrepo.path)
        self.restore_tree_to(rev_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"reset repo {subrepo.name}")

    def update_subrepo(self, subrepo: Subrepo) -> None:
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
        our_tree = self.get_tree_in_head(subrepo.name)
        base_sha = self.find_latest_subrepo_sha(subrepo)
        _, base_tree = self.fetch_sha_tree(subrepo.url, base_sha)
        merged_tree = self.merge_trees_preferring_theirs(base_tree, our_tree, rev_tree)

        self.restore_tree_to(merged_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"update repo {subrepo.name}")

    def remove_subrepo(self, path: Path) -> None:
        self.reset()

        run("git", "rm", "-rf", path)
        self.commit(f"downstream: remove repo {path.name}")

    def add_or_update_subrepo(self, subrepo: Subrepo) -> None:
        self.reset()

        if subrepo.path.exists():
            self.update_subrepo(subrepo)
        else:
            self.add_subrepo(subrepo)

    def prune_subrepos(self) -> None:
        self.reset()

        for path in Path().iterdir():
            if not path.is_dir():
                continue
            if path.name.startswith("."):
                continue
            if path.name not in self.subrepos_by_name:
                self.remove_subrepo(path)

    def split_to_branch(self, subrepo: Subrepo, branch: str) -> None:
        self.reset()

        our_tree = self.get_tree_in_head(subrepo.name)
        base_sha = self.find_latest_subrepo_sha(subrepo)
        self.fetch_sha_tree(subrepo.url, base_sha)

        run("git", "switch", "-C", branch, base_sha)
        self.restore_tree_to(our_tree, Path())

        run(
            *("git", "restore", "--worktree"),
            f"--source={our_tree}",
            ".",
        )

        # Remove our overrides
        for file in Path().glob("**/.lake/package-overrides.json"):
            file.unlink()

        # Restore all lean-toolchain files from the base commit
        for file in Path().glob("**/lean-toolchain"):
            file.unlink()
        run(
            *("git", "restore", "--worktree"),
            f"--source={base_sha}",
            ":(glob)**/lean-toolchain",
        )

        run("git", "add", ".")
        self.commit("chore: nightly adaptations")
