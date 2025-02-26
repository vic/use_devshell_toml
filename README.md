# `use devshell_toml` 

This repository provides a [direnv] function that allows 
you to load [devshell] TOML environments
without you writting a single line of Nix code. (see [motivation](#motivation))

![demo](https://github.com/user-attachments/assets/d573e297-9f81-49c4-984d-51431fe96118)


# Quick Usage

Just run this flake giving it as many [packages](https://search.nixos.org/packages) you need.

```
nix run github:vic/use_devshell_toml [package ...]
```

It will make sure the `use_devshell_toml.sh` function is installed into your direnv lib, and 
will update `devshell.toml` and `.envrc` in current directory.

The gif demo above shows this by adding `hello`, `cargo` and `pip` commands in a single command.

Be sure to checkout [devshell] documentation for more info on how to customize your environment. 

> That's it. Just a TOML file, no need for you to write a single line of Nix code.

# Manual Setup

#### Install/Update the direnv function.

The following line will install a function in your direnv stdlib directory (`$HOME/.config/direnv/lib/use_devshell_toml.sh`).

```bash
# You might change ref to any branch or release version.
nix run "github:vic/use_devshell_toml?ref=main#install"
```

After installation, any `.envrc` file of yours can run `use devshell_toml`.

#### Setup your working project

Create a simple `devshell.toml` and `.envrc` on your current directory.

```toml
# devshell.toml
[[commands]]
package = "hello"  # see https://numtide.github.io/devshell/
```

```bash
# .envrc
use devshell_toml
```

Alternatively you can use the following template to create both of them:

```bash
nix flake init -t github:vic/use_devshell_toml
```

# Advanced Usage

You can get pretty far without having to write a single nix line. All this features document
how to add more power to your environment by just adding a `flake.toml` file.

Both `devshell.toml` and `flake.toml` will be watched by `direnv` and your environment will be reloaded
upon any changes on them. You can always `devshell reload` manually if needed.

##### Adding third-party flake inputs

This example `flake.toml` shows how to override the `nixpkgs` and `devshell` inputs.
In the same way you can add any other flake input (or non-flake) you might need.

```toml
# flake.toml -- schema is same as flake.nix inputs

[inputs.nixpkgs]
url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable" # a custom nixpkgs branch

[inputs.devshell]
url = "github:numtide/devshell"
inputs.nixpkgs.follows = "nixpkgs" # make it depend on the previous nixpkgs branch

[inputs.something]
url = "path:./something" # use path:./ for relative dependencies
flake = false # something that is not a flake itself
```

##### Enabling third-party Overlays

If you find a flake that provides custom packages via an overlay, you can add include
them in your project allowing you to use those tools.

```toml
# flake.toml

[inputs.something]
url = "github:someorg/something"
[inputs.anotherthing]
url = "github:someorg/anotherting"

[[overlays]]
something = "default" # includes overlays.default from the something input

[[overlays]]
anotherthing = "foo"  # includes overlays.foo from the anotherthing input

[[overlays]]
anotherthing = "bar"  # also includes overlays.bar from the anotherthing input
```

```toml
# devshell.toml
[[commands]]
package = "foo" # uses the foo package provided by the anotherthing overlay.
```


##### Custom nix config

Sometimes it might be helpful to set some nix config while loading your environment.
For example allowing unfree packages or adding nix caches.

```toml
# flake.toml

[nix-config]
allowUnfree = true
extra-substituters = "https://some-nix-cache.org"
extra-trusted-public-keys = "some-nix-cache.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" 
```

##### Importing devshell nix-modules.

[devshell] TOML files allow you to import other TOML-modules or Nix-syntax modules. The later
ones are ofcourse more powerful, if you are willing to write simple nix expressions. As they
allow you to customize packages themselves or access your flake inputs directly.

```toml
# devshell.toml -- See https://numtide.github.io/devshell/extending.html
imports = [ "./mill.nix" ] # Imports should always be the first line in the TOML file.
```

```nix
# mill.nix -- See https://numtide.github.io/devshell/modules_schema.html
{inputs, pkgs, ...}: let
  jre = pkgs.graalvm-ce;
  mill = pkgs.mill.override { inherit jre; } # use a custom JVM
in {
  commands = [ { package = mill; } ];  # provide the mill command to the environment
}
```

##### The Eject button

If you need more power, maybe your project is ready to contain a `flake.nix` itself.
Don't worry we all knew the time would come.
The easiest way is to use [devshell's toml template](https://github.com/numtide/devshell/tree/main/templates/toml).

```bash
nix flake init -t github:numtide/devshell#toml
```

# Motivation

Many times I'm checking-out other people's repositories and just need a quick way to setup the required environment to work on them.
However, they might not have any `flake.nix` nor `shell.nix` files on them, and maybe I'm not even trying to add them myself to their
repository, but just want a quick way to have those tools available for me.

Since I'm already using `direnv` system wide, I just wanted to edit a simple `devshell.toml` file and get my env loaded without 
thinking about adding any nix files to the repo.

Many modern nix environment-tools are trying to use popular configuration languages (`json`, `toml`) in order to attract people who are not
as familiar with the nix-language. Allowing them to take advantage of the all nix packages from the comfort of simpler languages.

Since [devshell] already has excellent support for loading TOML files, this project only tries to make it as quick as it can get for
people already using [direnv]. Without them having to write any nix plumbing code, just edit `devshell.toml` on the current directory.


#### Upsides

- Quick, edit-toml-and-forget environments.
- All the advanced features provided by devshell and nixpkgs.
- Extensible, first via toml and later growing into proper nix code.

#### Downsides

- Flake is generated in hidden `.direnv/devshell-flake` directory whenever the user enters the project root.
- Since flake is generated in a git ignored dir, sometimes you might need to `rm -rf .direnv && direnv allow` to fully reload.


[direnv]: https://direnv.net
[devshell]: https://numtide.github.io/devshell
