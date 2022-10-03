{ nixpkgs, dag, eval, lib, ... }:
{
  header = {
    root = dag.entryAnywhere;
    between = dag.entryBetween;
    before = dag.entryBefore;
    after = dag.entryAfter;

    merge = parents:
      let
        merger = dag.merge (l: r: { imports = [ l r ]; });
      in
      builtins.foldl' merger (builtins.head parents) (builtins.tail parents);
  };

  evaluateStage = { stage, stages ? {}, futures ? {} }:
    nixpkgs.lib.evalModules {
      modules = [
        ./../modules
        stage.data
      ];
      specialArgs = {
        inherit futures stages;
        environment = futures."!urknall";
        stage = stage.name;
        localPkgs = import nixpkgs {
          system = builtins.currentSystem;
        };
        modulePath = ./../modules;
        lib = nixpkgs.lib // { urknall = lib.__finished__; } // (lib.futures.buildFutures stage.name futures);
      };
    };

  evaluate = { stages, futures ? {} }:
    let
      build = stages eval.header;
      sorted = dag.topoSort build;

      evaluated =
        builtins.foldl' (previousStages: currentStage: previousStages // {
          "${currentStage.name}" = {
            name = currentStage.name;
            eval = eval.evaluateStage { 
              inherit futures;
              stage = currentStage;
              stages = nixpkgs.lib.mapAttrs (k: v: v.eval.config) previousStages;
            };
          };
        }) {} sorted.result;
    in
    if sorted ? result then
      map (stage: evaluated.${stage.name}) sorted.result
    else
      throw "Found the following loops beginning with ${builtins.concatStringsSep ", " (map (e: e.name) sorted.loops)}";


  buildScript = { operation ? "none", stages, doResolves ? true }:
    let
      ops = 
        builtins.concatStringsSep "\n\n" (
          map (stage: ''
            ###
            # Stage: ${stage.name}
            mkdir -p $ROOT_DIR/stages/${stage.name}
            export STAGE_DIR=$ROOT_DIR/stages/${stage.name}

            pushd $ROOT_DIR/stages/${stage.name} >/dev/null 2>/dev/null
            echo 'Starting Stage "${stage.name}"'
            ${nixpkgs.lib.optionalString (operation != "none") ''
              bash $(nix-build --no-out-link ${toString ../urknall/urknall.nix} --arg root_flake '"${toString ./..}"' --arg flake_path "\"$URKNALL_FLAKE_PATH\"" --arg stageFiles "\"$stage_files\"" -A "operations.${operation}.${stage.name}" "$NIX_ARGS")
            ''}

            ${nixpkgs.lib.optionalString (doResolves) ''
              echo $(nix-build --no-out-link ${toString ../urknall/urknall.nix} --arg root_flake '"${toString ./..}"' --arg flake_path "\"$URKNALL_FLAKE_PATH\"" --arg stageFiles "\"$stage_files\"" -A "operations.resolvers.${stage.name}" "$NIX_ARGS")
              bash $(nix-build --no-out-link ${toString ../urknall/urknall.nix} --arg root_flake '"${toString ./..}"' --arg flake_path "\"$URKNALL_FLAKE_PATH\"" --arg stageFiles "\"$stage_files\"" -A "operations.resolvers.${stage.name}" "$NIX_ARGS") | jq -s add | jq '{ "${stage.name}" : . }' > $RESOLVE_DIR/${stage.name}.json
              if [[ -z "$stage_files" ]]; then
                stage_files="$RESOLVE_DIR/${stage.name}.json"
              else
                stage_files="$stage_files;$RESOLVE_DIR/${stage.name}.json"
              fi
            ''}
            popd >/dev/null 2>/dev/null
          '') stages
        );
    in
    ''
      # set -xueo pipefail
      set -ueo pipefail
      ROOT_DIR=$(mktemp -d)

      export SHARE_DIR=$ROOT_DIR/shared
      mkdir $SHARE_DIR

      ${nixpkgs.lib.optionalString (doResolves) ''
        mkdir -p $ROOT_DIR/resolves
        RESOLVE_DIR=$ROOT_DIR/resolves
        echo "{ \"!urknall\": { \"currentDirectory\": \"$URKNALL_LOCAL_DIRECTORY\" }}" > $ROOT_DIR/empty.json
        stage_files=$ROOT_DIR/empty.json
      ''}

      ${ops}
    '';
}
