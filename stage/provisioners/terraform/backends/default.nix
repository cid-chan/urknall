{ lib, config, localPkgs, ... }:
let
  cfg = config.provisioners.terraform;
in
{
  imports = [
    # ./cloud.nix
    ./local.nix
  ];
  options = let inherit (lib) mkOption; inherit (lib.types) enum lines attrsOf submodule str; in {
    provisioners.terraform.backend = {
      type = mkOption {
        type = enum [ "local" ];
        default = "local";
        description = ''
          What backend should pulumi use?
        '';
      };

      terraformBlock = mkOption {
        type = lines;
        default = "";
        description = ''
          Lines within the terraform block.
        '';
      };

      providers = mkOption {
        default = {};
        type = attrsOf (submodule ({ config, ... }: {
          options = {
            name = mkOption {
              type = str;
              default = config._module.args.name;
              description = ''
                The name of the private key.
              '';
            };

            source = mkOption {
              type = str;
              description = ''
                The source of the provider.
              '';
            };

            version = mkOption {
              type = str;
              description = ''
                The version of the provider.
              '';
            };
          };
        }));
      };
    };
  };

  config = {
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
