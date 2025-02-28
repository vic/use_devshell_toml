{
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs =
    {
      nixpkgs,
      treefmt-nix,
      self,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      perSystem =
        f:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      treefmt =
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.nixfmt.excludes = [ ".direnv" ];
          programs.deadnix.enable = true;
        };

      formatter = perSystem ({ pkgs, ... }: (treefmt pkgs).config.build.wrapper);

      libs = pkgs: rec {
        direnv_bash = pkgs.substitute {
          src = ./direnv.bash;
          substitutions = [
            "--subst-var-by"
            "MAIN_FLAKE"
            ./.
          ];
        };

        installer = pkgs.writeShellScriptBin "install" ''
          mkdir -p $HOME/.config/direnv/lib
          ln -sfn ${direnv_bash} $HOME/.config/direnv/lib/use_devshell_toml.sh
          echo "Installed use_devshell_toml.sh on direnv lib."
        '';

        app = pkgs.writeShellApplication {
          name = "app";
          text = ''
            if ! test -e "$HOME/.config/direnv/lib/use_devshell_toml.sh"; then
              ${installer}/bin/install
            fi

            test -z "''${1:-}" && exit 0 # terminate if no package names were given

            for package in "''${@:-}"; do
              echo "Adding package '$package' to devshell.toml"
              printf '\n[[commands]]\npackage = "%s"\n' "$package" >> devshell.toml
            done

            if ! test -e "$PWD/.envrc"; then
              echo "use devshell_toml" > "$PWD/.envrc"
            fi

            direnv allow
          '';
        };

        demo = pkgs.writeShellApplication {
          name = "demo";
          text = ''
            set -a
            export BASE="$PWD"
            export PATH="${
              with pkgs;
              lib.makeBinPath [
                vhs
                nix
                direnv
                coreutils
                which
                bash
              ]
            }"
            HOME="$(mktemp -d)"
            export HOME
            cd "$HOME"
            mkdir -p "$HOME/.config/nix"
            echo "extra-experimental-features = nix-command flakes" > "$HOME/.config/nix/nix.conf"
            direnv hook bash > .hook
            # shellcheck source=/dev/null
            source .hook
            vhs "$BASE/demo.tape"
            cp -f "$PWD/demo.gif" "$BASE/demo.gif"
          '';
        };

        genFlakes = pkgs.writeShellApplication {
          name = "gen-flakes";
          runtimeInputs = with pkgs; [
            coreutils
            gnused
            nix
          ];
          text = ''
            SOURCE_DIR="$1"
            FLAKE_DEST="$2"

            mkdir -p "$FLAKE_DEST/config"
            sed -e "s#path:./source#path:$SOURCE_DIR#" ${./lib/devshell-flake.nix} > "$FLAKE_DEST/flake.nix"

            if test -e "$SOURCE_DIR/flake.toml"; then
              nix eval \
                --file ${./lib/make-config-flake.nix} \
                --apply "f: f $SOURCE_DIR/flake.toml" \
                --extra-experimental-features "flakes nix-command" \
                --raw --impure --offline |\
                sed -e "s#url = \"path:./#url = \"path:$SOURCE_DIR/#g" > "$FLAKE_DEST/config/flake.nix"
            else
              cp -f ${./lib/empty-config-flake.nix} "$FLAKE_DEST/config/flake.nix"
            fi
          '';
        };
      };

      apps = perSystem (
        { pkgs, ... }:
        {
          default = {
            type = "app";
            program = "${(libs pkgs).app}/bin/app";
          };

          demo = {
            type = "app";
            program = "${(libs pkgs).demo}/bin/demo";
          };

          install = {
            type = "app";
            program = "${(libs pkgs).installer}/bin/install";
          };

          gen-flakes = {
            type = "app";
            program = "${(libs pkgs).genFlakes}/bin/gen-flakes";
          };

          test-templates =
            let
              app =
                with pkgs;
                writeShellApplication {
                  name = "test-templates";
                  runtimeInputs = [
                    direnv
                    nix
                    coreutils
                    jq
                  ];
                  text = lib.readFile ./test-templates.bash;
                };
            in
            {
              type = "app";
              program = "${app}/bin/test-templates";
            };
        }
      );

      checks = perSystem (
        { pkgs, ... }:
        {
          formatting = (treefmt pkgs).config.build.check self;
        }
      );

    in
    {
      inherit formatter apps checks;

      templates = {
        default.path = ./templates/default;
        default.description = "Simple toml devshell";
      };

    };

}
