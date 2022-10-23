{ lib, config, ... }:
let
  cfg = config.provisioners.terraform.cloudflare;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf listOf submodule nullOr str bool enum oneOf int; in {
    provisioners.terraform.cloudflare.zones = mkOption {
      type = attrsOf (submodule ({ config, ... }: { options = {
        name = mkOption {
          type = str;
          default = config._module.args.name;
          description = ''
            Applies to a given zone.
          '';
        };

        accountId = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Cloudflare zone names are not unique.
            It is possible for multiple accounts to have the same zone created but in different states.
            Use accountId to further restrict the match.
          '';
        };

        _id = mkOption {
          type = str;
          default = builtins.replaceStrings ["."] ["_d_"] config.name;
          internal = true;
        };

        id = mkOption {
          type = str;
          readOnly = true;
          default = "data.cloudflare_zone.${config._id}.id";
          description = ''
            The Terraform-ID of the zone.
          '';
        };

        records = mkOption {
          type = listOf (submodule ({ config, ... }: { options = {
            name = mkOption {
              type = str;
              description = ''
                The name of the record.
              '';
            };

            value = mkOption {
              type = oneOf [str (attrsOf (oneOf [int str]))];
              description = ''
                The value of the record.
              '';
            };

            _id = mkOption {
              type = str;
              internal = true;
              readOnly = true;
              description = ''
                The Terraform-ID of the record.
              '';
              default = 
                builtins.hashString "sha1" (builtins.toJSON {
                  name = config.name;
                  value = config.value;
                  type = config.type;
                });
            };

            type = mkOption {
              type = enum [
                # Can be proxied
                "A" "AAAA" "CNAME" 

                # Everything else
                "CAA" "CERT" "DNSKEY" "DS" "HTTPS" "LOC" "MX"
                "NAPTR" "NS" "PTR" "SMIMEA" "SPF" "SRV" "SSHFP"
                "SVCB" "TLSA" "TXT" "URI"
              ];
              description = ''
                The DNS Record type.
              '';
            };

            ttl = mkOption {
              type = nullOr int;
              default = null;
              description = ''
                The TTL of the entry. null means "Auto".
              '';
            };

            priority = mkOption {
              type = nullOr int;
              default = null;
              description = ''
                The priority of the record.
              '';
            };

            proxied = mkOption {
              type = bool;
              default = (config.type == "A" || config.type == "AAAA" || config.type == "CNAME");
              description = ''
                Whether or not CloudFlare should proxy this value.
              '';
            };
          }; }));
          default = [];
          description = ''
            A list of records that the zone should have.
          '';
        };
      }; }));
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.terraform.project = (lib.mkMerge (map (zone: {
      module = ''
        data "cloudflare_zone" "${zone._id}" {
          name = "${zone.name}"
          ${lib.optionalString (zone.accountId != null) "account_id = \"${zone.accountId}\""}
        }

        ${builtins.concatStringsSep "\n" (map (record: ''
          resource "cloudflare_record" "${zone._id}__${record._id}" {
            zone_id = ${zone.id}
            name = "${record.name}"
            type = "${record.type}"
            ${if builtins.isString record.value then
                "value = \"${record.value}\""
              else
              ''
                data {
                  ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
                    if builtins.isString v then
                      "${k} = \"${v}\""
                    else
                      "${k} = ${v}"
                  ) record.value)}
                }
              ''
            }
            ${lib.optionalString (record.ttl != null) "ttl = ${toString record.ttl}"}
            ${lib.optionalString (record.priority != null) "priority = ${toString record.priority}"}
            ${lib.optionalString (record.proxied != null) "proxied = ${if record.proxied then "true" else "false"}"}
          }
        '') zone.records)}
      '';
    }) (builtins.attrValues cfg.zones)));
  };
}

