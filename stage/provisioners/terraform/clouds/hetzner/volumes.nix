{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;

  stripDc = value:
    builtins.head (lib.splitString "-" value);
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule str int; in {
    provisioners.terraform.clouds.hcloud.volumes = mkOption {
      description = ''
        A set of additional volumes to create.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = config._module.args.name;
            description = ''
              The name of the server.
            '';
          };

          id = mkOption {
            type = str;
            readOnly = true;
            default = "hcloud_volume.${config.name}";
            description = ''
              ID in the terraform config
            '';
          };

          datacenter = mkOption {
            type = str;
            default = "fsn1-dc14";
            description = ''
              The datacenter the place the volume in
            '';
          };

          diskPath = mkOption {
            type = str;
            readOnly = true;
            description = ''
              The disk path of the extra volume.
            '';
          };

          size = mkOption {
            type = int;
            default = 10;
            description = ''
              The size of the volume in GB.
            '';
          };
        };

        config = {
          diskPath = "/dev/disk/by-id/scsi-0HC_Volume_${outputs."hcloud_volume_${config.name}_id".future}";
        };
      }));
      default = {};
      example = {
        volume_name = {
          datacenter = "fsn1-dc14";
          size = 20;
        };
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: volume: ''
      resource "hcloud_volume" "${volume.name}" {
        size = ${toString volume.size}
        name = "${volume.name}"
        location = "${stripDc volume.datacenter}"
      }
    '') cfg.volumes);

    provisioners.terraform.project.outputs = lib.mkMerge (lib.mapAttrsToList (_: volume: {
      "hcloud_volume_${volume.name}_id" = {
        value = "${volume.id}.id";
      };
    }) cfg.volumes);
  };
}

