#!/usr/bin/env bash
#
# Execute via: nix run .#test-templates

set -euo pipefail

out="$(mktemp -d)"
(
    export HOME="$out"
    mkdir -p "$HOME/.config/nix"
    echo "extra-experimental-features = nix-command flakes" > "$HOME/.config/nix/nix.conf"

    nix run .
    test -e "$HOME/.config/direnv/lib/use_devshell_toml.sh"
    eval "$(direnv hook bash)"

    for template in templates/*; do
    (
        echo "=========== $template ==========="
        cd "$template"
        direnv allow 
        direnv exec "$PWD" direnv dump json | jq -r .DEVSHELL_DIR | tee "$out/$(basename "$template")"
        devshell_bin="$(< "$out/$(basename "$template")")/bin"
        ls -l "$devshell_bin"
        "$devshell_bin/menu"
    )
    done
)