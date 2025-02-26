{ pkgs, inputs, ... }:
let
  bat = pkgs.writeShellScriptBin "bat" "echo ${pkgs.lib.readFile inputs.file}";
in
{
  commands = [ { package = bat; } ];
}
