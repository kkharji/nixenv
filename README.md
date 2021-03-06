# NixEnv

Nix Flake Library to create Nix-based system regardless of system architecture or context. (EXPERIMENTAL)

## Status:

Working on Darwin. Further tests required.

## Concepts

- **Top-level Profiles/Hosts**: The main entry to the setup. This is mixed within
  profile directory, but unlike profiles it returns a derivation that will be
  injected.
- **Profile**: A collection of modules or configurations categorized by a profile.
  For example, a desktop profile might have only desktop related packages,
  modules, and/or configurations.
- **Module**: A set of options and processors for theses options. For example,
  an bash module might contain a set of options to control the bash environment
  + ways to set configuration based on the options provided in **Top-level
  Profiles/hosts**
- **Patches**: Same as modules in term of being injected to user environment,
  but unlike modules they directly override context options.
- **Packages**: additional packages not available in nixpkgs.
- **Overlays**: modifications to packages available in nixpkgs.

## Examples

- [My Personal setup](https://github.com/kkharji/system)


## Getting Started

### Detailed flake
```nix
{
  description = "My awesome Setup.";
  inputs = {
    # Required: Avoid following master to avoid breaking changes
    nixenv.url = "github:kkharji/nixenv/release-1.0";

    # Require: nixpkgs source.
    nixpkgs.url = "github:nixos/nixpkgs/master";

    # Require: home-manager source.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Require: darwin source.
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optional example Overlays:
    nur.url = "github:nix-community/nur";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";

    # Optional example packages
    mkalias.url = "github:reckenrode/mkalias";

    # Custom modules TODO: support
    base16.url = "github:kkharji/base16";
  };
  outputs = { self, ... }@inputs:
    inputs.nixenv.lib.commonSystem {
      inherit inputs;
      # Optional: List of context to generate for,
      # default: "homeManagerConfigurations" "nixosConfigurations"
      # "darwinConfigurations". Do not set empty!!!.
      context = [ ];

      # Optional: List of system to generate for, default all systems defined
      # in nixpkgs. Do not set empty!!!.
      systems = [ ];

      # List of overlays provided by packages such as neovim-nightly;
      overlays = [ inputs.nur.overlay inputs.neovim-nightly.overlay ];

      # List of external modules. modules key must provide home,darwin,common like local modules
      # NOTE: not support yet
      modules = [ inputs.base16.modules ];

      # EXPERIMENTAL: Injects variable called xpkgs to access x86 packages in
      # aarch64 systems. for when users can run the x86 packages and some
      # packages are not yet supported
      injectX86AsXpkgs = false;

      # List of additional packages to be made merge into system pkgs.
      packages = [ inputs.mkalias.packages ];

      # Optional: Nix Configuration
      configs.nix = {
        binaryCaches = [ "https://cachix.cachix.org" ];
        extraOptions = "experimental-features = nix-command flakes"; # This is the default.
      };

      # Optional: Nix-Darwin configuration
      configs.darwin = {
        # Required for multi-user installation.
        multi-user = false;
      };

      # Optional: NixPkgs Configuration
      configs.nixpkgs = { allowUnfree = true; };

      # Optional: Home-Manager Configuration
      configs.home-manager = { useGlobalPkgs = true; };

      # Roots doesn't have to exists to be defined here. define and create them later when you need them.
      # Where modules to be found.
      # NOTE!: modules are defined in keys { home, darwin, nixos, common };
      roots.modules = ./modules;

      # Where services are found. same as modules, but logical for services.
      roots.services = ./services;

      # Where patches to be found. Pretty much like modules, except it
      # directly modifies contexts in some way.
      # Do not return a derivation!, but similar to modules.
      roots.patches = ./patches;

      # Where profiles and top-level derivations to be found.
      # Profiles are an additional abstraction layer for grouping modules.
      # NOTE!: Profiles that return derivations will be used as top level profile. i.e. to setup system.
      roots.profiles = ./profiles;

      # Where overlays are found. overlay should return (final: prev: attrs)
      roots.overlays = ./overlays;

      # Where additional packages are to be found. Each file must export a
      # derivation that can be processed by typical callPackage function.
      roots.packages = ./packages;
    };
}
```

### Minimal flake:

```nix
{
  description = "Personal development and work environment.";
  inputs = {
    # Required: Avoid following master to avoid breaking changes
    nixenv.url = "github:kkharji/nixenv/release-1.0";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin";
    home-manager.url = ""github:nix-community/home-manager";
  };
  outputs = { self, ... }@inputs:
    inputs.nix-env.lib.commonSystem {
      inherit inputs;
      overlays = [ ];
      packages = [ ];
      configs = {
        nix.extraOptions = "experimental-features = nix-command flakes";
        nix.binaryCaches = [ "https://cachix.cachix.org" ];
        nixpkgs.allowUnfree = true;
        nix-darwin.multi-user = true;
        home-manager.useGlobalPkgs = true;
      };
      roots = {
        modules = ./modules;
        patches = ./patches;
        profiles = ./profiles;
        overlays = ./overlays;
        packages = ./packages;
      };
    };
}
```

## Example Profile
```nix
{ pkgs, ... }: {
  # Common Context i.e. darwin or nixos.

  # If this isn't defined, profile name will be used as username.
  nixenv.username = "kkharji";

  nixenv.home = { pkgs, ... }: {
    # Home Manager Context
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

## Credit

- [@EdenEast](https://github.com/EdenEast/nyx)

