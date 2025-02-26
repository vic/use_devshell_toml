#!/usr/bin/env bash

use_devshell_toml() {

if [[ $(type -t use_flake) != function ]]; then
  echo "ERROR: use_flake function missing."
  echo "Please update direnv to v2.30.0 or later."
  exit 1
fi

watch_file devshell.toml
watch_file flake.toml

source_flake="$(direnv_layout_dir)"/source-flake
nix run "path:@MAIN_FLAKE@#gen-flakes" "$PWD" "$source_flake"
use_flake "path:$source_flake" "$@"

}