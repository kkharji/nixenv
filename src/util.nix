{ lib, vars }:
let
  inherit (vars) contextTypes;
  inherit (lib) isDerivation id types;
  inherit (lib) hasPrefix hasSuffix removeSuffix;
  inherit (lib) mapAttrs' mapAttrs mapAttrsToList;
  inherit (lib) mergeAttrs filterAttrs;
  inherit (lib.lists) any;
  inherit (lib) nameValuePair;
  inherit (lib) genAttrs getAttr hasAttr isAttrs attrValues;
  inherit (lib) pathIsRegularFile pathIsDirectory;
  inherit (builtins) length readDir replaceStrings;
in rec {
  inherit vars;

  # Remove nils from a set.
  withoutNulls = _: v: v != null;

  # Return true if a given val is of type path
  isPath = val: types.path.check val;

  # if check val then return val else abort
  passOrX = fn: { check, msg, val }: assert (check val) || fn msg; val;

  # if check val then return val else abort
  passOrAbort = passOrX abort;

  # if check val then return val else throw
  passOrThrow = passOrX throw;

  # check if a set has values
  attrsHasElements = x: (length (attrValues x)) != 0;

  # If given value is path then import it, else return it.
  importOrReturn = x: if (isPath x) then import x else x;

  # Check if a given path has default.nix
  hasDefaultFile = path: pathIsRegularFile (path + "/default.nix");

  # Call a function for each attribute in the given set and return
  # the result in a list.
  # source: @EdenEast
  # Example: firstOrDefault null "default" => "default"
  firstOrDefault = first: default: if !isNull first then first else default;

  # Call a function for each attribute in the given set and return
  # the result in a list.
  # source: @EdenEast
  # Example: existsOrDefault "name" {  } "default" => "default"
  existsOrDefault = key: attrs: default:
    if hasAttr key attrs then getAttr key attrs else default;

  # Given a path, and whether to import a given file return a list of imported
  # modules by the file/direcotry name or paths.
  #
  # Example:
  #  getNixPathsFromDir ./modules { } => { lf = { ... }; neovim = { ... };  ... }
  #  getNixPathsFromDir ./modules { withImport = false; } => { lf = /Users/tami5/system2/modules/lf;  ... }
  #  getNixPathsFromDir ./modules { withSelf = true; } => { modules = /Users/tami5/system2/modules/default.nix; ...}
  getNixPathsFromDir = path:
    { asPaths ? false, withSelf ? false, ... }:
    let
      # Partial function to check whether a given string is prefixed with default.
      hasDefaultPrefix = hasPrefix "default";
      # Partial function to check whether a given string ends with nix.
      hasNixSuffix = hasSuffix "nix";
      # Whether to keep default.nix in the root.
      keepSelf = n: (hasDefaultPrefix n) && withSelf || !(hasDefaultPrefix n);
      # Clean path name.
      pathName = name:
        if (name == "default.nix") then
          (baseNameOf path)
        else if (hasNixSuffix name) then
          (removeSuffix ".nix" name)
        else
          name;
      # Keep files that should be Included.
      processPaths = paths:
        mapAttrs' (name: type:
          let absPath = (path + "/${name}");
          in if
          # Ignore symlink and name prefixed with _ or .;
          (type != "symlink") && !(hasPrefix "_" name || hasPrefix "." name)
          # keep directories that has default file.
          && (if (type == "directory") then (hasDefaultFile absPath) else true)
          # keep nix files only and ignore others
          && (if (type == "regular") then (hasNixSuffix name) else true)
          # Keep root files when withSelf.
          && (if (type == "regular") then (keepSelf name) else true) then
          # If checks passes return absolutePaths;
            nameValuePair (pathName name)
            # If asPaths just return the path
            (if asPaths then absPath else (import absPath))
          else
            nameValuePair name null) paths;

    in if (pathIsDirectory path) then
      filterAttrs withoutNulls (processPaths (readDir path))
    else
      { };

  # Initialize Modules keys to functionss that can injected into
  # derivation contexts
  # Example: getModulesByCtx ./modules).home => {...}: { imports [...] };
  getModulesByCtx = let
    # Helper function to execute a transform function on each contextType
    eachCtx = genAttrs contextTypes;

    # Return derivation from a given module structure.
    asDrv = _: module: module.activate;

    # Return multi module style accessable by ctx name.
    multiModules = modules:
      let
        isMulti = _: a: isAttrs a && any id (map (c: hasAttr c a) contextTypes);
        m' = filterAttrs isMulti modules;
        m = ctx: filterAttrs (_: value: hasAttr ctx value) m';
      in eachCtx (ctx: mapAttrs (_: v: { activate = getAttr ctx v; }) (m ctx));

    # Return common stlye modules accessable by ctx name.
    commonModules = modules:
      let hasCtx = c: _: m: (isAttrs m) && (hasAttr "type" m) && m.type == c;
      in eachCtx (ctx: filterAttrs (hasCtx ctx) modules);

    # Return all modules accessable by ctx name,
    modulesByCtx' = modules:
      let
        common = commonModules modules;
        multi = multiModules modules;
      in eachCtx (ctx: mergeAttrs common."${ctx}" multi."${ctx}");

  in path:
  if (isPath path) then
    let
      modulesByCtx = modulesByCtx' (getNixPathsFromDir path { });
      imports = eachCtx (ctx: mapAttrsToList asDrv modulesByCtx."${ctx}");
    in {
      darwin = { ... }: { imports = imports.common ++ imports.darwin; };
      nixos = { ... }: { imports = imports.common ++ imports.nixos; };
      home = { ... }: { imports = imports.home; };
    }
  else {
    darwin = { ... }: { };
    nixos = { ... }: { };
    home = { ... }: { };
  };

  getUserProfiles = roots:
    let
      path = passOrAbort {
        check = types.path.check;
        msg = "Expected roots.profiles to be of type Path. Got something else";
        val = roots.profiles;
      };
      dirs = getNixPathsFromDir path { asPaths = true; };
    in passOrAbort {
      check = attrsHasElements;
      msg = "No Profiles found in ${toString path}";
      val = dirs;
    };

  getUserOverlays = roots:
    (if (hasAttr "overlays" roots) then
      let path = (getAttr "overlays" roots);
      in (attrValues (getNixPathsFromDir path { }))
    else
      [ ]);

  # TODO: Test
  getUserPackages = roots: pkgs:
    (if hasAttr "packages" roots then
      let
        path = (getAttr "packages" roots);
        paths = getNixPathsFromDir path { asPaths = true; };
      in mapAttrs (_: p: pkgs.callPackage p { }) paths
    else
      { });
}
