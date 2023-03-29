{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;

  stripDc = value:
    builtins.head (lib.splitString "-" value);
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf oneOf submodule str int nonEmptyListOf enum nullOr; in {
    provisioners.terraform.clouds.hcloud.placement-group = mkOption {
      description = ''
        A set of Placement groups to create.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = config._module.args.name;
            description = ''
              The name of the placement group.
            '';
          };

          type = mkOption {
            type = enum [ "spread" ];
            default = "spread";
            description = ''
              The type of the placement group.
            '';
          };

          id = mkOption {
            type = str;
            readOnly = true;
            default = "hcloud_firewall.${config.name}";
            description = ''
              ID in the terraform config
            '';
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: group: ''
      resource "hcloud_placement_group" "${group.name}" {
        name = "${group.name}"
        type = "${group.type}"
      }
    '') cfg.placement-group);
  };
}


