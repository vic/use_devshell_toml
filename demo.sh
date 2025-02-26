# Expected to be sourced in an isolated shell by `vhs demo.tape`
export HOME="$(mktemp -d)"
cd $HOME
eval "$(direnv hook bash)"
