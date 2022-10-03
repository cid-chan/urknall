{ nixpkgs, flake-utils, dag, eval, futures, lib, ... }:
{
  buildUrknall = 
    { system, modules ? [], specialArgs ? {}
    , stage ? "!urknall", futures ? {}
    , pkgs ? import nixpkgs.outPath { inherit system; }
    , ...
    }@attrs:
    let
      specialArgs = {
        inherit stage futures;

        stagePath = ./../stage;
        stackPath = ./../stacks;

        modulesPath = throw "modulesPath is supported in urknall.";
        localPkgs = pkgs;
        stages = urknall.config.stages;
      };

      extraAttrs = builtins.removeAttrs attrs [ "modules" "stage" "specialArgs" "futures" "system" ];
      extendedLib = 
        nixpkgs.lib.extend(self: super: { 
          urknall = lib.__finished__; 
          mkFuture = lib.futures.mkFuture futures;

          types = super.types // {
            submodule = module: super.types.submoduleWith {
              shorthandOnlyDefinesConfig = true;
              modules = [ module ];
              inherit specialArgs;
            };

            stageModule = module: super.types.submoduleWith {
              modules = [ 
                module 
              ];
              shorthandOnlyDefinesConfig = true;
              inherit specialArgs;
            };
          };
        });

      urknall =
        extendedLib.evalModules ({
          inherit specialArgs;
          modules = [ ./../stacks/default.nix ] ++ modules;
        }) // extraAttrs;
    in
    urknall;

  mkUrknall = { self, modules, ... }@attrs:
    let
      extraAttrs = builtins.removeAttrs attrs [ "futures" "stage" "system" "modules" ];

      evaluator = 
        ({ localPkgs, ... }: {
          urknall.build.evaluator =
            { stage, operation, stageFileVar }:
            "nix-build --no-out-link ${toString ./urknall/flakes.nix} --argstr path \"$URKNALL_FLAKE_PATH\" --argstr attr \"$URKNALL_FLAKE_ATTR\" --argstr \"\$${stageFileVar}\"";
        });

      urknall = 
        { system, stage, stageFiles ? null }:
        lib.buildUrknall ({
          inherit system stage;
          futures = futures.resolveFutures stageFiles;
          modules = [evaluator] ++ modules;
        } // extraAttrs);

      makeOp = name:
        args: (urknall args).config.build.${name};
    in
    (builtins.listToAttrs (map (system: {
      key = system;
      value = 
        let
          instance = urknall { inherit system; stage = "!urknall"; };
        in
        { 
          inherit modules;
          urknall = instance;
          runner = instance.urknall.build.run; 
          stages = nixpkgs.lib.mapAttrs (_: stage: {
            apply = stageFiles: (urknall { inherit system stageFiles; stage = stage.name; }).urknall.build.apply;
            destroy = stageFiles: (urknall { inherit system stageFiles; stage = stage.name; }).urknall.build.destroy;
          }) instance.stages;
        };
    })) );
}
