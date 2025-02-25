{
  outputs =
    inputs@{ nixpkgs, ... }:
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

      formatter = perSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);

      direnv_lib =
        pkgs:
        pkgs.substitute {
          src = ./direnv.bash;
          substitutions = [
            "--subst-var-by"
            "MAIN_FLAKE"
            ./.
            "--subst-var-by"
            "TOML_FLAKE"
            ./templates/devshell-toml
          ];
        };

      apps = perSystem (
        { pkgs, ... }:
        let
          installer = pkgs.writeShellScriptBin "install-direnv-lib" ''
            mkdir -p $HOME/.config/direnv/lib
            ln -sfn ${direnv_lib pkgs} $HOME/.config/direnv/lib/use_devshell_toml.sh
          '';

          genConfigFlake = pkgs.writeShellScriptBin "gen-config-flake" ''
          FLAKE_TOML="$1"
          if test -e "$FLAKE_TOML"; then
            nix eval --file ${./lib/mkFlake.nix} --apply "f: f $FLAKE_TOML" --raw --impure --offline
          else
            cat ${./lib/emptyFlake.nix}
          fi
          '';

          genSourceFlake = let 
            flake = pkgs.substitute {
              src = ./templates/devshell-toml/flake.nix;
              substitutions = [
                "--replace-fail"
                ''inputs.source.url = "path:empty"''
                ''inputs.source.url = "SOURCE_URL"''
                "--replace-fail"
                ''inputs.config.url = "path:empty"''
                ''inputs.config.url = "CONFIG_URL"''
              ];
            };
          in pkgs.writeShellScriptBin "gen-source-flake" ''
          SOURCE_DIR="$1"
          CONFIG_FLAKE="$2"
          sed -e "s#SOURCE_URL#path:$SOURCE_DIR#; s#CONFIG_URL#path:$CONFIG_FLAKE#" ${flake}
          '';
        in
        {
          default = {
            type = "app";
            program = "${installer}/bin/install-direnv-lib";
          };

          gen-config-flake = {
            type = "app";
            program = "${genConfigFlake}/bin/gen-config-flake";
          };

          gen-source-flake = {
            type = "app";
            program = "${genSourceFlake}/bin/gen-source-flake";
          };
        }
      );

    in
    {
      inherit formatter apps;

      lib.direnv_lib = direnv_lib;
      lib.mkFlake = import ./lib/mkFlake.nix;
      lib.emptyFlake = builtins.readFile ./lib/emptyFlake.nix;

      templates = {
        default.path = ./templates/default;
        default.description = "Simple toml devshell";
      };

    };

}
