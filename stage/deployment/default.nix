{ ... }:
{
  imports = [
    ./nix
    ./nix-v3
    ./nix-copy
    ./files
  ];

  options = {
    deployments.concurrency = mkOption {
      description = lib.mdDoc ''
        How many parallel uploads should be performed?
      '';
      default = 4;
      type = int;
    };
  };
}
