{ inputs, util, configs, modulesByCategory, ... }:
let
  inherit (inputs.nixpkgs.lib) mkIf;
  inherit (util) existsOrDefault;

  # Return function that can be used to inject and load home modules.
  mkUserHome = userConfig:
    { ... }: {
      imports = [
        modulesByCategory.modules.home
        modulesByCategory.profiles.home
        modulesByCategory.patches.home
        userConfig
      ];
    };
  # Built-in Module to handle profile setup.
  nixenvUser = import ./user.nix { inherit mkUserHome; };
in {

  homeManagerConfigurations = { system, user, pkgs }: {
    activationPackage = { };
    config = user.config;
    type = "Home";
  };

  nixosConfigurations = { system, user, pkgs }: {
    config = { system = { build = { toplevel = { type = "nixos"; }; }; }; };
    config' = user.config;
    type = "Nixos";
  };

  darwinConfigurations = { system, user, pkgs }:
    let specialArgs = { inherit system user pkgs; };
    in inputs.nix-darwin.lib.darwinSystem {
      inherit system specialArgs;
      modules = [
        ({ pkgs, ... }: {
          services.nix-daemon.enable = mkIf configs.nix-darwin.multi-user true;
          # Don't rely on the configuration to enable a flake-compatible version of Nix.
          nix = configs.nix // { package = pkgs.nixFlakes; };
        })
        (inputs.home-manager.darwinModules.home-manager)
        ({
          home-manager = configs.home-manager // {
            extraSpecialArgs = specialArgs;
          };
        })
        (nixenvUser.common)
        (nixenvUser.darwin)
        (modulesByCategory.modules.darwin)
        (modulesByCategory.profiles.darwin)
        (modulesByCategory.patches.darwin)
        (user.config)
      ];
    };

}

