{
  inputs.devshell.url = "github:numtide/devshell";

  inputs.source.url = "path:empty";
  inputs.source.flake = false;

  inputs.config.url = "path:empty";

  outputs =
    inputs@{ ... }:
    let
      toml-file = "${inputs.source.outPath}/devshell.toml";

      ins = inputs // inputs.config.inputs;
      nixpkgs = ins.nixpkgs;

      perSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      devShells = perSystem (
        system:
        let

          nix-config = ins.config.lib.nix-config or { };
          overlays-config = ins.config.lib.overlays or [ ];
          attr-overlay = name: value: [ ins.${name}.overlays.${value} ];
          overlays = with nixpkgs.lib; flatten (map (mapAttrsToList attr-overlay) overlays-config);

          pkgs = import nixpkgs (
            nix-config
            // {
              inherit system;
              overlays = [ ins.devshell.overlays.default ] ++ overlays;
            }
          );

          default = pkgs.devshell.mkShell {
            _module.args = {
              inputs = ins;
            };
            imports = [ (pkgs.devshell.importTOML toml-file) ];
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
