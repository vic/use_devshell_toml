# Usage: nix run .#demo

Output demo.gif
Set FontSize 13
Set Shell bash
Env PS1 "> "

Type "# No cargo command available"
Enter
Type "which cargo"
Enter

Type "# Add commands to devshell.toml"
Enter
Type "nix run github:vic/use_devshell_toml hello cargo python3 python3Packages.pip"
Enter

Wait@60s

Type "# cargo command is now in environment"
Enter
Type "cargo --version"
Enter

Type "cat .envrc"
Enter
Type "cat devshell.toml"
Enter

Sleep 5s 
