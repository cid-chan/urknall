{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.null.servers;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule listOf nullOr anything enum str oneOf bool lines int; in {
    provisioners.terraform.clouds.null.servers = mkOption {
      description = ''
        A set of servers that are deployed with a rescue image someone put into a drive.
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

          _identifier = mkOption {
            type = str;
            internal = true;
            readOnly = true;
            default = "${builtins.replaceStrings ["-"] ["_"] config._module.args.name}";
          };

          generation = mkOption {
            type = str;
            default = "0";
            description = ''
              The generation of the resource.
              Change the number to force recreation.
            '';
          };

          host = mkOption {
            type = str;
            description = ''
              The IP-Address that can reach the server.
            '';
          };

          provisioningHost = mkOption {
            type = str;
            default = config.host;
            description = ''
              The IP-Address that the provisioningHost currently has.
            '';
          };

          partitionType = mkOption {
            type = enum [ "dos" "gpt" ];
            default = "dos";
            description = ''
              What partitioning table should be used?
            '';
          };

          system = mkOption {
            type = submodule (import ./../../../../_utils/strategies/rescue/submodule.nix { system = "x86_64-linux"; });
            description = ''
              Install this NixOS System.

              Snapshot and nixosSystem are mutually incompatible.
              Using this option is not supported with TerraForm cloud.
            '';
          };

          files = mkOption {
            type = attrsOf (submodule (import ./../../../../_utils/strategies/files/submodule.nix));
            default = {};
            description = ''
              Additional files to copy to the target
            '';
          };
        };
      }));

      default = {};
    };
  };

  config = {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: module: ''
      resource "null_resource" "null_${module._identifier}" {
        triggers = {
          generation = "${module.generation}"
        }

        connection {
          host = "${module.host}"
        }

        provisioner "local-exec" {
          when = create
          command = "${localPkgs.callPackage ./../../../../_utils/strategies/rescue {
            inherit lib;
            module = module.system;
            tableType = module.partitionType;

            preActivate = "${(localPkgs.callPackage ./../../../../_utils/strategies/files {
              inherit lib;
              module = module.files;
              targetRewriter = (path: "/mnt${path}");
            })} $IPADDR";

            rebootAfterInstall = true;
          }} ${module.provisioningHost}"
        }

        provisioner "local-exec" {
          when = create
          command = "${localPkgs.writeShellScript "wait-for-online" ''
            IPADDR="$1"
            ESC_IPADDR="$IPADDR"
            if [[ "$IPADDR" == *:* ]]; then
              ESC_IPADDR="[$IPADDR]"
            fi

            export SSH_KEY="$(realpath "$2")"
            export PATH=${(localPkgs.callPackage ./../../../../_utils/ssh.nix {}).path}:$PATH

            runScript() {
              local name=$1
              local localname=$2
              shift
              shift

              scp $name root@$ESC_IPADDR:/root/$localname
              ssh root@$IPADDR -- chmod +x /root/$localname
              ssh root@$IPADDR -- /root/$localname "$@"
            }

            # Wait for the rescue system to come online.
            while ! ssh root@$IPADDR -- true; do
              sleep 1
            done
          ''} ${module.host}"
        }
      }
    '') cfg);
  };
}

