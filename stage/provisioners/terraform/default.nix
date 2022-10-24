{ lib, config, localPkgs, ... }:
let
  rootConfig = config;
  cfg = config.provisioners.terraform;

  module = 
    let
      rawFile = localPkgs.writeText "main.tf" ''
        # This file has been automatically generated by Urknall.
        # Do not edit this file manually.

        ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
          variable "${k}" {
            type = string
          }
        '') cfg.project.variables)}

        ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
          variable "${k}" {
            type = string
            sensitive = true
          }
        '') cfg.project.sensitiveVariables)}

        ${cfg.project.module}

        ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (_: v: ''
          output "${v.name}" {
            value = ${v.value}
            ${lib.optionalString v.sensitive ''
              sensitive = true
            ''}
          }
        '') cfg.project.outputs)}
      '';
    in
    localPkgs.runCommand "main.tf" {} ''
      cd /build
      dd if=${rawFile} of=./main.tf
      ${localPkgs.terraform}/bin/terraform fmt -list=false /build || (cat ${rawFile} && exit 1)
      cp ./main.tf $out
    '';

  variables = ''
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
      export TF_VAR_${k}=$(${v})
    '') cfg.project.variables)}
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
      export TF_VAR_${k}=$(${v})
    '') cfg.project.sensitiveVariables)}
  '';

  setupCommands = noOutput: ''
    ln -sf ${module} main.tf
    if [[ ! -e "${cfg.project.homePath}" ]]; then
      mkdir -p "${cfg.project.homePath}"
    fi
    ${variables}
    ${cfg.project.setup}

    if [[ -d assets ]]; then
      rm -rf assets
    fi
    mkdir assets
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (_: v: ''
      cp ${toString v.file} assets/${v.name}
      chmod ${v.chmod} assets/${v.name}
    '') cfg.project.assets)}

    ${localPkgs.terraform}/bin/terraform ${cfg.initArguments} ${lib.optionalString noOutput ">/dev/null 2>/dev/null"}
  '';
in
{
  imports = [
    ./cloudflare
    ./backends
    ./clouds
  ];

  options = let inherit (lib) mkOption mkEnableOption; inherit (lib.types) nullOr attrsOf anything str lines separatedString submodule bool; in {
    provisioners.terraform = {
      enable = mkEnableOption "terraform";

      project = {
        setup = mkOption {
          type = lines;
          default = "";
          description = ''
            Code to execute before running terraform.
          '';
        };

        homePath = mkOption {
          type = str;
          default = "$URKNALL_LOCAL_DIRECTORY/.terraform";
          description = ''
            The data directory of terraform.
          '';
        };

        variables = mkOption {
          type = attrsOf str;
          default = {};
          description = ''
            Variables to define within the terraform module.
          '';
        };

        sensitiveVariables = mkOption {
          type = attrsOf str;
          default = {};
          description = ''
            Sensitive variables.
          '';
        };

        assets = mkOption {
          type = attrsOf (submodule ({ config, ... }: {
            options = {
              name = mkOption {
                type = str;
                default = config._module.args.name;
                description = ''
                  The name of the asset.
                '';
              };

              file = mkOption {
                type = str;
                description = ''
                  A path to the file to include.
                '';
              };

              chmod = mkOption {
                type = str;
                default = "0644";
                description = ''
                  The chmod of the asset.
                '';
              };

              path = mkOption {
                type = str;
                default = "assets/${builtins.baseNameOf config.name}";
              };
            };
          }));
          default = {};
          description = ''
            Assets to include in the 
          '';
        };

        outputs = mkOption {
          default = {};
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
                default = "tf_output_${config.name}";
                readOnly = true;
                description = ''
                  The actual name of the future.
                '';
              };

              value = mkOption {
                type = str;
                description = ''
                  The code that resolves the value.
                '';
              };

              sensitive = mkOption {
                type = bool;
                default = false;
                description = ''
                  Is this a sensitive value?
                '';
              };

              future = mkOption {
                type = str;
                default = lib.mkFuture rootConfig.stage.name config.id;
                readOnly = true;
                description = ''
                  The resulting future.
                '';
              };
            };
          }));
        };

        module = mkOption {
          type = lines;
          default = "";
          description = ''
            The terraform module code.
          '';
        };

        arguments = mkOption {
          type = separatedString " ";
          default = "";
          description = ''
            Parameters to append to terraform.
          '';
        };

        initArguments = mkOption {
          type = separatedString " ";
          default = "";
          description = ''
            Parameters to append to terraform init.
          '';
        };
      };

    };
  };

  config = lib.mkIf (cfg.enable) {
    urknall.appliers = ''
      echo Using ${module} as main.tf
      ${setupCommands false}
      ${localPkgs.terraform}/bin/terraform apply ${cfg.project.arguments} -auto-approve
    '';

    urknall.destroyers = ''
      echo Using ${module} as main.tf
      ${setupCommands false}
      ${localPkgs.terraform}/bin/terraform destroy ${cfg.project.arguments} -auto-approve
    '';

    urknall.resolvers = ''
      ${setupCommands true}
      ${localPkgs.terraform}/bin/terraform output ${cfg.project.arguments} -json | ${localPkgs.jq}/bin/jq 'map_values(.value) | with_entries(.key = "tf_output_\(.key)")'
    '';
  };
}
