#!/usr/bin/env bash
#
# Execute via: nix run .#test-templates

set -euo pipefail

out="$(mktemp -d)"
echo "Writing output to $out"

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
        direnv dump json > "$out/$(basename "$template").json"
        direnv exec "$PWD" menu > "$out/$(basename "$template").menu"
    )
    done
)