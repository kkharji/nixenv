{ mkUserHome }:
let
  injectHome = username: userConfig: {
    home-manager.users."${username}" = (mkUserHome userConfig);
  };

in {

  # Common, Applied with nixos and darwin.
  common = { lib, pkgs, config, user, ... }:
    let username = if lib.hasAttr "username" user then user.username else null;
    in {
      options.nixenv = {
        username = lib.mkOption {
          type = lib.types.str;
          default = username;
          description = "user's name";
        };

        shell = lib.mkOption {
          type = lib.types.package;
          default = pkgs.zsh;
          description = "user's shell";
        };

        # TODO: make sure it's either a path or a derivation
        home = lib.mkOption {
          # type =  lib.types.either lib.types.path (lib.types.functionTo lib.types.attrs);
          default = null;
          description = "function to initialize user in home-manager aspect.";
        };
      };
    };

  # Only Applied darwin system.
  darwin = { lib, pkgs, config, ... }: {
    config = lib.mkMerge [
      ({
        # Enable zsh in order to add /run/current-system/sw/bin to $PATH
        # TODO: should this be default??
        programs.zsh.enable = true;

        # Setup user user
        users = with config.nixenv; {
          users = {
            "${username}" = {
              description = "...";
              shell = shell;
              home = "/Users/${username}";
            };
          };
          # Do not allow users to be added or modified except through Nix configuration.
          # mutableUsers = false;
        };

        # nix.settings.trusted-users = [ "${config.nixenv.username}" ];
      })
      (lib.mkIf (!isNull config.nixenv.home)
        (injectHome config.nixenv.username config.nixenv.home))
      # (tryToInjectHome config.nixenv.username config.nixenv.home)
    ];
  };
}
