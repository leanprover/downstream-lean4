#!/usr/bin/env python3
import json
import os
import sys
from argparse import ArgumentParser
from contextlib import redirect_stdout
from dataclasses import asdict
from pathlib import Path

from downstream.updater import Updater


class Args:
    downstream: Path
    subrepo: str


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("downstream", type=Path)
    parser.add_argument("subrepo", type=str)
    args = parser.parse_args(namespace=Args())

    # Keep stdout clean for the json output
    with redirect_stdout(sys.stderr):
        os.chdir(args.downstream)
        updater = Updater()
        subrepo = updater.subrepos_by_name[args.subrepo]
        info = updater.find_latest_base_commit(subrepo)
    print(json.dumps(asdict(info)))


if __name__ == "__main__":
    main()
