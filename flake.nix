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

      libs = pkgs: {
        direnv_fun = pkgs.substitute {
          src = ./direnv.bash;
          substitutions = [
            "--subst-var-by"
            "MAIN_FLAKE"
            ./.
          ];
        };

        installer = pkgs.writeShellScriptBin "install-direnv-lib" ''
          mkdir -p $HOME/.config/direnv/lib
          ln -sfn ${(libs pkgs).direnv_fun} $HOME/.config/direnv/lib/use_devshell_toml.sh
        '';

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
              nix eval --file ${./lib/make-config-flake.nix} --apply "f: f $SOURCE_DIR/flake.toml" --raw --impure --offline > "$SOURCE_FLAKE/config/flake.nix"
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
            program = "${(libs pkgs).installer}/bin/install-direnv-lib";
          };

          gen-flakes = {
            type = "app";
            program = "${(libs pkgs).genFlakes}/bin/gen-flakes";
          };
        }
      );

      checks = perSystem (
        { pkgs, ... }:
        let
          checkTemplate =
            name: code:
            pkgs.stdenvNoCC.mkDerivation {
              inherit name;
              phases = [ "check" ];
              check = ''
                set -v
                mkdir $out
                cd $out
                export PATH=${
                  with pkgs;
                  lib.makeBinPath [
                    nix
                    coreutils
                    gnugrep
                  ]
                }
                export HOME=$out
                mkdir -p $HOME/.config/nix
                echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
                ${(libs pkgs).installer}/bin/install-direnv-lib
                test -f $HOME/.config/direnv/lib/use_devshell_toml.sh
                grep gen-flakes $HOME/.config/direnv/lib/use_devshell_toml.sh
                ${(libs pkgs).genFlakes}/bin/gen-flakes "${./templates/${name}}" "$PWD"
                cat flake.nix
                grep "inputs.source.url = \"path:${./templates/${name}}\"" flake.nix
                grep "inputs.config.url = \"path:$PWD/config\"" flake.nix
                ${code}
              '';
            };

        in
        {
          formatting = (treefmt pkgs).config.build.check self;

          "templates/custom-inputs-overlays" = checkTemplate "custom-inputs-overlays" ''
            ls -la *
            cat config/flake.nix
            cat config/flake.nix | grep inputs | grep 'url = "github:astro/deadnix";'
            cat config/flake.nix | grep lib.overlays | grep 'deadnix = "default";'
          '';

          "templates/custom-nix-module" = checkTemplate "custom-nix-module" ''
            cat config/flake.nix
            cat config/flake.nix | grep 'inputs = { terraform = { url = "github:stackbuilders/nixpkgs-terraform"; }; };'
            cat config/flake.nix | grep lib.overlays | grep 'terraform = "default";'
            cat config/flake.nix | grep lib.nix-config | grep 'allowUnfree = true;'
          '';
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
