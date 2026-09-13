import json
import re
import shutil
from dataclasses import dataclass
from graphlib import TopologicalSorter
from pathlib import Path
from subprocess import CalledProcessError

from downstream.merge_tree_theirs import merge_tree_theirs
from downstream.util import (
    Subrepo,
    github_full_name,
    group,
    load_subrepos,
    normalize_url,
    run,
)


@dataclass
class CommitStatus:
    empty: bool
    committed: bool

    @classmethod
    def unit(cls) -> "CommitStatus":
        return cls(empty=True, committed=False)

    def join(self, other: "CommitStatus") -> "CommitStatus":
        return CommitStatus(
            empty=self.empty and other.empty,
            committed=self.committed or other.committed,
        )


class Updater:
    def __init__(self) -> None:
        self.toolchain = Path("lean-toolchain").read_text().strip()
        subrepos = list(load_subrepos(Path("repos.toml")))

        self.overrides = [r for r in subrepos if r.override_only]
        self.overrides_by_name = {r.name: r for r in self.overrides}
        self.overrides_by_url = {
            url: r for r in self.overrides for url in (r.url, *r.aliases)
        }

        self.subrepos = [r for r in subrepos if not r.override_only]
        self.subrepos_by_name = {r.name: r for r in self.subrepos}
        self.subrepos_by_url = {
            url: r for r in self.subrepos for url in (r.url, *r.aliases)
        }

    def dep_graph(self, external: bool = False) -> dict[str, set[str]]:
        graph: dict[str, set[str]] = {}
        for subrepo in self.subrepos:
            deps: set[str] = set()
            graph[subrepo.name] = deps
            if subrepo.assume_empty_manifest and not subrepo.manifest_path.exists():
                continue
            manifest = json.loads(subrepo.manifest_path.read_text())
            for package in manifest["packages"]:
                if package["type"] != "git":
                    continue
                url = normalize_url(package["url"])
                if dep := self.subrepos_by_url.get(url):
                    deps.add(dep.name)
                elif external:
                    deps.add(github_full_name(url) or url)
        return graph

    def topo_subrepos(self) -> list[Subrepo]:
        graph = self.dep_graph()
        order = TopologicalSorter(graph).static_order()
        return [self.subrepos_by_name[name] for name in order]

    def reset(self) -> None:
        run("git", "clean", "-dffx")
        run("git", "restore", "--staged", "--worktree", ".")

    def fetch_sha_tree(self, url: str, rev: str) -> tuple[str, str]:
        try:
            run("git", "fetch", "--depth=1", url, rev)
        except CalledProcessError:
            # Retrying once since this command occasionally fails with the error
            # "fatal: shallow file has changed since we read it".
            run("git", "fetch", "--depth=1", url, rev)

        sha = run("git", "rev-parse", "FETCH_HEAD", capture=True).stdout.strip()
        tree = run("git", "rev-parse", "FETCH_HEAD^{tree}", capture=True).stdout.strip()
        return sha, tree

    def restore_tree_to(self, tree: str, path: Path) -> None:
        path.mkdir(parents=True, exist_ok=True)
        shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)

        run(
            *("git", f"--work-tree={path}"),
            *("restore", "--worktree", f"--source={tree}", "."),
        )

    def fixup_subrepo_toolchain(self, subrepo: Subrepo) -> None:
        subrepo_toolchain = (subrepo.path / "lean-toolchain").read_text().strip()
        for file in subrepo.path.glob("**/lean-toolchain"):
            if file.read_text().strip() != subrepo_toolchain:
                continue
            file.unlink()
            relative = Path("lean-toolchain").relative_to(file.parent, walk_up=True)
            file.symlink_to(relative)

    def fixup_manifest_dependencies(self, manifest_path: Path) -> None:
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
                package["dir"] = str(
                    repo.path.relative_to(manifest_path.parent, walk_up=True)
                )
                package["scope"] = ""
                del package["url"]
                del package["rev"]
                del package["inputRev"]
                packages.append(package)

        overrides = {"version": manifest["version"], "packages": packages}
        override_path = manifest_path.parent / ".lake" / "package-overrides.json"
        override_path.parent.mkdir(parents=True, exist_ok=True)
        override_path.write_text(json.dumps(overrides, indent=2))

    def fixup_subrepo_dependencies(self, subrepo: Subrepo) -> None:
        for manifest_path in subrepo.find_manifest_paths():
            self.fixup_manifest_dependencies(manifest_path)

    def commit(self, msg: str, allow_empty: bool = False) -> CommitStatus:
        result = run("git", "diff", "--staged", "--quiet", "--exit-code", check=False)
        empty = result.returncode == 0
        committed = False
        if not empty:
            run("git", "commit", "-m", msg)
            committed = True
        elif allow_empty:
            run("git", "commit", "--allow-empty", "-m", msg)
            committed = True
        return CommitStatus(empty=empty, committed=committed)

    def fixup_subrepo_and_commit(
        self, subrepo: Subrepo, sha: str, msg: str
    ) -> CommitStatus:
        self.fixup_subrepo_toolchain(subrepo)
        self.fixup_subrepo_dependencies(subrepo)

        message = "\n".join([
            f"downstream: {msg}",
            "",
            f"downstream-repo: {subrepo.name}",
            f"downstream-url: {subrepo.url}",
            f"downstream-rev: {subrepo.rev}",
            f"downstream-sha: {sha}",
        ])

        try:
            base_changed = self.find_latest_subrepo_sha(subrepo) != sha
        except ValueError:
            base_changed = True

        run("git", "add", subrepo.path)
        for override_path in subrepo.path.glob("**/.lake/package-overrides.json"):
            run("git", "add", "--force", override_path)
        return self.commit(message, allow_empty=base_changed)

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

    def add_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"add {subrepo.name}"):
            self.reset()

            rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
            self.restore_tree_to(rev_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"add repo {subrepo.name}"
            )

    def reset_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"reset {subrepo.name}"):
            self.reset()

            rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
            self.restore_tree_to(rev_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"reset repo {subrepo.name}"
            )

    def update_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"update {subrepo.name}"):
            self.reset()

            rev_sha, rev_tree = self.fetch_sha_tree(subrepo.url, subrepo.rev)
            our_tree = self.get_tree_in_head(subrepo.name)
            base_sha = self.find_latest_subrepo_sha(subrepo)
            _, base_tree = self.fetch_sha_tree(subrepo.url, base_sha)
            merged_tree = merge_tree_theirs(base_tree, our_tree, rev_tree)

            self.restore_tree_to(merged_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"update repo {subrepo.name}"
            )

    def fixup_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"fixup {subrepo.name}"):
            self.reset()

            base_sha = self.find_latest_subrepo_sha(subrepo)
            return self.fixup_subrepo_and_commit(
                subrepo, base_sha, f"fixup repo {subrepo.name}"
            )

    def remove_subrepo(self, path: Path) -> CommitStatus:
        with group(f"remove {path.name}"):
            self.reset()

            run("git", "rm", "-rf", path)
            return self.commit(f"downstream: remove repo {path.name}")

    def add_or_reset_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        if subrepo.path.exists():
            return self.reset_subrepo(subrepo)
        else:
            return self.add_subrepo(subrepo)

    def add_or_update_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        if subrepo.path.exists():
            return self.update_subrepo(subrepo)
        else:
            return self.add_subrepo(subrepo)

    def add_or_fixup_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        if subrepo.path.exists():
            return self.fixup_subrepo(subrepo)
        else:
            return self.add_subrepo(subrepo)

    def prune_subrepos(self) -> CommitStatus:
        status = CommitStatus.unit()
        for path in Path().iterdir():
            if not path.is_dir():
                continue
            if path.name.startswith("."):
                continue
            if path.name not in self.subrepos_by_name:
                status = status.join(self.remove_subrepo(path))
        return status

    def split(
        self, subrepo: Subrepo, message: str = "chore: nightly adaptations"
    ) -> CommitStatus:
        self.reset()

        our_tree = self.get_tree_in_head(subrepo.name)
        base_sha = self.find_latest_subrepo_sha(subrepo)
        self.fetch_sha_tree(subrepo.url, base_sha)

        run("git", "switch", "--detach", base_sha)
        run("git", "read-tree", "--reset", "-u", our_tree)

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
        return self.commit(message)
