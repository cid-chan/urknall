{ config, lib, localPkgs, stage, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
  outputs = config.provisioners.terraform.project.outputs;

  stripDc = value:
    builtins.head (lib.splitString "-" value);
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf oneOf submodule str int nonEmptyListOf enum nullOr; in {
    provisioners.terraform.clouds.hcloud.firewalls = mkOption {
      description = ''
        A set of Firewalls to create.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = config._module.args.name;
            description = ''
              The name of the firewall.
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

          rules = mkOption {
            type = nonEmptyListOf (submodule ({ config, ... }: {
              options = {
                direction = mkOption {
                  type = enum [ "in" "out" ];
                  description = "Filter which direction.";
                };
                protocol = mkOption {
                  type = enum [ "tcp" "icmp" "udp" "gre" "esp" ];
                  description = "The protocol the rule applies to";
                };
                port = mkOption {
                  type = oneOf [ int (submodule ({ ... }: {
                    options = {
                      from = mkOption {
                        type = int;
                        description = "The starting port";
                      };
                      to = mkOption {
                        type = int;
                        description = "The last port";
                      };
                    };
                  })) ];
                  description = "Which ports to filter. Only required with tcp and udp";
                };
                ips = mkOption {
                  type = nonEmptyListOf str;
                  description = "A list of CIDRs that match this rule.";
                };
              };
            }));
            description = "Firewall rules to apply.";
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project.module = lib.mkMerge (lib.mapAttrsToList (_: firewall: ''
      resource "hcloud_firewall" "${firewall.name}" {
        name = "${firewall.name}"

        ${builtins.concatStringsSep "\n" (map (fw: ''
          rule {
            direction = "${fw.direction}"
            protocol = "${fw.protocol}"

            ${lib.optionalString (fw.protocol == "tcp" || fw.protocol == "udp") ''
              ${
                if (builtins.isInt fw.port) then 
                  "port = \"${toString port}\""
                else
                  "port = \"${toString port.from}-${toString port.to}\""
              }
            ''}

            ${if (fw.direction == "in") then "source_ips" else "destination_ips"} = [
              ${builtins.concatStringsSep "," (map (ip: "\"${ip}\"") fw.ips)}
            ]
          }
        '') firewall.rules}
      }
    '') cfg.firewalls);

    provisioners.terraform.project.outputs = lib.mkMerge (lib.mapAttrsToList (_: firewall: {
    }) cfg.firewalls);
  };
}


