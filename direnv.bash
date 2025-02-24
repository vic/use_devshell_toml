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
rm -rf $config_flake
mkdir -p $config_flake

if test -e ./flake.toml; then
   nix eval "path:@MAIN_FLAKE@#lib.mkFlake" --apply "f: f ./flake.toml" --raw --impure > $config_flake/flake.nix
else
   nix eval "path:@MAIN_FLAKE@#lib.emptyFlake" --raw > $config_flake/flake.nix
fi

stored_config_flake="$(nix store add $config_flake)"
rm -rf $config_flake
ln -sfn $stored_config_flake $config_flake

use_flake "path:@TOML_FLAKE@" --override-input source $PWD --override-input config $stored_config_flake --show-trace

}