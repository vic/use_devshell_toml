#!/usr/bin/env bash
#
# Execute via: nix run .#test-templates

base="$PWD"
function test_template() {
  set -vaeuo pipefail
  template="$1"
  echo "===== $template =====" | tr '[:print:]' '='
  echo "||    $template    ||"
  echo "===== $template =====" | tr '[:print:]' '='
  if test -z "${CI:-}"; then
    out="$(mktemp -d)"
  else
    out="$(pwd)/ci"
  fi
  export HOME="$out"

  env

  mkdir -p "$HOME/.config/nix"
  echo "extra-experimental-features = nix-command flakes" >"$HOME/.config/nix/nix.conf"

  cd "$out"

  cp -rf "$base/$template"/* "$out/"

  nix run "path:$base" --show-trace
  test -e "$HOME/.config/direnv/lib/use_devshell_toml.sh"

  # use bash strict inside .envrc
  echo "set -euo pipefail; source $HOME/.config/direnv/lib/use_devshell_toml.sh; use devshell_toml --show-trace" >"$out/.envrc" && direnv allow "$out"
  direnv exec "$out" check
}

if test -z "${1:-}"; then
  for template in templates/*; do
    test_template "$template"
  done
else
  test_template "$1"
fi

