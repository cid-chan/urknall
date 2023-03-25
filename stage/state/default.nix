{ config, lib, localPkgs
, ... }:
let
  cstage = config.stage.name;

  decryptor = localPkgs.writeShellScript "decryptor" config.state.encryption.decryptionCommand;
  encryptor = localPkgs.writeShellScript "encryptor" config.state.encryption.encryptionCommand;

  prefix = ''
    set -e
    mkdir -p $STAGE_DIR/{current,next,tmp}
    mkdir -p "${config.state.resultDirectory}"
    STATE_TEMP_DIR="$STAGE_DIR/tmp"
    STATE_CURRENT_DIR="$STAGE_DIR/current"
    STATE_RESULT_DIR="${config.state.resultDirectory}"
    STATE_NEXT_DIR="$STAGE_DIR/next"
  '';

  commands = ''
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: 
      ''
        if [[ -e "$STATE_CURRENT_DIR/${value.generation}-${name}" ]]; then
          cp "$STATE_CURRENT_DIR/${value.generation}-${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"

          ${if value.sensitive then 
              ''
                ${decryptor} "$STATE_CURRENT_DIR/${value.generation}-${name}" "$STATE_RESULT_DIR/${name}"
              '' 
            else 
              ''
                cp "$STATE_CURRENT_DIR/${value.generation}-${name}" "$STATE_RESULT_DIR/${name}"
              ''
          }
        else
          ${localPkgs.writeShellScript "generate-${name}" value.generator} "$STATE_TEMP_DIR/${name}"

          ${if value.sensitive then 
              ''
                ${encryptor} "$STATE_TEMP_DIR/${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"
              '' 
            else 
              ''
                cp "$STATE_TEMP_DIR/${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"
              ''
          }
          cp "$STATE_TEMP_DIR/${name}" "$STATE_RESULT_DIR/${name}"
          rm "$STATE_TEMP_DIR/${name}"
        fi

      ''
    ) config.state.files)}
  '';

  wrapPush = command: ''
    ${prefix}
    ${config.state.storage.pullCommand}
    ${command}
  '';


  wrapPushPull = command: ''
    ${wrapPush command}
    ${config.state.storage.pushCommand}
  '';
in
{
  imports = [
    ./storages
  ];

  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule enum bool int str; in {
    state.resultDirectory = mkOption {
      type = str;
      default = "$STAGE_DIR/state";
      description = ''
        Where will the resolved state be stored?
      '';
    };

    state.storage.type = mkOption {
      type = enum [ "rsync" "git" ];
      default = "rsync";
      description = ''
        Where should the state be stored?

        Possible values:
        - rsync: Use rsync to synchronize the state. This can be used with SSH and local directories.
        - git: Use a git repository to track changes to the state.
      '';
    };

    state.storage.target = mkOption {
      type = str;
      description = "The path to the directory that stores the state.";
    };

    state.storage.pullCommand = mkOption {
      type = str;
      internal = true;
      description = ''
        This script is run when the current state is being pulled.

        $STATE_CURRENT_DIR is the directory that the current state should be pulled into.
        $STATE_NEXT_DIR contains the new state that the system should have, while pulling, this directory should remain untouched.
      '';
    };

    state.storage.pushCommand = mkOption {
      type = str;
      internal = true;
      description = ''
        This script is run when the current state is being uploaded.

        $STATE_CURRENT_DIR contains the previous state.
        $STATE_NEXT_DIR contains the new state that the system should have.
      '';
    };

    state.encryption.type = mkOption {
      type = enum [ "age" "gpg" ];
      description = ''
        How should sensitive data be encrypted?
        Possible values:
        - age: use age to encrypt and/or decrypt
        - gpg: use gpg to encrypt and/or decrypt
      '';
    };

    state.encryption.encryptionCommand = mkOption {
      type = str;
      internal = true;
      description = ''
        This command is run when a secret should be encrypted.

        $1 = unencrypted source file
        $2 = encrypted destination file
      '';
    };

    state.encryption.decryptionCommand = mkOption {
      type = str;
      internal = true;
      description = ''
        This command is run when a secret should be decrypted.

        $1 = encrypted source file
        $2 = unencrypted destination file
      '';
    };

    state.files = mkOption {
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          generator = mkOption {
            type = str;
            description = "The bash script that is executed to generate this file. $1 will be the path the file should be stored in.";
          };

          sensitive = mkOption {
            type = bool;
            default = false;
            description = "If set to true, the contents of the file will be encrypted.";
          };

          generation = mkOption {
            type = str;
            default = "";
            description = "Files with a different generation will get regenerated, regardless of whether they have already been created.";
          };

          path = mkOption {
            type = str;
            readOnly = true;
            description = "The path to the generated file.";
            default = lib.mkFuture cstage config._module.args.name;
          };
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (config.state != {}) {
    urknall.appliers = wrapPushPull commands;

    urknall.destroyers = wrapPushPull ''
      # Do nothing as we want to delete everything.
    '';

    urknall.shell = wrapPush commands;

    urknall.resolveCommands = lib.mapAttrs' (k: v: {
      name = k;
      value = "echo \\\"${config.state.resultDirectory}/${k}\\\"";
    }) cfg.state.files;
  };
}
