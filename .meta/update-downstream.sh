#!/usr/bin/env bash

# This script must be run from the repo root
git subtree pull -P .downstream https://github.com/leanprover/downstream master -m "chore: update downstream"
