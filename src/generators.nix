{ inputs, util, args, ... }:
let
  inherit (inputs.nixpkgs.lib) attrNames genAttrs mkIf lists;
  inherit (inputs.nixpkgs.lib.strings) replaceStrings hasPrefix;
  inherit (args)
    configs overlays packages systems contexts roots injectX86AsXpkgs;
  inherit (util) existsOrDefault;
  inherit (util)
    getUserProfiles getUserOverlays getModulesByCtx getUserPackages;

  profiles = getUserProfiles roots;
in rec {
  # Generators
  eachProfile = genAttrs (attrNames profiles);
  eachCategory = genAttrs [ "modules" "profiles" "patches" "services" ];
  eachSystem = genAttrs systems;
  eachContext = genAttrs contexts;

  # modules = [ inputs.base16.modules ];
  extrnModules = genAttrs util.vars.contextTypes
    (c: (map (v: (existsOrDefault "${c}" v ({ ... }: { }))) args.modules));

  # Modules By Cateogry
  modulesByCategory = eachCategory
    (category: getModulesByCtx (existsOrDefault category roots null));

  # Overlays by given system
  overlaysBySystem = eachSystem (system:
    let
      user-overlays = getUserOverlays roots;
      user-packages = getUserPackages roots pkgsBySystem."${system}";
      extrn-packages = (map (p: (_: prev: p."${system}" // prev)) packages);
    in overlays ++ user-overlays ++ extrn-packages
    ++ [ (_: _: user-packages) ]);

  # Packages by given system
  pkgsBySystem = eachSystem (system:
    import inputs.nixpkgs {
      inherit system;
      config = configs.nixpkgs;
      overlays = overlaysBySystem."${system}";
    });

  # Temporary: Get x86_64 equivalent packages
  xpkgsBySystem = eachSystem (system:
    if injectX86AsXpkgs && (hasPrefix "aarch64" system) then
      pkgsBySystem."${(replaceStrings [ "aarch64" ] [ "x86_64" ] system)}"
    else
      { });

  # User by profile name
  userByProfile = eachProfile (profileName: {
    username = profileName;
    config = import profiles."${profileName}";
  });

  # Make Function by Context
  makeByCtx = import ./make.nix {
    inherit inputs util configs modulesByCategory extrnModules;
  };
}
