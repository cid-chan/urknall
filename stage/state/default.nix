{ config, lib, localPkgs
, ... }:
let
  cstage = config.stage.name;

  decryptor = localPkgs.writeShellScript "decryptor" config.state.encryption.decryptionCommand;
  encryptor = localPkgs.writeShellScript "encryptor" config.state.encryption.encryptionCommand;

  prefix = ''
    set -e
    mkdir -p $STAGE_DIR/{current,next,tmp,update}
    mkdir -p "${config.state.resultDirectory}"
    STATE_TEMP_DIR="$STAGE_DIR/tmp"
    STATE_CURRENT_DIR="$STAGE_DIR/current"
    STATE_UPDATE_DIR="$STAGE_DIR/update"
    STATE_NEXT_DIR="$STAGE_DIR/next"
    STATE_RESULT_DIR="${config.state.resultDirectory}"
  '';

  commands = ''
    function copy_maybe_recursive() {
      FROM="$1"
      TO="$2"
      [[ -e "$TO" ]] && rm -r "$TO"

      if [[ -d "$FROM" ]]; then
        mkdir -p "$TO"

        ${localPkgs.findutils}/bin/find "$FROM" -type f | while read file; do
          # Decrypt each file to the corresponding target path
          target_file="$TO''${file#$FROM}"
          mkdir -p "$(dirname "$target_file")"
          cp -a "$file" "$target_file"
        done
      else
        cp "$FROM" "$TO"
      fi
    }

    # toString False = ""
    # toString True = "1"
    function decrypt_recursive_() {
      copy_maybe_recursive "$1" "$2"
    }
    function decrypt_recursive_1() {
      source_path="$1"
      target_path="$2"
      
      # If the source path is a file, decrypt it to the target path
      if [[ -f "$source_path" ]]; then
        mkdir -p "$(dirname "$target_path")"
        ${decryptor} "$source_path" "$target_path"
      
      # If the source path is a directory, decrypt all files within it
      elif [[ -d "$source_path" ]]; then
        # Create the target directory if it doesn't exist yet
        mkdir -p "$target_path"
        
        # Loop over all files within the source directory, including subdirectories
        ${localPkgs.findutils}/bin/find "$source_path" -type f | while read file; do
          # Decrypt each file to the corresponding target path
          target_file="$target_path''${file#$source_path}"
          mkdir -p "$(dirname "$target_file")"
          ${decryptor} "$file" "$target_file"
        done
      fi
    }
    function encrypt_recursive_() {
      copy_maybe_recursive "$1" "$2"
    }
    function encrypt_recursive_1() {
      source_path="$1"
      target_path="$2"
      
      # If the source path is a file, encrypt it to the target path
      if [[ -f "$source_path" ]]; then
        mkdir -p "$(dirname "$target_path")"
        ${encryptor} "$source_path" "$target_path"
      
      # If the source path is a directory, encrypt all files within it
      elif [[ -d "$source_path" ]]; then
        # Create the target directory if it doesn't exist yet
        mkdir -p "$target_path"
        
        # Loop over all files within the source directory, including subdirectories
        ${localPkgs.findutils}/bin/find "$source_path" -type f | while read file; do
          # Decrypt each file to the corresponding target path
          target_file="$target_path''${file#$source_path}"
          mkdir -p "$(dirname "$target_file")"
          ${encryptor} "$file" "$target_file"
        done
      fi
    }

    function compare_files() {
      if [[ ! -e "$2" ]]; then
          return 0
      elif [[ ! -e "$1" ]]; then
          return 0
      elif [[ -d "$1" && -f "$2" ]]; then
          return 0
      elif [[ -f "$1" && -d "$2" ]]; then
          return 0
      elif [[ -f "$1" && -f "$2" ]]; then
          if ${localPkgs.diffutils}/bin/cmp "$1" "$2" >/dev/null; then
              return 1
          else
              return 0
          fi
      elif [[ -d "$1" && -d "$2" ]]; then
          if ${localPkgs.diffutils}/bin/diff -qr "$1" "$2" >/dev/null; then
              return 1
          else
              return 0
          fi
      else
          echo "Invalid paths provided."
          return 2
      fi
    }


    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: 
      ''
        if [[ -e "$STATE_CURRENT_DIR/${value.generation}-${name}" ]]; then
          copy_maybe_recursive "$STATE_CURRENT_DIR/${value.generation}-${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"

          decrypt_recursive_${toString value.sensitive} "$STATE_CURRENT_DIR/${value.generation}-${name}" "$STATE_TEMP_DIR/${name}"

          ${lib.optionalString value.alwaysUpdate ''
            ${localPkgs.writeShellScript "generate-${name}" value.generator} "$STATE_UPDATE_DIR/${name}" "$STATE_TEMP_DIR/${name}"
            if compare_files "$STATE_UPDATE_DIR/${name}" "$STATE_TEMP_DIR/${name}"; then
              copy_maybe_recursive "$STATE_UPDATE_DIR/${name}" "$STATE_TEMP_DIR/${name}"
              encrypt_recursive_${toString value.sensitive} "$STATE_UPDATE_DIR/${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"
            fi
          ''}
        else
          ${localPkgs.writeShellScript "generate-${name}" value.generator} "$STATE_TEMP_DIR/${name}" ""
          encrypt_recursive_${toString value.sensitive} "$STATE_TEMP_DIR/${name}" "$STATE_NEXT_DIR/${value.generation}-${name}"
        fi

        copy_maybe_recursive "$STATE_TEMP_DIR/${name}" "$STATE_RESULT_DIR/${name}"
        rm -r "$STATE_TEMP_DIR/${name}"
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

  options = let inherit (lib) mkOption; inherit (lib.types) listOf attrsOf submodule enum bool int str; in {
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
            default = "0";
            description = ''
              The bash script that is executed to generate this file. 

              Defaults to 0.

              $1 will be the path the file should be stored in.

              If alwaysUpdate is true, $2 will contain the path the current version of the file. If the file has not been created yet, $2 will be empty.
            '';
          };

          before = mkOption {
            type = listOf str;
            default = [];
            description = ''
            '';
          };

          sensitive = mkOption {
            type = bool;
            default = false;
            description = "If set to true, the contents of the file will be encrypted.";
          };

          alwaysUpdate = mkOption {
            type = bool;
            default = false;
            description = "The generator will always run.";
          };

          generation = mkOption {
            type = str;
            default = "";
            description = "Files with a different generation will get regenerated, regardless of whether they have already been created.";
          };

          inStagePath = mkOption {
            type = str;
            readOnly = true;
            description = "The path, using a bash variable, "
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

  config = lib.mkIf (config.state.files != {}) {
    urknall.appliers = wrapPushPull commands;

    urknall.destroyers = wrapPushPull ''
      # Do nothing as we want to delete everything.
    '';

    urknall.shell = wrapPush commands;

    urknall.resolveCommands = lib.mapAttrs' (k: v: {
      name = k;
      value = "echo \\\"${config.state.resultDirectory}/${k}\\\"";
    }) config.state.files;
  };
}
