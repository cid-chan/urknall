{ lib, config, localPkgs, environment, ... }:
let
  cfg = config.provisioners.terraform;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) nullOr listOf str; in {
    provisioners.terraform.backend.cloud = {
      organization = mkOption {
        type = str;
        description = lib.mkDoc ''
          The organization to use.
        '';
      };

      host = mkOption {
        type = str;
        default = "app.terraform.io";
        description = lib.mkDoc ''
          The host that contains the terraform cloud backend.
        '';
      };

      tags = mkOption {
        type = listOf str;
        default = [];
        description = lib.mkDoc ''
          Tags to attach to the workspace.
        '';
      };

      workspace = mkOption {
        type = nullOr str;
        default = null;
        description = lib.mkDoc ''
          The workspace to use. Either tags or workspace must be defined.
        '';
      };

      tokenCommand = mkOption {
        type = nullOr str;
        default = null;
        description = lib.mkDoc ''
          The command that retrieves the token for the terraform cloud.
        '';
      };
    };
    
  };

  config = lib.mkIf (config.provisioners.terraform.backend.type == "cloud") {
    provisioners.terraform.project.setup = lib.mkIf (cfg.backend.cloud.tokenCommand != null) ''
      export TF_TOKEN_${builtins.replaceStrings ["."] ["_"] cfg.backend.cloud.host}="$(${cfg.backend.cloud.tokenCommand})"
    '';

    provisioners.terraform.backend.terraformBlock = ''
      cloud {
        organization = "${cfg.backend.cloud.organization}"
        hostname = "${cfg.backend.cloud.host}"
        workspaces {
          ${lib.optionalString (cfg.backend.cloud.workspace != null) "name = \"${cfg.backend.cloud.workspace}\""}
          ${lib.optionalString (cfg.backend.cloud.tags != []) "tags = [${builtins.concatStringsSep ", " (map (v: "\"${v}\"") cfg.backend.cloud.tags)}]"}
        }
      }
    '';
  };
}

