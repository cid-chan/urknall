{ config, lib, localPkgs, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;
  assets = config.provisioners.terraform.project.assets;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule listOf nullOr anything enum str oneOf bool lines int; in {
    provisioners.terraform.clouds.hcloud.servers = mkOption {
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
            default = "hcloud_server.${config.name}";
            description = ''
              ID in the terraform config
            '';
          };

          type = mkOption {
            type = enum [ 
              "cx11" "cpx11" "cx21" "cpx21" "cx31" "cpx31" "cx41" "cpx41" "cx51" "cpx51"              # Shared Resources
              "ccx11" "ccx12" "ccx21" "ccx22" "ccx31" "ccx32" "ccx41" "ccx42" "ccx51" "ccx52" "ccx52" # Dedicated Resources
            ];
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

          btrfs = mkOption {
            type = bool;
            default = false;
            description = ''
              Make a server with btrfs running on it.
            '';
          };

          snapshot = mkOption {
            type = nullOr int;
            default = null;
            description = ''
              Use the snapshot with the given id.
              If this option is given, privateKey and sshKeys are not used.
            '';
          };

          extraConfig = mkOption {
            type = lines;
            default = "";
            description = ''
              Extra options to put in the terraform resource.
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

          nixosModule = mkOption {
            type = anything;
            readOnly = true;
            default = import ./nixos-module.nix { inherit (config) name btrfs; };
            description = ''
              A NixOS-module that includes a configuration suitable for the hetzner vps.
            '';
          };

          addresses = {
            ipv4 = mkOption {
              type = str;
              default = outputs."hcloud_server_${config.name}_ipv4_address".future;
              readOnly = true;
              description = ''
                The resolved public IPv4 of the server.
              '';
            };
            ipv6 = mkOption {
              type = str;
              readOnly = true;
              default = outputs."hcloud_server_${config.name}_ipv4_address".future;
              description = ''
                The resolved public IPv6 of the server.
              '';
            };
          };
        };
      }));
      default = {};
    };
  };

  config = {
    provisioners.terraform.project.assets = lib.mkMerge [
      (lib.mkIf (cfg.servers != {}) {
        hcloud_server_cloud_init_ext4.file = toString ./cloudinit_ext4.yml;
        hcloud_server_cloud_init_btrfs.file = toString ./cloudinit_btrfs.yml;
        hcloud_server_wait_for_installed = {
          file = toString ./wait_for_nixos.sh;
          chmod = "755";
        };
      })

      (lib.mkMerge (map (server: {
        "hcloud_server_pk_${server.name}" = lib.mkIf (server.privateKey != null) {
          file = server.privateKey;
          chmod = "0600";
        };
      }) (builtins.attrValues cfg.servers)))
    ];

    provisioners.terraform.project.setup = lib.mkIf (cfg.servers != {}) ''
      export PATH="${lib.makeBinPath [ localPkgs.gawk localPkgs.openssh localPkgs.coreutils ]}:$PATH"
    '';

    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: module: ''
      ${lib.optionalString (module.ipv4 == true) ''
        resource "hcloud_primary_ip" "${module.name}_ipv4" {
            name = "${module.name}-ipv4"
            type = "ipv4"
            assignee_type = "server"
            datacenter = "${module.datacenter}"
            auto_delete = false
        }
      ''}

      ${lib.optionalString (module.ipv6 == true) ''
        resource "hcloud_primary_ip" "${module.name}_ipv6" {
            name = "${module.name}-ipv6"
            type = "ipv6"
            datacenter = "${module.datacenter}"
            assignee_type = "server"
            auto_delete = false
        }
      ''}

      ${lib.optionalString (module.rdns != null) ''
        ${lib.optionalString (module.ipv4 != false) ''
          resource "hcloud_rdns" "${module.name}_rdns_ipv4" {
              server_id = hcloud_server.${module.name}.id
              ip_address = hcloud_server.${module.name}.ipv4_address
              dns_ptr = "${module.rdns}"
          }
        ''}

        ${lib.optionalString (module.ipv6 != false) ''
          resource "hcloud_rdns" "${module.name}_rdns_ipv6" {
              server_id = hcloud_server.${module.name}.id
              ip_address = hcloud_server.${module.name}.ipv6_address
              dns_ptr = "${module.rdns}"
          }
        ''}
      ''}

      resource "hcloud_server" "${module.name}" {
        name = "${module.name}"
        datacenter = "${module.datacenter}"
        server_type = "${module.type}"
        user_data = file("${
          if module.btrfs then
            assets.hcloud_server_cloud_init_btrfs.path
          else
            assets.hcloud_server_cloud_init_ext4.path
        }")

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
                ipv4 = hcloud_primary_ip.${module.name}_ipv4.id
            ''}
          ''}
          ${lib.optionalString (module.ipv6 != false) ''
            ipv6_enabled = true
            ${if (module.ipv6 != true) then ''
                ipv6 = ${module.ipv6}.id
            '' else ''
                ipv6 = hcloud_primary_ip.${module.name}_ipv6.id
            ''}
          ''}
        }

        ${if module.snapshot == null then ''
          image = "ubuntu-22.04"
          provisioner "local-exec" {
            when = create
            command = "./${assets.hcloud_server_wait_for_installed.path} ${lib.urknall.variable "self.ipv4_address"} ${lib.optionalString (module.privateKey != null) assets."hcloud_server_pk_${module.name}".path}"
          }
        '' else ''
          image = ${toString module.snapshot}
        ''}

        ${module.extraConfig}
      }
    '') cfg.servers);

    provisioners.terraform.project.outputs = lib.mkMerge (lib.mapAttrsToList (_: module: {
      "hcloud_server_${module.name}_ipv4_address" = {
        value = "${module.id}.ipv4_address";
      };

      "hcloud_server_${module.name}_ipv6_address" = {
        value = "${module.id}.ipv6_address";
      };
    }) cfg.servers);
  };
}

