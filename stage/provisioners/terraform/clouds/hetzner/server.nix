{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;
  assets = config.provisioners.terraform.project.assets;

  scriptPreface = 
    let
      ssh = localPkgs.callPackage ./../../../../_utils/ssh.nix { withExec = false; nixSsh = false; };
    in
    ''
      IPADDR="$1"
      ESC_IPADDR="$IPADDR"
      if [[ "$IPADDR" == *:* ]]; then
        ESC_IPADDR="[$IPADDR]"
      fi

      if [[ ! -z "$2" ]]; then 
        export SSH_KEY="$(realpath "$2")"
      fi

      rssh() {
        ${ssh.fakeSSH.text}
      }

      rscp() {
        ${ssh.fakeSCP.text}
      }
    '';

  deployIP = module:
    if module.ipv4 != false then
      lib.urknall.variable "hcloud_server.${module._identifier}.ipv4_address"
    else if module.ipv6 != false then
      lib.urknall.variable "replace(hcloud_server.${module._identifier}.ipv6_address, \"::1\", \"::2\")"
    else
      throw "Cannot provision on privately networked servers.";

  serverIP = module:
    if module.ipv4 != false then
      lib.urknall.variable "hcloud_server.${module._identifier}.ipv4_address"
    else if module.ipv6 != false then
      lib.urknall.variable "hcloud_server.${module._identifier}.ipv6_address"
    else
      throw "Cannot provision on privately networked servers.";

  generateFileRenameMap = module:
    let
      fileEntries = lib.mapAttrsToList (name: value: { inherit name value; }) module.files;
      renames = lib.imap0 (idx: entry: {
        name = entry.name;
        value = {
          key = "hcloud_server_files_${module.name}_${toString idx}";
          renamed = "assets/hcloud_server_files_${module.name}_${toString idx}";
          file = entry.value.file;
        };
      }) fileEntries;
    in
    builtins.listToAttrs renames;


  armTypes = [ "cax11" "cax21" "cax31" "cax41" ];
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule listOf nullOr anything enum str oneOf bool lines int; in {
    provisioners.terraform.clouds.hcloud.servers = mkOption {
      description = ''
        A set of servers that should be created on Hetzner Cloud.
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

          id = mkOption {
            type = str;
            readOnly = true;
            default = "hcloud_server.${config._identifier}";
            description = ''
              ID in the terraform config
            '';
          };

          generation = mkOption {
            type = str;
            default = "";
            description = "Changing this value triggers a replacement of the server. Volumes and IPs will remain the same.";
          };

          type = mkOption {
            type = enum ([ 
              "cx11" "cpx11" "cx21" "cpx21" "cx31" "cpx31" "cx41" "cpx41" "cx51" "cpx51"              # Shared Resources
              "ccx11" "ccx12" "ccx21" "ccx22" "ccx31" "ccx32" "ccx41" "ccx42" "ccx51" "ccx52" "ccx52" # Dedicated Resources
            ] ++ armTypes);
            description = ''
              The instance type.
            '';
          };

          datacenter = mkOption {
            type = str;
            default = "fsn1-dc14";
            description = ''
              The datacenter to place the vps in.
            '';
          };

          sshKeys = mkOption {
            type = listOf str;
            default = [];
            description = ''
              The SSH-Key IDs (obtainable via `ssh-keys.[name].id`) to provision the machine with.
            '';
          };

          privateKey = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              An private key to use for connecting to the newly created server.
            '';
          };

          snapshot = mkOption {
            type = nullOr int;
            default = null;
            description = ''
              Use the snapshot with the given id.
              If this option is given sshKeys are not used.

              Install this NixOS System. Snapshot and nixosSystem are mutually incompatible.
            '';
          };

          system = mkOption {
            type = nullOr (submodule (import ./../../../../_utils/strategies/rescue/submodule.nix { 
              system = 
                if  (builtins.elem config.type armTypes) then
                  "aarch64-linux"
                else
                  "x86_64-linux"; 
            }));
            default = null;
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

          volumes = mkOption {
            type = listOf str;
            default = [];
            description = ''
              List of volumes to add.
              Define volumes using `hcloud.volumes`.
              For hcloud.server.[name].files, the volumes will be accessible as `/tmp/volumes/[name]`.
              For subsequent stages, the disk-path will be accessible using the future `hcloud.volumes.[name].diskPath` 
            '';
          };

          placementGroup = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              The placement-group to join the server to.
              May trigger a rebuild.
            '';
          };

          extraConfig = mkOption {
            type = lines;
            default = "";
            description = ''
              Extra options to put in the terraform resource.
            '';
          };

          labels = mkOption {
            type = attrsOf str;
            default = {};
            description = ''
              Labels to apply to a server.
            '';
          };

          firewalls = mkOption {
            type = listOf str;
            default = [];
            description = ''
              A list of firewalls the machine should be attached to.
            '';
          };

          networks = mkOption {
            type = attrsOf (submodule ({ config, ... }: { options = {
              network = mkOption {
                type = str;
                description = ''
                  The name of the network
                '';
              };
              subnet = mkOption {
                type = str;
                default = config._module.args.name;
                description = ''
                  The subnet to attach to.
                '';
              };

              ip = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  A static IP to assign to the server.
                '';
              };

              routes = mkOption {
                type = listOf str;
                default = [];
                description = ''
                  A route to announce to the whole private network.
                '';
              };
            }; }));
            default = {};
            description = ''
              A set of up to three private networks.
            '';
          };

          ipv4 = mkOption {
            type = oneOf [ str bool ];
            default = true;
            description = ''
              Give the server a public IPv4.

              If you have a primary IP set, use that one instead. (Not implemented yet)
            '';
          };

          ipv6 = mkOption {
            type = oneOf [ str bool ];
            default = true;
            description = ''
              Give the server a public IPv6.
              If you have a primary IP set, use that one instead. (Not implemented yet)
            '';
          };

          rdns = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Reverse DNS Entry for the server
            '';
          };

          addresses = {
            ipv4 = mkOption {
              type = str;
              readOnly = true;
              description = ''
                The resolved public IPv4 of the server.
              '';
            };
            ipv6 = mkOption {
              type = str;
              readOnly = true;
              description = ''
                The resolved public IPv6 of the server.
              '';
            };
          };
        };

        config = {
          addresses = {
            ipv4 = outputs."hcloud_server_${config._identifier}_ipv4_address".future;
            ipv6 = outputs."hcloud_server_${config._identifier}_ipv6_address".future;
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.assets = lib.mkMerge [
      (lib.mkIf (cfg.servers != {}) {
        hcloud_server_name_volumes = {
          file = toString ./mount_volumes.sh;
          chmod = "755";
        };
      })

      (lib.mkMerge (map (server: lib.mkMerge [
        ({
          "hcloud_server_pk_${server._identifier}" = lib.mkIf (server.privateKey != null) {
            file = server.privateKey;
            chmod = "0600";
          };

          "hcloud_server_${server._identifier}_primary_ip_workaround" = lib.mkIf (server.ipv4 != false && server.ipv6 != false) {
            file = toString (localPkgs.writeText "primary-ip-workaround" ''
              #!/usr/bin/env bash
              sleep 5
              echo '{ "text": "unused" }'
            '');
            chmod = "0755";
          };
        })

        (lib.mkIf (server.files != {}) {
          "hcloud_server_files_${server._identifier}_upload" = {
            file = 
              let
                paths = builtins.attrNames server.files;
                renames = generateFileRenameMap server;
                commands = map (path:
                  let 
                    file = server.files.${path};
                  in 
                  ''
                  rssh root@$IPADDR -- mkdir -p $(dirname ${path})
                  rscp ${renames.${path}.renamed} root@$ESC_IPADDR:${path}
                  rssh root@$IPADDR -- chown ${file.user}:${file.group} ${path}
                  rssh root@$IPADDR -- chmod ${file.mode} ${path}
                  ''
                ) paths;
              in
              toString (localPkgs.writeText "mkdirs.sh" ''
                #!/usr/bin/env bash
                ${scriptPreface}
                ${builtins.concatStringsSep "\n" commands}
              '');
            chmod = "0755";
          };
        })

        (lib.mkMerge (map (file: {
          "${file.key}" = lib.mkIf (file.file != null) {
            file = toString file.file;
          };
        }) (builtins.attrValues (generateFileRenameMap server))))
      ]) (builtins.attrValues cfg.servers)))
    ];

    provisioners.terraform.project.setup = lib.mkIf (cfg.servers != {}) ''
      export PATH="${lib.makeBinPath [ localPkgs.gawk localPkgs.openssh localPkgs.coreutils ]}:$PATH"
    '';

    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: module: ''
      ${lib.optionalString (module.ipv4 == true) ''
        resource "hcloud_primary_ip" "${module._identifier}_ipv4" {
            name = "${module._identifier}-ipv4"
            type = "ipv4"
            assignee_type = "server"
            datacenter = "${module.datacenter}"
            auto_delete = false
        }
      ''}

      ${lib.optionalString (module.ipv6 == true) ''
        resource "hcloud_primary_ip" "${module._identifier}_ipv6" {
            name = "${module._identifier}-ipv6"
            type = "ipv6"
            datacenter = "${module.datacenter}"
            assignee_type = "server"
            auto_delete = false
        }
      ''}

      ${lib.optionalString (module.rdns != null) ''
        ${lib.optionalString (module.ipv4 != false) ''
          resource "hcloud_rdns" "${module._identifier}_rdns_ipv4" {
              server_id = hcloud_server.${module._identifier}.id
              ip_address = hcloud_server.${module._identifier}.ipv4_address
              dns_ptr = "${module.rdns}"
          }
        ''}

        ${lib.optionalString (module.ipv6 != false) ''
          resource "hcloud_rdns" "${module._identifier}_rdns_ipv6" {
              server_id = hcloud_server.${module._identifier}.id
              ip_address = hcloud_server.${module._identifier}.ipv6_address
              dns_ptr = "${module.rdns}"
          }
        ''}
      ''}

      ${builtins.concatStringsSep "\n" (map (network: ''
        resource "hcloud_server_network" "${module._identifier}_${network.network}" {
          server_id = hcloud_server.${module._identifier}.id
          network_id = hcloud_network.${network.network}.id
          ${lib.optionalString (network.ip != null) "ip = \"${network.ip}\""}
        }

        ${lib.optionalString (network.ip != null) ''
          ${builtins.concatStringsSep "\n" (map (route: ''
            resource "hcloud_network_route" "${network.network}_${module._identifier}_${builtins.replaceStrings ["." "/"] ["_" "_"] route}" {
              network_id = hcloud_network.${network.network}.id
              destination = "${route}"
              gateway = "${network.ip}"
            }
          '') network.routes)}
        ''}
      '') (builtins.attrValues module.networks))}

      ${builtins.concatStringsSep "\n" (map (volume: ''
        resource "hcloud_volume_attachment" "${module._identifier}_${volume}" {
          volume_id = hcloud_volume.${volume}.id
          server_id = hcloud_server.${module._identifier}.id
          automount = false
        }
      '') module.volumes)}

      resource "null_resource" "hcloud_server_${module._identifier}_provision" {
        triggers = {
          server_id = "${lib.urknall.variable "hcloud_server.${module._identifier}.id"}"
        }

        ${if module.snapshot == null then ''
          ${lib.optionalString (module.system != null) ''
            ${lib.optionalString ((builtins.length module.volumes) > 0) ''
              provisioner "local-exec" {
                when = create
                command = "VOLUMES='${builtins.concatStringsSep " " (map (volume: "${volume}=${lib.urknall.variable "hcloud_volume.${volume}.id"}") module.volumes)}' ${assets.hcloud_server_name_volumes.path} ${deployIP module}"
              }
            ''}

            provisioner "local-exec" {
              when = create
              command = "${localPkgs.callPackage ./../../../../_utils/strategies/rescue {
                inherit lib;
                module = module.system;
                tableType = "dos";

                preActivate = "${(localPkgs.callPackage ./../../../../_utils/strategies/files {
                  inherit lib;
                  module = module.files;
                  targetRewriter = (path: "/mnt${path}");
                })} $IPADDR";

                rebootAfterInstall = true;
              }} ${deployIP module}"
            }
          ''}
        '' else ''
          ${lib.optionalString ((module.files != {}) && (module.system == null)) (
            ''
            provisioner "local-exec" {
              when = create
              command = "${assets."hcloud_server_files_${module._identifier}_upload".path} ${serverIP module}"
            }

            provisioner "local-exec" {
              when = create
              command = "ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no root@${serverIP module} -- reboot"
            }
          '')}
        ''}

      }

      resource "hcloud_server" "${module._identifier}" {
        name = "${module.name}"
        datacenter = "${module.datacenter}"
        server_type = "${module.type}"

        ${lib.optionalString (builtins.length module.sshKeys > 0) ''
          ssh_keys = [
            ${builtins.concatStringsSep ",\n" (map (ssh: "${ssh}.id") module.sshKeys)}
          ]
        ''}

        public_net {
          ${lib.optionalString (module.ipv4 == false) ''
            ipv4_enabled = false
          ''}

          ${lib.optionalString (module.ipv6 == false) ''
            ipv6_enabled = false
          ''}

          ${lib.optionalString (module.ipv4 != false) ''
            ipv4_enabled = true
            ${if (module.ipv4 != true) then ''
                ipv4 = ${module.ipv4}.id
            '' else ''
                ipv4 = hcloud_primary_ip.${module._identifier}_ipv4.id
            ''}
          ''}
          ${lib.optionalString (module.ipv6 != false) ''
            ipv6_enabled = true
            ${if (module.ipv6 != true) then ''
                ipv6 = ${module.ipv6}.id
            '' else ''
                ipv6 = hcloud_primary_ip.${module._identifier}_ipv6.id
            ''}
          ''}
        }

        ${lib.optionalString ((builtins.length module.firewalls) > 0) ''
          firewall_ids = [
              ${builtins.concatStringsSep "," (map (name: "hcloud_firewall.${name}.id") module.firewalls)}
          ]
        ''}

        ${lib.optionalString (module.placementGroup != null) ''
          placement_group_id = hcloud_placement_group.${module.placementGroup}.id 
        ''}

        labels = {
          "urknall.dev/stage" : "${stage}",
          "urknall.dev/name" : "${module.name}"${lib.optionalString (module.labels != {}) ","}
          ${builtins.concatStringsSep ",\n" (lib.mapAttrsToList (k: v: ''
            "${k}" : "${v}"
          '') module.labels)}
        }

        ${if module.snapshot == null then ''
          image = "ubuntu-22.04"
          ${lib.optionalString (module.system != null) ''
            rescue = "linux64"
          ''}
        '' else ''
          image = ${toString module.snapshot}
          rescue = "linux64"
        ''}

        lifecycle {
          replace_triggered_by = [ null_resource.${module._identifier}_trigger_replace ]
        }

        ${module.extraConfig}
      }

      resource "null_resource" "${module._identifier}_trigger_replace" {
        triggers = {
          ${lib.optionalString (module.volumes != []) ''
            volumes = "${builtins.concatStringsSep " " (map (vol: lib.urknall.variable "hcloud_volume.${vol}.id") module.volumes)}"
          ''}
          ${lib.optionalString (module.generation != "") ''
            generation = "${module.generation}--${module.type}"
          ''}
        }
      }
    '') cfg.servers);

    provisioners.terraform.project.outputs = lib.mkMerge (lib.mapAttrsToList (_: module: {
      "hcloud_server_${module._identifier}_ipv4_address" = {
        value = "${module.id}.ipv4_address";
      };

      "hcloud_server_${module._identifier}_ipv6_address" = {
        value = "${module.id}.ipv6_address";
      };
    }) cfg.servers);
  };
}

