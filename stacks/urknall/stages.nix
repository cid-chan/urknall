{ lib, config, ... }:
let
  modules = config.urknall.stageModules;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) stageModule attrsOf listOf str raw anything; in {
    urknall.stageList = mkOption {
      type = listOf raw;
      internal = true;
    };
    urknall.stageModules = mkOption {
      type = listOf anything;
      default = [];
    };
    stages = mkOption {
      type = attrsOf (stageModule ({ config, ... }: {
        imports = [ ./../../stage ] ++ modules;

        options = {
          stage.name = mkOption {
            type = str;
            readOnly = true;
            default = config._module.args.name;
            description = lib.mdDoc ''
              The name given to the stage. Differs from the currently active stage!
            '';
          };
          stage.after = mkOption {
            type = listOf str;
            default = [];
            description = lib.mdDoc ''
              Queue the stage after the current one.
            '';
          };

          stage.before = mkOption {
            type = listOf str;
            default = [];
            description = lib.mdDoc ''
              Make sure that the stages noted here run after the current one.
            '';
          };

        };
      }));
      default = {};
      description = ''
        The Urknall Deploy-Process is implemented in stages.
        Each stage provides dynamic values to the next stage.
      '';
    };
  };

  config = {
    urknall.stageList =
      let
        toDagEntry = stage:
          lib.urknall.dag.entryBetween
            stage.stage.before
            stage.stage.after
            stage;

        stageDag =
          lib.mapAttrs (_: toDagEntry) config.stages;

        sorted = lib.urknall.dag.topoSort stageDag;
      in
      if sorted ? result then
        sorted.result
      else
        throw "Detected cycle while trying to sort the stages: ${toString sorted}";
  };
}
