#!/usr/bin/env bash

use_devshell_toml() {

if [[ $(type -t use_flake) != function ]]; then
  echo "ERROR: use_flake function missing."
  echo "Please update direnv to v2.30.0 or later."
  exit 1
fi

watch_file devshell.toml
watch_file flake.toml

config_flake="$(direnv_layout_dir)"/config-flake
mkdir -p $config_flake
nix run "path:@MAIN_FLAKE@#gen-config-flake" ./flake.toml > $config_flake/flake.nix

source_flake="$(direnv_layout_dir)"/source-flake
mkdir -p $source_flake
nix run "path:@MAIN_FLAKE@#gen-source-flake" "$PWD" "$config_flake" > $source_flake/flake.nix

use_flake "path:$source_flake" "$@"

}