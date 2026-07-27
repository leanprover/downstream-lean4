#!/usr/bin/env bash

META_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(dirname "$META_DIR")
export LAKE_CONFIG="$META_DIR/lake-config.toml"

TOOLCHAIN="$(cat "$ROOT_DIR/lean-toolchain")"
TOOLCHAIN="${TOOLCHAIN#leanprover/lean4:}"

python3 "$ROOT_DIR/.downstream/list.py" "$ROOT_DIR" | while IFS= read -r repo; do
  pushd "$ROOT_DIR/$repo"
  lake cache get --scope "$TOOLCHAIN/$repo" || true
  popd
done
