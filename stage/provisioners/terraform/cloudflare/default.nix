{ lib, config, ... }:
let
  cfg = config.provisioners.terraform.cloudflare;

  optionalInt = attrs:
    lib.mkOption ({
      type = lib.types.nullOr lib.types.int;
      default = null;
    } // attrs);
in
{
  imports = [
    ./zones.nix
  ];

  options = let inherit (lib) mkOption mkEnableOption; inherit (lib.types) nullOr str int lines; in {
    provisioners.terraform.cloudflare = {
      enable = mkEnableOption "Support for cloudflare.";

      tokenCommand = mkOption {
        type = nullOr str;
        description = lib.mkDoc ''
          The command that yields the token.
        '';
        default = null;
      };

      provider = {
        retries = optionalInt {
          description = lib.mkDoc ''
            Maximum retries when an API request fails.
          '';
        };

        rps = optionalInt {
          description = lib.mkDoc ''
            Maximum requests per second when making calls to the API
          '';
        };

        backoff = {
          max = optionalInt {
            description = ''
              Maximal backoff time in seconds when API calls fail.
            '';
          };
          min = optionalInt {
            description = ''
              Minimal backoff time in seconds when API calls fail.
            '';
          };
        };
      };
    };
  };

  config = lib.mkIf (cfg.enable) (lib.mkMerge [
    ({
      provisioners.terraform.backend.providers.cloudflare = {
        source = "cloudflare/cloudflare";
        version = "3.26.0";
      };
      provisioners.terraform.project.module = ''
        provider "cloudflare" {
          ${lib.optionalString (cfg.provider.rps != null) "rps = ${toString cfg.provider.rps}"}
          ${lib.optionalString (cfg.provider.retries != null) "retries = ${toString cfg.provider.retries}"}
          ${lib.optionalString (cfg.provider.backoff.min != null) "min_backoff = ${toString cfg.provider.backoff.min}"}
          ${lib.optionalString (cfg.provider.backoff.max != null) "max_backoff = ${toString cfg.provider.backoff.max}"}
        }
      '';
    })

    (lib.mkIf (cfg.tokenCommand != null) {
      provisioners.terraform.project.setup = ''
        export CLOUDFLARE_API_TOKEN="$(${cfg.tokenCommand})"
      '';
    })
  ]);
}
