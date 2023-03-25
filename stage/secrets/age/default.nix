{ localPkgs, config, stages, stage, lib, ... }:
let
  cstage = config.stage.name;
  cfg = config.secrets.age;
in
{
  imports = [
    ./state.nix
  ];
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf listOf submodule str path package; in {
    secrets.age = {
      ageCommand = mkOption {
        type = str;
        default = "${localPkgs.rage}/bin/rage";
        description = ''
          The age implementation to use.
        '';
      };

      rootPath = mkOption {
        type = str;
        default = "$STAGE_DIR";
        description = ''
          The path where decrypted files should be located.

          This directory will not be cleaned up automatically,
          however it will be cleared of all files before it is being filled again.

          It can be used to automatically generate a stable path for all files,
          so later stages will not always be rebuilt.
        '';
      };
      secrets = mkOption {
        description = ''
          Defines a set of files that should be decrypted using AGE.
        '';
        type = attrsOf (submodule ({ config, ... }: {
          options = {
            path = mkOption {
              type = path;
              description = ''
                The path to the encrypted file.
              '';
            };

            name = mkOption {
              type = str;
              default = config._module.args.name;
              description = ''
                The name of the file.
              '';
            };

            identity = mkOption {
              type = str;
              default = "$(cat AGE_IDENTITY_${config.name})";
              description = ''
                The path to the identity file that can decrypt the secret.

                Can contain bash substitutions.
              '';
            };

            decryptedPath = mkOption {
              type = str;
              default = lib.mkFuture cstage "${config._module.args.name}";
              description = ''
                The path to the decrypted secret.
              '';

            };
          };
        }));
        default = {};
      };
    };
  };

  config = lib.mkIf (config.secrets.age.secrets != {}) {
    urknall.resolvers = ''
      mkdir -p ${cfg.rootPath}
      rm -rf ${cfg.rootPath}/*
      ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
        ${cfg.ageCommand} -d -i "${v.identity}" -o "${cfg.rootPath}/${k}" "${v.path}"
      '') cfg.secrets)}
    '';
    urknall.resolveCommands = lib.mapAttrs' (k: v: {
      name = k;
      value = "echo \\\"${cfg.rootPath}/${k}\\\"";
    }) cfg.secrets;
  };
}


