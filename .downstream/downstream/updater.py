import json
import re
import shutil
from pathlib import Path
from subprocess import CalledProcessError

from downstream.merge_tree_theirs import merge_tree_theirs
from downstream.util import Subrepo, load_subrepos, normalize_url, run


class Updater:
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
        for file in subrepo.path.glob("**/lean-toolchain"):
            file.unlink()
            relative = Path("lean-toolchain").relative_to(file.parent, walk_up=True)
            file.symlink_to(relative)

    def fixup_subrepo_dependencies(self, subrepo: Subrepo) -> None:
        manifest = json.loads(subrepo.manifest_path.read_text())

        packages = []
        for package in manifest["packages"]:
            if package["type"] != "git":
                continue
            url = normalize_url(package["url"])

            if repo := self.overrides_by_url.get(url):
                sha, _ = self.fetch_sha_tree(repo.fetch_url, repo.rev)
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
        subrepo.override_path.parent.mkdir(parents=True, exist_ok=True)
        subrepo.override_path.write_text(json.dumps(overrides, indent=2))

    def commit(self, msg: str) -> None:
        result = run("git", "diff", "--staged", "--quiet", "--exit-code", check=False)
        if result.returncode == 0:
            return
        run("git", "commit", "-m", msg)

    def fixup_subrepo_and_commit(self, subrepo: Subrepo, sha: str, msg: str) -> None:
        self.fixup_subrepo_toolchain(subrepo)
        self.fixup_subrepo_dependencies(subrepo)

        message = "\n".join([
            f"downstream: {msg}",
            "",
            f"downstream-repo: {subrepo.name}",
            f"downstream-url: {subrepo.fetch_url}",
            f"downstream-rev: {subrepo.rev}",
            f"downstream-sha: {sha}",
        ])

        run("git", "add", subrepo.path)
        run("git", "add", "--force", subrepo.override_path)
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

    def add_subrepo(self, subrepo: Subrepo) -> None:
        print(f"::group::add {subrepo.name}", flush=True)
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.fetch_url, subrepo.rev)
        self.restore_tree_to(rev_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"add repo {subrepo.name}")
        print("::endgroup::", flush=True)

    def reset_subrepo(self, subrepo: Subrepo) -> None:
        print(f"::group::reset {subrepo.name}", flush=True)
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.fetch_url, subrepo.rev)
        self.restore_tree_to(rev_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"reset repo {subrepo.name}")
        print("::endgroup::", flush=True)

    def update_subrepo(self, subrepo: Subrepo) -> None:
        print(f"::group::update {subrepo.name}", flush=True)
        self.reset()

        rev_sha, rev_tree = self.fetch_sha_tree(subrepo.fetch_url, subrepo.rev)
        our_tree = self.get_tree_in_head(subrepo.name)
        base_sha = self.find_latest_subrepo_sha(subrepo)
        _, base_tree = self.fetch_sha_tree(subrepo.fetch_url, base_sha)
        merged_tree = merge_tree_theirs(base_tree, our_tree, rev_tree)

        self.restore_tree_to(merged_tree, subrepo.path)
        self.fixup_subrepo_and_commit(subrepo, rev_sha, f"update repo {subrepo.name}")
        print("::endgroup::", flush=True)

    def fixup_subrepo(self, subrepo: Subrepo) -> None:
        print(f"::group::fixup {subrepo.name}", flush=True)
        self.reset()

        base_sha = self.find_latest_subrepo_sha(subrepo)
        self.fixup_subrepo_and_commit(subrepo, base_sha, f"fixup repo {subrepo.name}")
        print("::endgroup::", flush=True)

    def remove_subrepo(self, path: Path) -> None:
        print(f"::group::prune {path.name}", flush=True)
        self.reset()

        run("git", "rm", "-rf", path)
        self.commit(f"downstream: remove repo {path.name}")
        print("::endgroup::", flush=True)

    def add_or_reset_subrepo(self, subrepo: Subrepo) -> None:
        if subrepo.path.exists():
            self.reset_subrepo(subrepo)
        else:
            self.add_subrepo(subrepo)

    def add_or_update_subrepo(self, subrepo: Subrepo) -> None:
        if subrepo.path.exists():
            self.update_subrepo(subrepo)
        else:
            self.add_subrepo(subrepo)

    def prune_subrepos(self) -> None:
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
        self.fetch_sha_tree(subrepo.fetch_url, base_sha)

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
