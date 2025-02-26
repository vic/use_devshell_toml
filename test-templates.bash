#!/usr/bin/env bash
#
# Execute via: nix run .#test-templates

base="$PWD"
function test_template() {
    set -euo pipefail
    template="$1"
    echo "===== $template =====" | tr '[:print:]' '='
    echo "||    $template    ||"
    echo "===== $template =====" | tr '[:print:]' '='
    out="$(mktemp -d)"
    export HOME="$out"
    mkdir -p "$HOME/.config/nix"
    echo "extra-experimental-features = nix-command flakes" > "$HOME/.config/nix/nix.conf"

    cd "$out"
    touch "$out/.envrc" && direnv deny "$out" # temporarily until we setup .envrc

    cp -rf "$base/$template"/* "$out/"

    nix run "path:$base"
    test -e "$HOME/.config/direnv/lib/use_devshell_toml.sh"

    # use bash strict inside .envrc
    echo "set -euo pipefail; source $HOME/.config/direnv/lib/use_devshell_toml.sh; use devshell_toml" > "$out/.envrc"

    direnv allow "$out"
    direnv exec "$out" check
}

if test -z "${1:-}"; then
    for template in templates/*; do
      (test_template "$template")
    done
else
  (test_template "$1")
fi