{ inputs, util, args, ... }:
let
  inherit (inputs.nixpkgs.lib) attrNames genAttrs;
  inherit (args) configs overlays packages systems contexts roots;
  inherit (util) existsOrDefault;
  inherit (util) getUserProfiles getUserOverlays getModulesByCtx;

  profiles = getUserProfiles roots;

in rec {
  # Generators
  eachProfile = genAttrs (attrNames profiles);
  eachCategory = genAttrs [ "modules" "profiles" "patches" ];
  eachSystem = genAttrs systems;
  eachContext = genAttrs contexts;

  # Modules By Cateogry
  modulesByCategory = eachCategory
    (category: getModulesByCtx (existsOrDefault category roots null));

  # Overlays by given system
  overlaysBySystem = eachSystem (system:
    let
      user-overlays = getUserOverlays roots;
      extrn-packages = (map (p: (_: prev: p."${system}" // prev)) packages);
    in overlays ++ user-overlays ++ extrn-packages);

  # Packages by given system
  pkgsBySystem = eachSystem (system:
    import inputs.nixpkgs {
      inherit system;
      config = configs.nixpkgs;
      overlays = overlaysBySystem."${system}";
    });

  # User by profile name
  userByProfile = eachProfile (profileName: {
    username = profileName;
    config = import profiles."${profileName}";
  });

  # Make Function by Context
  makeByCtx =
    import ./make.nix { inherit inputs util configs modulesByCategory; };
}
