{ lib, config, localPkgs, environment, ... }:
let
  cfg = config.provisioners.terraform;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) nullOr str; in {
    provisioners.terraform.backend.local.statePath = mkOption {
      type = str;
      description = lib.mkDoc "The path to the state file.";
      default = 
        if cfg.project.homePath != null then
          cfg.project.homePath  + "/state"
        else
          "$URKNALL_LOCAL_DIRECTORY/.terraform/state";
    };
  };

  config = lib.mkIf (config.provisioners.terraform.backend.type == "local") {
    provisioners.terraform.project.setup = ''
      if [[ ! -e "$(dirname ${cfg.backend.local.statePath})" ]]; then
        mkdir -p "$(dirname ${cfg.backend.local.statePath})"
      fi
    '';

    provisioners.terraform.backend.terraformBlock = ''
      backend "local" {
      }
    '';
    provisioners.terraform.project.arguments = "-state $(echo ${cfg.backend.local.statePath})";
    provisioners.terraform.project.initArguments = "-reconfigure";
  };
}
