{ lib, config, localPkgs, ... }:
let
  stage = config.stage.name;
  cfg = config.provisioners.packer.hcloud;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule enum str package int; in {
    provisioners.packer.hcloud = mkOption {
      type = attrsOf (submodule ({ config, ... }: {
        imports = [
          (import ./../../../_utils/strategies/rescue/submodule.nix { system = "x86_64-linux"; })
        ];
        options = {
          location = mkOption {
            type = enum [ "nbg1" "fsn1" "hel1" "ash" ];
            default = "nbg1";
            description = ''
              The datacenter to place the module in.
            '';
          };

          serverType = mkOption {
            type = enum [
              "cx11" "cpx11" "cx21" "cpx21" "cx31" "cpx31" "cx41" "cpx41" "cx51" "cpx51"              # Shared Resources
              "ccx11" "ccx12" "ccx21" "ccx22" "ccx31" "ccx32" "ccx41" "ccx42" "ccx51" "ccx52" "ccx52" # Dedicated Resources
            ];
            default = "cx11";
          };

          files = mkOption {
            type = attrsOf (submodule (import ./../../../_utils/strategies/files/submodule.nix));
            default = {};
            description = ''
              Files to copy to the remote server
            '';
          };

          __filePackage = mkOption {
            type = package;
            internal = true;
            readOnly = true;
            default = localPkgs.callPackage ./../../../_utils/strategies/files {
              inherit lib;
              module = config.files;
              targetRewriter = (path: "/mnt${path}");
            };
          };

          __builderPackage = mkOption {
            type = package;
            internal = true;
            readOnly = true;
            default = localPkgs.callPackage ./../../../_utils/strategies/rescue {
              inherit lib;
              module = config;
              tableType = "dos";
              preActivate = let k = config._module.args.name; in ''
                ${config.__filePackage} $(cat hcloud-${k}-ip) hcloud-${k}-pkr.private.key
              '';
            };
          };

          snapshotName = mkOption {
            type = str;
            readOnly = true;
            default = 
              let
                # Add all scripts to run here.
                derivationCode = localPkgs.writeText "${config._module.args.name}" ''
                  ${config.__builderPackage}
                '';
              in
              "${builtins.baseNameOf (derivationCode.outPath)}";
            description = ''
              The name of the snapshot on Hetzner Cloud.
            '';
          };

          snapshotId = mkOption {
            type = int;
            readOnly = true;
            default = lib.mkFuture stage "hcloud.${config._module.args.name}.id";
            description = ''
              Will hold the ID of the hetzner snapshot.
            '';
          };
        };
      }));
      default = {};
      description = ''
        Each entry defines a hetzner cloud snapshot to create.
      '';
    };
  };

  config.provisioners.packer.project = lib.mkIf (cfg != {}) (lib.mkMerge [
    ({
      plugins.hcloud = {
        source = "github.com/hashicorp/hcloud";
        version = "1.0.5";
      };

      destroys = [
        ''
          for image_id in $(${localPkgs.hcloud}/bin/hcloud image list -t snapshot -o json -l 'urknall.dev/stage==${stage}' | jq -r '. // [] | map(.id) | join("\n")'); do
            ${localPkgs.hcloud}/bin/hcloud image delete "$image_id"
          done
        ''
      ];

      resolves = [
        (
          let
            snapshots = lib.mapAttrs' (k: v: {
              name = "hcloud.${k}.id";
              value = v.snapshotName;
            }) cfg;
          in
          ''
            ${localPkgs.hcloud}/bin/hcloud image list -t snapshot -o json -l 'urknall.dev/stage==${stage}' | jq -r '. // []    | map({key: .description, value: .id}) | map({key: ((${builtins.toJSON snapshots}|with_entries({key:.value,value:.key})))[.key], value:.value})| map(select(.key != null)) | from_entries'
          ''
        )
      ];

      excludes = [ 
        (
          let
            snapshots = lib.mapAttrs' (k: v: {
              name = "hcloud.${k}.hcloud.${k}";
              value = v.snapshotName;
            }) cfg;
          in
          ''
            #                                                                                                null => []                       intersection snapshotName with available snapshots             map snapshotName to build source                                               make comma-separated
            ${localPkgs.hcloud}/bin/hcloud image list -t snapshot -o json -l 'urknall.dev/stage==${stage}' | jq -r '. // []    | map(.description) | . - (. - ${builtins.toJSON (builtins.attrValues snapshots)}) | map((${builtins.toJSON snapshots}|with_entries({key:.value,value:.key}))[.]) | join(",")'
          ''
        )
      ];
    })

    (lib.mkMerge (lib.mapAttrsToList (k: v: {
      module = ''
        source "hcloud" "${k}" {
          location = "${v.location}"
          server_type = "${v.serverType}"
          snapshot_name = "${v.snapshotName}"
          snapshot_labels = {
            "urknall.dev/stage" = "${stage}"
            "urknall.dev/name" = "${k}"
          }
          server_name = "pkr-${v.snapshotName}"
          image = "ubuntu-22.04"
          ssh_username = "root"
          rescue = "linux64"

        }

        build {
            name = "hcloud.${k}"
            sources = [ "hcloud.${k}" ]

            provisioner "shell" {
              inline = [ "ifconfig eth0 | sed -ne 's/.*inet \\(.*\\) netmask.*/\\1/gp' > /tmp/ip" ]
            }
  
            provisioner "file" {
              direction = "download"
              source = "/tmp/ip"
              destination = "hcloud-${k}-ip"
            }
  
            provisioner "shell-local" {
              inline = [ "echo '${lib.urknall.variable "build.SSHPrivateKey"}' > hcloud-${k}-pkr.private.key && chmod 0600 hcloud-${k}-pkr.private.key" ]
            }
  
            provisioner "shell-local" {
              command = "${v.__builderPackage} $(cat hcloud-${k}-ip) hcloud-${k}-pkr.private.key"
            }

            post-processor "manifest" {
              output = "hcloud.${k}.manifest.json"
            }
        }
      '';
    }) cfg))
  ]);
}

