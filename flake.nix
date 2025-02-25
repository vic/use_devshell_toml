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
        in
        {
          default = {
            type = "app";
            program = "${installer}/bin/install-direnv-lib";
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
