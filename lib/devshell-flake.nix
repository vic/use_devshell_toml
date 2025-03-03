{

  inputs.systems.url = "github:nix-systems/default";
  inputs.devshell.url = "github:numtide/devshell";

  inputs.source.url = "path:./source";
  inputs.source.flake = false;

  inputs.devshell_toml.url = "path:./devshell.toml";
  inputs.devshell_toml.flake = false;

  inputs.config.url = "path:./config";

  outputs =
    inputs@{
      # deadnix: skip
      nixpkgs,
      ...
    }:
    let
      ins = inputs // inputs.config.inputs;

      devshell_toml =
        if builtins.pathExists ins.source then "${ins.source}/devshell.toml" else ins.devshell_toml;

      nixpkgs = ins.nixpkgs or ins.devshell.inputs.nixpkgs;
      perSystem = nixpkgs.lib.genAttrs (import ins.systems);

      nix-config = ins.config.lib.nix-config or { };
      overlays-config = ins.config.lib.overlays or [ ];
      attr-overlay = name: value: [ ins.${name}.overlays.${value} ];
      overlays = with nixpkgs.lib; flatten (map (mapAttrsToList attr-overlay) overlays-config);

      devShells = perSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = nix-config;
            overlays = [ ins.devshell.overlays.default ] ++ overlays;
          };

          default = pkgs.devshell.mkShell {
            _module.args = {
              inputs = ins;
            };
            imports = [ (pkgs.devshell.importTOML devshell_toml) ];
          };
        in
        {
          inherit default;
        }
      );
    in
    {
      inherit devShells;
    };
}
