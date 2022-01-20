# Nix-Env

(EXPERIENTIAL): Nix Flake Library to create Nix-based system regardless of system architecture or context.


## Getting Started

```nix
{
  description = "My awesome Setup.";

  inputs = {
    # Required
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    darwin.url = "github:lnl7/nix-darwin/master";
    nix-env.url = "github:tami5/nix-env";

    # Example Overlay: Nix User Repository: Extra pacakges
    nur.url = "github:nix-community/nur";
    nur.inputs.nixpkgs.follows = "nixpkgs";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly.inputs.nixpkgs.follows = "nixpkgs";

    # Example pacakges
    mkalias.url = "github:reckenrode/mkalias";
  };

  outputs = { self, ... }@inputs:
    let inherit (inputs.nix-env.lib) commnSystem;
    in commonSystem {
      # Nix-Darwin Source
      darwin.source = self.inputs.darwin;

      # Nix Configuration.
      nix-config = {
        binaryCaches =
          [ "https://cachix.cachix.org" "https://nix-community.cachix.org" ];
        extraOptions = "experimental-features = nix-command flakes";
      };

      # NixPkgs source and configuration
      nixpkgs = {
        source = self.inputs.nixpkgs;
        allowUnfree = true;
      };

      # Home-Manager Configuration
      home-manager = {
        source = self.inputs.home-manager;
        useGlobalPkgs = true;
        # NOTE: aviod setting up users.
      };

      options = {
        # List of system to generate for, default all systems defined in nixpkgs
        systems = [ ];

        # List of pacakges to be made merge into system pkgs.
        packages = [ inputs.mkalias.packages ];

        # List of context to generate for, default "homeManagerConfigurations"
        # "nixosConfigurations" "darwinConfigurations"
        contexts = [ ];

        # Addtional overlays provided by packages such as neovim-nightly;
        overlays = [ nur.overlay neovim-nightly.overlay ];
      };

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

        # Where addtional packages are to be found. Each file must export a
        # derivation that can be processed by typeical callPackage function.
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
