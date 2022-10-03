{ config, lib, ... }:
let
  cfg = config.provisioners.terraform.clouds.hcloud;
in
{
  imports = [
    ./ssh-keys.nix
    ./server.nix
  ];

  options = let inherit (lib) mkOption mkEnableOption; inherit (lib.types) nullOr str int lines; in {
    provisioners.terraform.clouds.hcloud = {
      enable = mkEnableOption "hcloud";

      tokenCommand = mkOption {
        type = nullOr str;
        description = ''
          The command that yields the token.
        '';
        default = null;
      };

      pollingRate = mkOption {
        type = int;
        description = ''
          The polling rate in ms. Increase this value if you run into rate-limiting errors.
        '';
        default = "500ms";
      };

      providerBlock = mkOption {
        type = lines;
        default = "";
      };
    };
  };

  config = (lib.mkIf (cfg.enable) (lib.mkMerge [
    ({
      provisioners.terraform.backend.providers.hcloud = {
        source = "hetznercloud/hcloud";
        version = "1.35.2";
      };
      provisioners.terraform.project.module = ''
        provider "hcloud" {
          ${cfg.providerBlock}
        }
      '';
    })

    (lib.mkIf (cfg.tokenCommand != null) {
      provisioners.terraform.project.setup = ''
        export HCLOUD_TOKEN="$(cfg.tokenCommand)"
      '';
    })
  ]));
}
