{
  description =
    "Create common system regardless of system architecture or context.";

  outputs = { self, ... }: {
    lib.commonSystem = { roots, inputs, ... }@userArgs:
      let
        inherit (inputs.nixpkgs) lib;
        inherit (lib.attrsets) recursiveUpdate;

        vars = import ./src/vars.nix;
        util = import ./src/util.nix { inherit lib vars; };

        applyDefaults = recursiveUpdate {
          injectX86AsXpkgs = false;
          systems = vars.supportedSystems;
          contexts = vars.supportedContexts;
          configs.nix = {
            extraOptions = "experimental-features = nix-command flakes";
          };
          configs.nixpkgs = { };
          configs.home-manager = { };
          configs.nix-darwin = { };
          overlays = [ ];
          packages = [ ];
          modules = [ ];
        };
        args = applyDefaults userArgs;
        gen = import ./src/generators.nix { inherit inputs args util; };
      in {
        # Produce map of <system>.<context>.<profile>
        packages = with gen;
        # For Each System type:
          eachSystem (system:
            # and for each context:
            eachContext (context:
              # and for Each Profile:
              eachProfile (profile:
                let
                  user = userByProfile."${profile}";
                  make = makeByCtx."${context}";
                  pkgs = pkgsBySystem."${system}";
                  xpkgs = xpkgsBySystem.${system};
                in make { inherit system user pkgs xpkgs; })));
      };
  };
}
