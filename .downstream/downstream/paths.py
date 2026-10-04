from collections.abc import Generator
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Paths:
    root: Path = Path()

    ################
    ## Toolchains ##
    ################

    @property
    def toolchain(self) -> Path:
        return self.root / "lean-toolchain"

    def toolchains(self) -> Generator[Path]:
        yield from sorted(self.root.glob("**/lean-toolchain"))

    def toolchains_to_override(self) -> Generator[Path]:
        root_toolchain = self.toolchain.read_text().strip()
        for file in self.toolchains():
            if file.read_text().strip() == root_toolchain:
                yield file

    def unlink_all_toolchains(self) -> None:
        for file in self.toolchains():
            file.unlink()

    def override_toolchains_with_symlinks(self, target: Path) -> None:
        for file in self.toolchains_to_override():
            file.unlink()
            file.symlink_to(target.relative_to(file.parent, walk_up=True))

    def override_toolchains_with_values(self, toolchain: str) -> None:
        toolchain = toolchain.strip() + "\n"
        for file in self.toolchains_to_override():
            file.write_text(toolchain)

    ###############
    ## Lakefiles ##
    ###############

    def lakefiles(self) -> Generator[Path]:
        tomls = self.root.glob("**/lakefile.toml")
        leans = self.root.glob("**/lakefile.lean")
        yield from sorted(list(tomls) + list(leans))

    ###############
    ## Manifests ##
    ###############

    @property
    def manifest(self) -> Path:
        return self.root / "lake-manifest.json"

    def manifests(self) -> Generator[Path]:
        yield from sorted(self.root.glob("**/lake-manifest.json"))

    @staticmethod
    def override_for(manifest: Path) -> Path:
        return manifest.parent / ".lake" / "package-overrides.json"

    def overrides(self) -> Generator[Path]:
        yield from sorted(self.root.glob("**/.lake/package-overrides.json"))
