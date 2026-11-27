#!/usr/bin/env python3
import json
from argparse import ArgumentParser
from dataclasses import asdict
from pathlib import Path

from downstream.util import load_subrepos


class Args:
    repos_toml: Path


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("repos_toml", type=Path)
    args = parser.parse_args(namespace=Args())

    subrepos = [asdict(s) for s in load_subrepos(args.repos_toml)]
    print(json.dumps(subrepos))


if __name__ == "__main__":
    main()
