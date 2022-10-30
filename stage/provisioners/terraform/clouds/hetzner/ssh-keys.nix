{ config, lib, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule anything str; in {
    provisioners.terraform.clouds.hcloud.ssh-keys = mkOption {
      description = ''
        A set of SSH-Keys that should be included in Hetzner Cloud.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = config._module.args.name;
            description = ''
              The name of the private key.
            '';
          };

          id = mkOption {
            type = str;
            default = "hcloud_ssh_key.${config.name}";
            readOnly = true;
            description = ''
              ID in the terraform config
            '';
          };

          key = mkOption {
            type = str;
            description = ''
              The instance type.
            '';
          };

          extraConfig = mkOption {
            type = attrsOf anything;
            default = {};
            description = ''
              Extra options to put in the YAML file.
            '';
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: module: ''
      resource "hcloud_ssh_key" "${module.name}" {
        name = "${module.name}"
        public_key = "${module.key}"
      }
    '') cfg.ssh-keys);
  };
}
