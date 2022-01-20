{ lib }:
let
  inherit (lib) mapAttrs mapAttrs' nameValuePair;
  inherit (lib) getAttr hasAttr hasPrefix hasSuffix;
  inherit (lib) removeSuffix filterAttrs;
  inherit (builtins) replaceStrings attrValues length;

  inherit (lib) pathIsRegularFile;
  inherit (builtins) readDir;
in rec {

  # Remove nils from a set.
  withoutNulls = _: v: v != null;

  # if check val then return val else abort
  passOrX = fn: { check, msg, val }: assert (check val) || fn msg; val;

  # if check val then return val else abort
  passOrAbort = passOrX abort;

  # if check val then return val else throw
  passOrThrow = passOrX throw;

  # check if a set has values
  attrsHasElements = x: (length (attrValues x)) != 0;

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
  existsOrDefault = x: attrs: default:
    if hasAttr x attrs then getAttr x attrs else default;

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
    in filterAttrs withoutNulls (processPaths (readDir path));
}
