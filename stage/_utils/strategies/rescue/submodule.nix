{ system }:
{ config, lib, pkgs, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule raw bool nullOr; in {
    drives = mkOption {
      type = attrsOf (submodule (import ./../_partitioner/submodule.nix));
      description = ''
        Drives to install.
      '';
    };

    direct = mkOption {
      type = bool;
      default = true;
      description = ''
        Copy the store directly to the target partition.
        Setting this to false automatically substitutes on remote.
      '';
    };

    kexec.enable = lib.mkEnableOption "Use kexec to boot into a known installer.";
    kexec.config = mkOption {
      type = lib.types.nixosConfigWith {
        inherit system;
      };
      description = ''
        A nixos-system that is used as a rescue system.

        It works by kexec'ing a nixos-image and using it to install nixos over ssh.
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

  config = {
    kexec.config = {modulesPath, ...}: {
      imports = [
        lib.urknall.urknall-inputs.nixos-generators.nixosModules.kexec-bundle
        "${modulesPath}/profiles/minimal.nix"
      ];

      config = {
        system.build.kexec_tarball = lib.mkForce (pkgs.callPackage "${lib.urknall.urknall-inputs.nixpkgs.outPath}/nixos/lib/make-system-tarball.nix" {
          storeContents = [
            { object = config.system.build.kexec_script; symlink = "/kexec_nixos"; }
          ];
          contents = [];
        });
        system.extraDependencies = lib.mkOverride 70 [];
        networking.wireless.enable = lib.mkOverride 500 false;
        hardware.enableRedistributableFirmware = lib.mkOverride 70 false;
      };
    };
  };
}
