{ system }:
{ config, lib, pkgs, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule raw bool nullOr; in {
    drives = mkOption {
      type = attrsOf (submodule (import ./../_partitioner/submodule.nix));
      description = lib.mdDoc ''
        Drives to install.
      '';
    };

    direct = mkOption {
      type = bool;
      default = true;
      description = lib.mdDoc ''
        Copy the store directly to the target partition.
        Setting this to false automatically substitutes on remote.
      '';
    };

    kexec.enable = lib.mkEnableOption "Use kexec to boot into a known installer.";
    kexec.config = mkOption {
      type = lib.types.nixosConfigWith {
        inherit system;
      };
      description = lib.mdDoc ''
        A nixos-system that is used as a rescue system.

        It works by kexec'ing a nixos-image and using it to install nixos over ssh.
      '';
    };

    config = mkOption {
      type = lib.types.nixosConfigWith {
        inherit system;
      };
      description = lib.mdDoc ''
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
        system.build.kexec_tarball_2 = lib.mkOverride 0 (pkgs.callPackage "${modulesPath}/lib/make-system-tarball.nix" {
          storeContents = [
            { object = config.system.build.kexec_script; symlink = "/kexec_nixos"; }
          ];
          contents = [];
        });
        kexec_bundle = pkgs.runCommand "kexec_bundle" {} ''
          cat \
            ${config.system.build.kexec_tarball_self_extract_script} \
            ${config.system.build.kexec_tarball_2}/tarball/nixos-system-${config.system.build.kexec_tarball_2.system}.tar.xz \
            > $out
          chmod +x $out
        '';
        system.extraDependencies = lib.mkOverride 70 [];
        networking.wireless.enable = lib.mkOverride 500 false;
        hardware.enableRedistributableFirmware = lib.mkOverride 70 false;
      };
    };
  };
}
