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

        genConfigFlake = pkgs.writeShellScriptBin "gen-config-flake" ''
          FLAKE_TOML="$1"
          if test -e "$FLAKE_TOML"; then
            ${pkgs.nix}/bin/nix eval --file ${./lib/mkFlake.nix} --apply "f: f $FLAKE_TOML" --raw --impure --offline
          else
            cat ${./lib/emptyFlake.nix}
          fi
        '';

        genSourceFlake =
          let
            flake = pkgs.substitute {
              src = ./templates/devshell-toml/flake.nix;
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
          pkgs.writeShellScriptBin "gen-source-flake" ''
            SOURCE_DIR="$1"
            CONFIG_FLAKE="$2"
            ${pkgs.gnused}/bin/sed -e "s#SOURCE_URL#$SOURCE_DIR#; s#CONFIG_URL#$CONFIG_FLAKE#" ${flake}
          '';
      };

      apps = perSystem (
        { pkgs, ... }:
        {
          default = {
            type = "app";
            program = "${(libs pkgs).installer}/bin/install-direnv-lib";
          };

          gen-config-flake = {
            type = "app";
            program = "${(libs pkgs).genConfigFlake}/bin/gen-config-flake";
          };

          gen-source-flake = {
            type = "app";
            program = "${(libs pkgs).genSourceFlake}/bin/gen-source-flake";
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
                grep gen-config-flake $HOME/.config/direnv/lib/use_devshell_toml.sh
                grep gen-source-flake $HOME/.config/direnv/lib/use_devshell_toml.sh
                ${(libs pkgs).genConfigFlake}/bin/gen-config-flake ${./templates/${name}}/flake.toml > config.nix
                ${(libs pkgs).genSourceFlake}/bin/gen-source-flake FAKE_SOURCE FAKE_CONFIG > source.nix
                grep 'inputs.source.url = "path:FAKE_SOURCE"' source.nix
                grep 'inputs.config.url = "path:FAKE_CONFIG"' source.nix
                ${code}
              '';
            };

        in
        {
          formatting = (treefmt pkgs).config.build.check self;

          "templates/custom-inputs-overlays" = checkTemplate "custom-inputs-overlays" ''
            cat config.nix
            cat config.nix | grep inputs | grep 'url = "github:astro/deadnix";'
            cat config.nix | grep lib.overlays | grep 'deadnix = "default";'
          '';

          "templates/custom-nix-module" = checkTemplate "custom-nix-module" ''
            cat config.nix
            cat config.nix | grep 'inputs = { terraform = { url = "github:stackbuilders/nixpkgs-terraform"; }; };'
            cat config.nix | grep lib.overlays | grep 'terraform = "default";'
            cat config.nix | grep lib.nix-config | grep 'allowUnfree = true;'
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
