{ lib, util, vars, ... }:
let
  inherit (vars) contextTypes;
  inherit (lib) id types;
  inherit (lib) genAttrs getAttr hasAttr isAttrs nameValuePair;
  inherit (lib) mergeAttrs filterAttrs mapAttrs;
  inherit (lib) listToAttrs mapAttrsToList;
  inherit (lib.lists) any;
  inherit (util) isPath attrsHasElements getNixPathsFromDir;
in {
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
}
