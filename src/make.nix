{ inputs, util, configs, modulesByCategory, ... }:
let
  inherit (inputs.nixpkgs.lib) mkIf;
  inherit (util) existsOrDefault;

  # Return function that can be used to inject and load home modules.
  mkUserHome = userConfig:
    { ... }: {

      imports = [ userConfig ];
      # For compatibility with nix-shell, nix-build, etc.
      home.file.".nixpkgs".source = inputs.nixpkgs;
      home.sessionVariables."NIX_PATH" =
        "nixpkgs=$HOME/.nixpkgs\${NIX_PATH:+:}$NIX_PATH";

    };
  # Built-in Module to handle profile setup.
  nixenvUser = import ./user.nix { inherit mkUserHome; };
in {

  homeManagerConfigurations = { system, user, pkgs, xpkgs }: {
    activationPackage = { };
    config = user.config;
    type = "Home";
  };

  nixosConfigurations = { system, user, pkgs, xpkgs }: {
    config = { system = { build = { toplevel = { type = "nixos"; }; }; }; };
    config' = user.config;
    type = "Nixos";
  };

  darwinConfigurations = { system, user, pkgs, xpkgs }:
    let specialArgs = { inherit system user pkgs xpkgs; };
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
            sharedModules = [
              modulesByCategory.modules.home
              modulesByCategory.profiles.home
              modulesByCategory.patches.home
              modulesByCategory.services.home
            ];
          };
        })
        (nixenvUser.common)
        (nixenvUser.darwin)
        (modulesByCategory.modules.darwin)
        (modulesByCategory.services.darwin)
        (modulesByCategory.profiles.darwin)
        (modulesByCategory.patches.darwin)
        (user.config)
      ];
    };

}
