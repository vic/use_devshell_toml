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
          runtimeInputs = with pkgs; [ ];
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

        genFlakes =
          let
            flake = pkgs.substitute {
              src = ./lib/devshell-flake.nix;
              substitutions = [
                "--replace-fail"
                ''inputs.source.url = "path:empty"''
                ''inputs.source.url = "path:SOURCE_URL"''
                "--replace-fail"
                ''inputs.config.url = "path:empty"''
                ''inputs.config.url = "path:CONFIG_URL"''
              ];
            };
          in
          pkgs.writeShellScriptBin "gen-flakes" ''
            export PATH="${
              with pkgs;
              lib.makeBinPath [
                coreutils
                gnused
                nix
              ]
            }"

            SOURCE_DIR="$1"
            SOURCE_FLAKE="$2"

            mkdir -p "$SOURCE_FLAKE/config"

            if test -e "$SOURCE_DIR/flake.toml"; then
              nix eval --file ${./lib/make-config-flake.nix} --apply "f: f $SOURCE_DIR/flake.toml" --raw --impure --offline | \
                sed -e "s#url = \"path:./#url = \"path:$SOURCE_DIR/#g" > "$SOURCE_FLAKE/config/flake.nix"
            else
              cp -f ${./lib/empty-config-flake.nix} "$SOURCE_FLAKE/config/flake.nix"
            fi

            sed -e "s#SOURCE_URL#$SOURCE_DIR#; s#CONFIG_URL#$SOURCE_FLAKE/config#" ${flake} > "$SOURCE_FLAKE/flake.nix"
          '';
      };

      apps = perSystem (
        { pkgs, ... }:
        {
          default = {
            type = "app";
            program = "${(libs pkgs).app}/bin/app";
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
