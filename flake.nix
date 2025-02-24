{
  outputs =
    inputs@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      formatter = lib.genAttrs lib.systems.flakeExposed (
        system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
      );

      defaultApp = lib.genAttrs lib.systems.flakeExposed (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};

          code = pkgs.substitute {
            src = ./direnv.bash;
            substitutions = [ 
              "--subst-var-by" "MAIN_FLAKE" ./. 
              "--subst-var-by" "TOML_FLAKE" ./templates/devshell-toml
            ];
          };

          program = pkgs.writeShellScriptBin "install-direnv-lib" ''
          mkdir -p $HOME/.config/direnv/lib
          ln -sfn ${code} $HOME/.config/direnv/lib/use_devshell_toml.sh
          '';
        in {
          type = "app";
          program = "${program}/bin/install-direnv-lib";
        }
      );

    in
    {
      inherit formatter defaultApp;

      lib.mkFlake = import ./lib/mkFlake.nix;
      lib.emptyFlake = builtins.readFile ./lib/emptyFlake.nix;

      templates = {
        default.path = ./templates/default;
        default.description = "Simple toml devshell";
      };
      
    };

}
