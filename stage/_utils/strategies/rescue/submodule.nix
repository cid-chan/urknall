{ system }:
{ config, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule raw boolean; in {
    drives = mkOption {
      type = attrsOf (submodule (import ./../_partitioner/submodule.nix));
      description = ''
        Drives to install.
      '';
    };

    direct = mkOption {
      type = boolean;
      default = true;
      description = ''
        Copy the store directly to the target partition.
        Setting this to false automatically substitutes on remote.
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
