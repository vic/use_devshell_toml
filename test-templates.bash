#!/usr/bin/env bash
#
# Execute via: nix run .#test-templates

base="$PWD"

for template in templates/*; do
(
    set -euo pipefail
    echo
    echo
    echo
    echo
    echo "=========== $template ==========="
    out="$(mktemp -d)"
    export HOME="$out"
    mkdir -p "$HOME/.config/nix"
    echo "extra-experimental-features = nix-command flakes" > "$HOME/.config/nix/nix.conf"

    cd "$out"
    cp -rf "$base/$template"/{*,.*} "$out/"

    nix run "path:$base"
    test -e "$HOME/.config/direnv/lib/use_devshell_toml.sh"

    echo "set -euo pipefail; source $HOME/.config/direnv/lib/use_devshell_toml.sh; use devshell_toml" > .envrc
    direnv allow 
    direnv exec "$PWD" direnv dump json | jq -r .DEVSHELL_DIR > "$out/devshell_dir"
    devshell_bin="$(< "$out/devshell_dir")/bin"
    ls -l "$devshell_bin"
    "$devshell_bin/menu"
)
done