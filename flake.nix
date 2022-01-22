{
  description =
    "Create common system regardless of system architecture or context.";

  inputs = {
    nixpkgs.url =
      "github:nixos/nixpkgs?rev=f42a9e258664bf1cabae305275143384e959ed09";
    nix-darwin.url =
      "github:lnl7/nix-darwin?rev=bcdb6022b3a300abf59cb5d0106c158940f5120e";
    home-manager.url =
      "github:nix-community/home-manager?rev=7eb5106548eaab99ebeb21c87f93092de54fe931";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      vars = import ./src/vars.nix;
      util = import ./src/util.nix { inherit lib vars; };
      applyDefaults = args:
        lib.attrsets.recursiveUpdate {
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
        } args;
    in {

      lib.commonSystem = { roots, ... }@userArgs:
        let
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
                    make = makeByCtx."${context}";
                    pkgs = pkgsBySystem."${system}";
                    user = userByProfile."${profile}";
                  in make { inherit system pkgs user; })));
        };
    };
}
