{ config, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule raw; in {
    drives = mkOption {
      type = attrsOf (submodule (import ./../_partitioner/submodule.nix));
      description = ''
        Drives to install.
      '';
    };

    nixosSystem = mkOption {
      type = raw;
      description = ''
        The nixos-system to build
      '';
    };
  };
}
