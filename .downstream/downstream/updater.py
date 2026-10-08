import json
import re
import shutil
from dataclasses import dataclass
from graphlib import TopologicalSorter
from pathlib import Path
from subprocess import CalledProcessError

from downstream.merge_tree_theirs import merge_tree_theirs
from downstream.paths import Paths
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


@dataclass
class BaseCommit:
    repo: str
    url: str
    rev: str
    sha: str


class Updater:
    def __init__(self) -> None:
        self.toolchain = Path("lean-toolchain").read_text().strip()
        subrepos = list(load_subrepos(Path("repos.toml")))

        self.overrides = [r for r in subrepos if r.override_only]
        self.overrides_by_name = {r.name: r for r in self.overrides}
        self.overrides_by_url = {
            url: r for r in self.overrides for url in (r.source_url, *r.alias_urls)
        }

        self.subrepos = [r for r in subrepos if not r.override_only]
        self.subrepos_by_name = {r.name: r for r in self.subrepos}
        self.subrepos_by_url = {
            url: r for r in self.subrepos for url in (r.source_url, *r.alias_urls)
        }

    def dep_graph(self, external: bool = False) -> dict[str, set[str]]:
        graph: dict[str, set[str]] = {}
        for subrepo in self.subrepos:
            manifest_path = Paths(subrepo.path).manifest
            deps: set[str] = set()
            graph[subrepo.name] = deps
            if subrepo.assume_empty_manifest and not manifest_path.exists():
                continue
            manifest = json.loads(manifest_path.read_text())
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

    def local_sha_tree(self, rev: str) -> tuple[str, str]:
        sha = run("git", "rev-parse", f"{rev}^{{commit}}", capture=True).stdout.strip()
        tree = run("git", "rev-parse", f"{rev}^{{tree}}", capture=True).stdout.strip()
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
        Paths(subrepo.path).override_toolchains_with_symlinks(Paths().toolchain)

    def fixup_manifest_dependencies(self, manifest_path: Path) -> None:
        manifest = json.loads(manifest_path.read_text())

        packages = []
        for package in manifest["packages"]:
            if package["type"] != "git":
                continue
            url = normalize_url(package["url"])

            if repo := self.overrides_by_url.get(url):
                sha, _ = self.fetch_sha_tree(repo.source_url, repo.source_rev)
                package["input_rev"] = repo.source_rev
                package["rev"] = sha
                packages.append(package)
            elif repo := self.subrepos_by_url.get(url):
                package["type"] = "path"
                package["dir"] = str(
                    repo.path.relative_to(manifest_path.parent, walk_up=True)
                )
                package["scope"] = ""
                if repo.copy:
                    package["copy"] = True
                del package["url"]
                del package["rev"]
                del package["inputRev"]
                packages.append(package)

        overrides = {"version": manifest["version"], "packages": packages}
        override_path = Paths.override_for(manifest_path)
        override_path.parent.mkdir(parents=True, exist_ok=True)
        override_path.write_text(json.dumps(overrides, indent=2))

    def fixup_subrepo_dependencies(self, subrepo: Subrepo) -> None:
        for manifest_path in Paths(subrepo.path).manifests():
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

    def fixup_subrepo_and_stage(self, subrepo: Subrepo) -> None:
        self.fixup_subrepo_toolchain(subrepo)
        self.fixup_subrepo_dependencies(subrepo)

        run("git", "add", subrepo.path)
        for override_path in subrepo.path.glob("**/.lake/package-overrides.json"):
            run("git", "add", "--force", override_path)

    def fixup_subrepo_and_commit(
        self, subrepo: Subrepo, sha: str, msg: str
    ) -> CommitStatus:
        self.fixup_subrepo_and_stage(subrepo)

        message = "\n".join([
            f"downstream: {msg}",
            "",
            f"downstream-repo: {subrepo.name}",
            f"downstream-url: {subrepo.source_url}",
            f"downstream-rev: {subrepo.source_rev}",
            f"downstream-sha: {sha}",
        ])

        try:
            base_changed = self.find_latest_base_commit(subrepo).sha != sha
        except ValueError:
            base_changed = True

        return self.commit(message, allow_empty=base_changed)

    def find_latest_base_commit(self, subrepo: Subrepo) -> BaseCommit:
        messages = run(
            *("git", "log", "-z", "-E"),
            f"--grep=^downstream-repo: {re.escape(subrepo.name)}$",
            "--format=%B",
            capture=True,
        ).stdout

        # I don't want to rely on the ordering of `downstream-*` tags, so
        # they're matched here instead of included in the regex above.
        for message in messages.split("\0"):
            m_url = re.search(r"^downstream-url: (.+)$", message, re.MULTILINE)
            m_rev = re.search(r"^downstream-rev: (.+)$", message, re.MULTILINE)
            m_sha = re.search(r"^downstream-sha: (.+)$", message, re.MULTILINE)

            if not (m_url and m_rev and m_sha):
                continue

            url = m_url.group(1).strip()
            rev = m_rev.group(1).strip()
            if url != subrepo.source_url or rev != subrepo.source_rev:
                continue

            return BaseCommit(
                repo=subrepo.name,
                url=url,
                rev=rev,
                sha=m_sha.group(1).strip(),
            )

        raise ValueError(f"no previous commit found for subrepo {subrepo.name}")

    def get_tree_in_head(self, path: str) -> str:
        return run("git", "rev-parse", f"HEAD:{path}", capture=True).stdout.strip()

    def add_subrepo(self, subrepo: Subrepo, sha: str | None = None) -> CommitStatus:
        with group(f"add {subrepo.name}"):
            self.reset()

            if sha is None:
                rev_sha, rev_tree = self.fetch_sha_tree(
                    subrepo.source_url, subrepo.source_rev
                )
            else:
                rev_sha, rev_tree = self.local_sha_tree(sha)
            self.restore_tree_to(rev_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"add repo {subrepo.name}"
            )

    def reset_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"reset {subrepo.name}"):
            self.reset()

            rev_sha, rev_tree = self.fetch_sha_tree(
                subrepo.source_url, subrepo.source_rev
            )
            self.restore_tree_to(rev_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"reset repo {subrepo.name}"
            )

    # Like reset_subrepo, but from an arbitrary repo and rev, and without
    # recording a new base commit for the subrepo.
    def import_subrepo(
        self, subrepo: Subrepo, url: str, rev: str, source: str | None = None
    ) -> CommitStatus:
        with group(f"import {subrepo.name}"):
            self.reset()

            rev_sha, rev_tree = self.fetch_sha_tree(url, rev)
            self.restore_tree_to(rev_tree, subrepo.path)
            self.fixup_subrepo_and_stage(subrepo)

            msg = f"downstream: import repo {subrepo.name}"
            if source:
                msg += f" from {source}"
            msg += f"\n\nsource sha: {rev_sha}"
            return self.commit(msg)

    # If sha is given, both it and the base commit must be available locally.
    def update_subrepo(self, subrepo: Subrepo, sha: str | None = None) -> CommitStatus:
        with group(f"update {subrepo.name}"):
            self.reset()

            our_tree = self.get_tree_in_head(subrepo.name)
            base_sha = self.find_latest_base_commit(subrepo).sha
            if sha is None:
                rev_sha, rev_tree = self.fetch_sha_tree(
                    subrepo.source_url, subrepo.source_rev
                )
                _, base_tree = self.fetch_sha_tree(subrepo.source_url, base_sha)
            else:
                rev_sha, rev_tree = self.local_sha_tree(sha)
                _, base_tree = self.local_sha_tree(base_sha)
            merged_tree = merge_tree_theirs(base_tree, our_tree, rev_tree)

            self.restore_tree_to(merged_tree, subrepo.path)
            return self.fixup_subrepo_and_commit(
                subrepo, rev_sha, f"update repo {subrepo.name}"
            )

    def fixup_subrepo(self, subrepo: Subrepo) -> CommitStatus:
        with group(f"fixup {subrepo.name}"):
            self.reset()

            base_sha = self.find_latest_base_commit(subrepo).sha
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

    def add_or_update_subrepo(
        self, subrepo: Subrepo, sha: str | None = None
    ) -> CommitStatus:
        if subrepo.path.exists():
            return self.update_subrepo(subrepo, sha)
        else:
            return self.add_subrepo(subrepo, sha)

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

    def edit_lakefile(self, lakefile: Path, edits: list[tuple[str, str]]) -> None:
        text = lakefile.read_text()
        for pattern, replacement in edits:
            text = re.sub(pattern, replacement, text, flags=re.MULTILINE)
        lakefile.write_text(text)

    def resolve_sha_placeholders(self, text: str) -> str:
        def repl(m: re.Match[str]) -> str:
            name = m.group(1)
            if name not in self.subrepos_by_name:
                raise ValueError(f"unknown repo {name!r} in placeholder {m.group(0)!r}")
            return self.find_latest_base_commit(self.subrepos_by_name[name]).sha

        return re.sub(r"<([^<>\s]+) sha>", repl, text)

    def export(
        self,
        subrepo: Subrepo,
        message: str = "chore: nightly adaptations",
        onto: str | None = None,
        update_toolchains: bool = False,
        lakefile_edits: list[tuple[str, str]] | None = None,
        update_manifests: bool = False,
    ) -> CommitStatus:
        self.reset()

        our_tree = self.get_tree_in_head(subrepo.name)
        our_toolchain = Path("lean-toolchain").read_text()

        # Must happen while HEAD is still the downstream commit
        lakefile_edits = [
            (pattern, self.resolve_sha_placeholders(replacement))
            for pattern, replacement in (lakefile_edits or [])
        ]

        base_sha = onto
        if base_sha is None:
            base_sha = self.find_latest_base_commit(subrepo).sha
            self.fetch_sha_tree(subrepo.source_url, base_sha)

        run("git", "switch", "--detach", base_sha)
        run("git", "read-tree", "--reset", "-u", our_tree)

        # Remove our overrides
        for file in Path().glob("**/.lake/package-overrides.json"):
            file.unlink()

        # Restore lean-toolchain files to their previous value
        Paths().unlink_all_toolchains()
        run(
            *("git", "restore", "--worktree", f"--source={base_sha}"),
            ":(glob)**/lean-toolchain",
        )

        if update_toolchains:
            Paths().override_toolchains_with_values(our_toolchain)

        if lakefile_edits:
            for lakefile in Paths().lakefiles():
                self.edit_lakefile(lakefile, lakefile_edits)

        if update_manifests:
            for manifest in Paths().manifests():
                run("lake", "update", cwd=manifest.parent)

        run("git", "add", ".")
        return self.commit(message)
