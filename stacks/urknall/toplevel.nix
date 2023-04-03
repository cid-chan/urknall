{ lib, config, localPkgs, ... }:
let
  scriptHead = ''
    ###########################################
    # Urknall Script                          #
    ###########################################
    set -e

    # Pushd makes annoying output. Hide it.
    pushd () {
      command pushd "$@" > /dev/null
    }
    
    popd () {
        command popd "$@" > /dev/null
    }

    ##
    # Create a skeleton directory.
    mkdir $URKNALL_ROOT_DIR/{shared,resolves,stages}
    export SHARE_DIR=$URKNALL_ROOT_DIR/shared
    export RESOLVE_DIR=$URKNALL_ROOT_DIR/resolves
    export STAGES_ROOT=$URKNALL_ROOT_DIR/stages

    ##
    # Build the script stages.
    echo "{ \"!urknall\": { \"currentDirectory\": \"$URKNALL_LOCAL_DIRECTORY\" }}" > $URKNALL_ROOT_DIR/urknall.json
    stage_files=$URKNALL_ROOT_DIR/urknall.json

    ##
    # Build the stage directories (empty at first)
    ${builtins.concatStringsSep "\n" (map (stage: ''
      mkdir $STAGES_ROOT/${stage}
    '') (builtins.attrNames config.stages))}
  '';

  stageHead = ''
    # Assertions:
    # Evaluating this will fail building when any assertion evaluates to true
    # ${config.urknall.build.assertions}

    # Warnings:
    # Evaluating this will show a warning when any assertion evaluates to true
    # ${config.urknall.build.warnings}
  '';

  resolveStage = stage: ''
    ###
    # Stage: ${stage.name}
    echo "Resolving variables of ${stage.name}"
    export STAGE_DIR=$STAGES_ROOT/${stage.name}
    pushd $STAGES_ROOT/${stage.name} >/dev/null 2>/dev/null
    ($(${config.urknall.build.evaluator {
      stage = stage.name;
      operation = "resolve";
      stageFileVar = "stage_files";
    }} "$@") || exit 1) | jq -s 'add | { "${stage.name}": . }' > $RESOLVE_DIR/${stage.name}.json

    if [[ -z "$stage_files" ]]; then
      stage_files="$RESOLVE_DIR/${stage.name}.json"
    else
      stage_files="$stage_files;$RESOLVE_DIR/${stage.name}.json"
    fi
    popd
  '';

  applyStage = stage: ''
    ###
    # Stage: ${stage.name}
    echo "Applying ${stage.name}"
    export STAGE_DIR=$STAGES_ROOT/${stage.name}
    pushd $STAGES_ROOT/${stage.name}
    $(${config.urknall.build.evaluator {
      stage = stage.name;
      operation = "apply";
      stageFileVar = "stage_files";
    }} "$@") || exit $?
    popd
  '';

  destroyStage = stage: ''
    ###
    # Stage: ${stage.name}
    echo "Destroying ${stage.name}"
    export STAGE_DIR=$STAGES_ROOT/${stage.name}
    pushd $STAGES_ROOT/${stage.name}
    $(${config.urknall.build.evaluator {
      stage = stage.name;
      operation = "destroy";
      stageFileVar = "stage_files";
    }} "$@")
    popd
  '';

  shellStage = stage:
    let
      launcher = localPkgs.writeShellScript "launch-shell" ''
        export PATH=$PATH:$URKNALL_ORIGINAL_PATH
        exec ${localPkgs.bashInteractive}/bin/bash -i >/dev/tty 2>/dev/tty </dev/tty
      '';
    in
    ''
    if [[ "$URKNALL_SELECTED_STAGE" == "${stage.name}" ]]; then
      ###
      # Stage: ${stage.name}
      echo "Entering ${stage.name}"
      export STAGE_DIR=$STAGES_ROOT/${stage.name}
      pushd $STAGES_ROOT/${stage.name}
      $(${config.urknall.build.evaluator {
        stage = stage.name;
        operation = "shell";
        stageFileVar = "stage_files";
      }} "$@") ${launcher}
      popd
    fi
  '';
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) package raw; in {
    urknall.build = {
      evaluator = mkOption {
        # This is filled by makeUrknall or directly by the urknall-script.
        type = raw;
        internal = true;
        default = _: throw "No evaluator given. Did you use urknall incorrectly?";
      };

      resolve = mkOption {
        type = package;
        internal = true;
      };

      destroy = mkOption {
        type = package;
        internal = true;
      };

      apply = mkOption {
        type = package;
        internal = true;
      };

      shell = mkOption {
        type = package;
        internal = true;
      };

      build = mkOption {
        type = package;
        internal = true;
      };

      run = mkOption {
        type = package;
        internal = true;
      };
    };
  };

  config = {
    urknall.build.apply =
      localPkgs.writeShellScript "apply" ''
        set -ueo pipefail

        ${stageHead}
        ${scriptHead}
        ${builtins.concatStringsSep "\n" (map (stage: "${applyStage stage}\n${resolveStage stage}") config.urknall.stageList)}
      '';

    urknall.build.destroy =
      localPkgs.writeShellScript "destroy" ''
        set -ueo pipefail

        ${stageHead}
        ${scriptHead}

        ${builtins.concatStringsSep "\n" (map (resolveStage) config.urknall.stageList)}
        ${builtins.concatStringsSep "\n" (map (destroyStage) (lib.lists.reverseList config.urknall.stageList))}
      '';

    urknall.build.shell =
      localPkgs.writeShellScript "shell" ''
        set -ueo pipefail

        ${stageHead}
        ${scriptHead}

        URKNALL_SELECTED_STAGE="$1"
        shift 1

        # Resolve variables first
        ${builtins.concatStringsSep "\n" (map (resolveStage) config.urknall.stageList)}
        ${builtins.concatStringsSep "\n" (map (shellStage) config.urknall.stageList)}
      '';

    urknall.build.build =
      localPkgs.writeShellScript "build" ''
        set -ueo pipefail

        ${stageHead}
        ${scriptHead}

        URKNALL_SELECTED_STAGE="$1"
        shift 1

        URKNALL_SELECTED_ARTIFACT="$1"
        shift 1

        # Resolve variables first
        ${builtins.concatStringsSep "\n" (map (resolveStage) config.urknall.stageList)}
      '';

    urknall.build.run =
      localPkgs.writeShellScript "run" ''
        set -ueo pipefail

        OPERATION=$1
        shift

        case "$OPERATION" in
          apply)
            exec ${config.urknall.build.apply} "$@"
            ;;

          destroy)
            exec ${config.urknall.build.destroy} "$@"
            ;;

          shell)
            exec ${config.urknall.build.shell} "$@"
            ;;

          stages)
            echo Found stages: ${builtins.concatStringsSep ", " config.urknall.stageList}
            ;;

          *)
            echo Unknown operation "'$OPERATION'".
            echo "urknall [apply|destroy] [TARGET] [OPTIONS...]"
            exit 1
        esac
      '';
  };
}

