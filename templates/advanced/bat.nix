{pkgs, ...}: let 
  bat = pkgs.writeShellScriptBin "bat" "echo BAT";
in {
  commands = [ { package = bat; } ];
}