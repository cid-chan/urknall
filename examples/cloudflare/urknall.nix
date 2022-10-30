{ config, localPkgs, lib, ... }:
{
  config.stages.terraform = {
    provisioners.terraform.enable = true;
    provisioners.terraform.backend.type = "local";

    provisioners.terraform.cloudflare.enable = true;
    provisioners.terraform.cloudflare.zones = {
      "nemur.in".records = [
        {
          type = "TXT";
          name = "nemur.in.";
          value = "keybase-site-verification=QAWkz35E7zgm5P_o10TYoG8u6GNz3_lf0uiR0vblFzk";
        }
      ];
    };
  };
  config.urknall.stateVersion = "0.1";
}

