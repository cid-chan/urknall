{ lib, ... }:
{
  imports = [
    ./nix
    ./nix-v3
    ./nix-copy
    ./files
  ];

  options = let inherit (lib) mkOption; inherit (lib.types) int; in {
    deployments.concurrency = mkOption {
      description = lib.mdDoc ''
        How many parallel uploads should be performed?
      '';
      default = 4;
      type = int;
    };
  };
}
