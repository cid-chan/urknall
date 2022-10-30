{ localPkgs, config, stages, stage, lib, ... }:
let
  cstage = config.stage.name;
  cfg = config.secrets.gpg;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf listOf submodule str path package; in {
    secrets.gpg = {
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
          Defines a set of files that should be decrypted using GPG.
        '';
        type = attrsOf (submodule ({ config, ... }: {
          options = {
            path = mkOption {
              type = path;
              description = ''
                The path to the encrypted file.
              '';
            };

            decryptedPath = mkOption {
              type = str;
              default = lib.mkFuture cstage "${config._module.args.name}";
              description = ''
                This future will hold the path to the generated file.
              '';
            };
          };
        }));
        default = {};
      };
    };
  };

  config = lib.mkIf (config.secrets.gpg.secrets != {}) {
    urknall.resolvers = ''
      mkdir -p ${cfg.rootPath}
      rm -rf ${cfg.rootPath}/*
      ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
        ${localPkgs.gnupg}/bin/gpg -q -d ${v.path} > "${cfg.rootPath}/${k}"
      '') cfg.secrets)}
    '';
    urknall.resolveCommands = lib.mapAttrs' (k: v: {
      name = k;
      value = "echo \\\"${cfg.rootPath}/${k}\\\"";
    }) cfg.secrets;
  };
}



