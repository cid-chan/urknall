{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;

  stripDc = value:
    builtins.head (lib.splitString "-" value);
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule str int nonEmptyListOf enum; in {
    provisioners.terraform.clouds.hcloud.networks = mkOption {
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
            default = "hcloud_network.${config.name}";
            description = ''
              ID in the terraform config
            '';
          };

          ipRange = mkOption {
            type = str;
            description = ''
              An IP Range that encompasses all included subnets.
            '';
          };

          zone = mkOption {
            type = enum [ "eu-central" "us-east" ];
            default = "eu-central";
            description = ''
              The area the network belongs to.
            '';
          };

          subnets = mkOption {
            type = nonEmptyListOf str;
            description = ''
              A list of subnets to attach
            '';
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: network: ''
      resource "hcloud_network" "${network.name}" {
        name = "${network.name}"
        ip_range = "${network.ipRange}"
      }

      ${builtins.concatStringsSep "\n" (map (subnet: ''
        resource "hcloud_network_subnet" "${network.name}_${builtins.replaceStrings ["." "/"] ["_" "_"] subnet}" {
          type = "cloud"
          network_id = hcloud_network.${network.name}.id
          network_zone = "${network.zone}"
          ip_range = "${subnet}"
        }
      '') network.subnets)}
    '') cfg.networks);

    provisioners.terraform.project.outputs = lib.mkMerge (lib.mapAttrsToList (_: network: {
    }) cfg.networks);
  };
}


