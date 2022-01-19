# Nix-Env

(EXPERIENTIAL): Nix Flake Library to create Nix-based system regardless of system architecture or context.


## Getting Started

```nix
{
  description = "My awesome Setup.";
  inputs = {
    # Optional: To show how to override nixenv sources
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    darwin.url = "github:lnl7/nix-darwin/master";

    nixenv.url = "github:tami5/nix-env"
    # Optional: Changes sources
    nixenv.inputs.nixpkgs.follows = "nixpkgs"
    nixenv.inputs.home-manager.follows = "home-manager"
    nixenv.inputs.darwin.follows = "darwins"

    # Example Overlay: Nix User Repository: Extra pacakges
    nur.url = "github:nix-community/nur";
    nur.inputs.nixpkgs.follows = "nixpkgs";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, ... }@inputs:
    let
      inherit (inputs.nixenv.lib) initialize;
      in initialize {
        # List of system to generate for, default all systems defined in nixpkgs.
        systems = [];
        # List of context to generate for, default "homeManagerConfigurations" "nixosConfigurations" "darwinConfigurations"
        contexts = [];
        # Addtional overlays provided by packages such as neovim-nightly;
        overlays = [ nur.overlay neovim-nightly.overlay ];
        # Required paths for NixEnv to do it's magic
        paths = {
          # Where modules to be found.
          # NOTE!: modules are defined in keys { home, darwin, nixos, common };
          modules = ./modules;

          # Where patches to be found. Pretty much like modules, execpt it
          # directly modifies contexts in some way.
          # Do not return a derivation!, but similar to modules.
          patches = ./patches;

          # Where profiles and top-level derivations to be found.
          # Profiles are where modules and patches are used.
          # NOTE!: Profiles return Derivation are used as top level derivation
          # otherwise something similar to modules. (see modules)
          profiles = ./profiles;

          # Where overlays are found. overlay should return (final: prev: attrs)
          overlays = ./overlays;

          # Where addtional packages are to be found Files here Common callPackage argument
          packages = ./packages;
        };
    };
}
```

## Usage

Build main profile, or `./<profiles-path>/main` `./<profiles-path>/main.nix`

```bash
# Build nixos system
nix build .\#nixosConfigurations.main

# Build home-manager
nix build .\#homeManagerConfigurations.main

# Build darwin
nix build .\#darwinConfigurations.main
```
