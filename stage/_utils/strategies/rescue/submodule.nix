{ system }:
{ config, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule raw; in {
    drives = mkOption {
      type = attrsOf (submodule (import ./../_partitioner/submodule.nix));
      description = ''
        Drives to install.
      '';
    };

    config = mkOption {
      type = lib.types.nixosConfigWith {
        inherit system;
      };
      description = ''
        The nixos-system to build
      '';
    };
  };
}
