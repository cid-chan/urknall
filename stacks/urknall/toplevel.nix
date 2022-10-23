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

  resolveStage = stage: ''
    ###
    # Stage: ${stage.name}
    echo "Resolving variables of ${stage.name}"
    export STAGE_DIR=$STAGES_ROOT/${stage.name}
    pushd $STAGES_ROOT/${stage.name} >/dev/null 2>/dev/null
    $(${config.urknall.build.evaluator {
      stage = stage.name;
      operation = "resolve";
      stageFileVar = "stage_files";
    }} "$@") | jq -s 'add | { "${stage.name}": . }' > $RESOLVE_DIR/${stage.name}.json

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
    }} "$@")
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

      run = mkOption {
        type = package;
        internal = true;
      };
    };
  };

  config = {
    urknall.build.apply =
      localPkgs.writeShellScript "apply" ''
        ${scriptHead}
        ${builtins.concatStringsSep "\n" (map (stage: "${applyStage stage}\n${resolveStage stage}") config.urknall.stageList)}
      '';

    urknall.build.destroy =
      localPkgs.writeShellScript "destroy" ''
        ${scriptHead}

        ${builtins.concatStringsSep "\n" (map (resolveStage) config.urknall.stageList)}
        ${builtins.concatStringsSep "\n" (map (destroyStage) (lib.lists.reverseList config.urknall.stageList))}
      '';

    urknall.build.run =
      localPkgs.writeShellScript "run" ''
        OPERATION=$1
        shift

        case "$OPERATION" in
          apply)
            exec ${config.urknall.build.apply} "$@"
            ;;

          destroy)
            exec ${config.urknall.build.destroy} "$@"
            ;;

          *)
            echo Unknown operation "'$OPERATION'".
            echo "urknall [apply|destroy] [TARGET]"
            exit 1
        esac
      '';
  };
}

