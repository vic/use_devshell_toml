{ pkgs, ... }:
{
  commands = [ { package = pkgs.terraform-versions."1.9.8"; } ];
}
