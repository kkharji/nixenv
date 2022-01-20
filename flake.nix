{
  description = ''
    Functions to create Nix-based system regardless of system
    architecture or context.
  '';
  outputs = { self }: { lib = import ./src; };
}
