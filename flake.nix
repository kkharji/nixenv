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

  outputs = { self, ... }@inputs: {
    lib = { commonSystem = import ./src { inherit inputs; }; };
  };
}
