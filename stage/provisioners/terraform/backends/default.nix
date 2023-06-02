{ lib, config, localPkgs, ... }:
let
  cfg = config.provisioners.terraform;
in
{
  imports = [
    ./cloud.nix
    ./local.nix
  ];
  options = let inherit (lib) mkOption; inherit (lib.types) enum lines attrsOf submodule str; in {
    provisioners.terraform.backend = {
      type = mkOption {
        type = enum [ "local" "cloud" ];
        default = "local";
        description = lib.mkDoc ''
          What backend should terraform use?

          When using cloud, make sure the Execution Mode is set to "Local".
        '';
      };

      terraformBlock = mkOption {
        type = lines;
        default = "";
        description = lib.mkDoc ''
          Lines within the terraform block.
        '';
      };

      providers = mkOption {
        description = ''
          A set of terraform providers to include in the project.
        '';
        default = {};
        type = attrsOf (submodule ({ config, ... }: {
          options = {
            name = mkOption {
              type = str;
              default = config._module.args.name;
              description = lib.mkDoc ''
                The name of the private key.
              '';
            };

            source = mkOption {
              type = str;
              description = lib.mkDoc ''
                The source of the provider.
              '';
            };

            version = mkOption {
              type = str;
              description = lib.mkDoc ''
                The version of the provider.
              '';
            };
          };
        }));
      };
    };
  };

  config = {
    provisioners.terraform.backend.providers = {
      null = {
        source = "hashicorp/null";
        version = "3.1.1";
      };

      external = {
        source = "hashicorp/external";
        version = "2.2.2";
      };
    };
    provisioners.terraform.project.module = ''
      terraform {
        ${cfg.backend.terraformBlock}

        required_providers {
          ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
            ${v.name} = {
              source = "${v.source}"
              version = "${v.version}"
            }
          '') cfg.backend.providers)}
        }
      }
    '';
  };
}
