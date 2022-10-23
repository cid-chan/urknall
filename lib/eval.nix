{ nixpkgs, flake-utils, dag, eval, futures, lib, ... }:
{
  buildUrknall = 
    { system, modules ? [], extraArgs ? {}
    , stage ? "!urknall", futures ? {}
    , pkgs ? import nixpkgs.outPath { inherit system; }
    , ...
    }@attrs:
    let
      rootSystem = system;

      specialArgs = {
        inherit stage futures;

        stagePath = ./../stage;
        stackPath = ./../stacks;

        modulesPath = throw "modulesPath is supported in urknall.";
        localPkgs = pkgs;
        stages = urknall.config.stages;
      } // extraArgs;

      extraAttrs = builtins.removeAttrs attrs [ "modules" "stage" "specialArgs" "futures" "system" ];
      extendedLib = 
        nixpkgs.lib.extend(self: super: { 
          urknall = lib.__finished__; 
          mkFuture = lib.futures.mkFuture futures;

          types = super.types // {
            nixosConfigWith = { extraModules ? [], specialArgs ? {}, system ? null}: 
              super.types.mkOptionType {
                name = "Toplevel NixOS Config.";
                description = ''
                  A specification of the desired configuration of the target.
                '';

                merge = loc: defs: (import "${toString nixpkgs}/nixos/lib/eval-config.nix") {
                  specialArgs = {
                    inherit self futures;
                  } // specialArgs;

                  modules = [
                    ({
                      _file = "module at ${__curPos.file}:${toString __curPos.line}";
                      nixpkgs = 
                        if system == rootSystem then
                          {
                            hostPlatform = system;
                          }
                        else
                          {
                            buildPlatform = rootSystem;
                            hostPlatform = system;
                          };
                    })
                  ] ++ (map (x: x.value) defs);
                };
              };

            nixosConfig = self.types.nixosConfigWith {};

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

  mkUrknall = 
    { modules
    , pkgs ? (system: import nixpkgs.outPath { inherit system; })
    , ... 
    }@attrs:
    let
      extraAttrs = builtins.removeAttrs attrs [ "futures" "stage" "system" "modules" "pkgs" ];

      evaluator = 
        ({ localPkgs, ... }: {
          urknall.build.evaluator =
            { stage, operation, stageFileVar }:
            builtins.concatStringsSep " " [
              "nix-build"
              "--no-out-link ${toString ../urknall/flakes.nix}"
              "--argstr path \"$URKNALL_FLAKE_PATH\""
              "--argstr attr \"$URKNALL_FLAKE_ATTR\""
              "--argstr stage \"${stage}\""
              "--argstr stageFiles \"\$${stageFileVar}\""
              "-A ${operation}"
            ];
        });

      urknall = 
        { system, stage, stageFiles ? null }:
        eval.buildUrknall ({
          inherit system stage;
          futures = futures.resolveFutures stageFiles;
          modules = [evaluator] ++ modules;
          pkgs = pkgs system;
        } // extraAttrs);

      makeOp = name:
        args: (urknall args).config.build.${name};
    in
    (builtins.listToAttrs (map (system: {
      name = system;
      value = 
        let
          instance = urknall { inherit system; stage = "!urknall"; };
        in
        { 
          inherit modules;
          urknall = instance;
          runner = instance.config.urknall.build.run; 
          stages = nixpkgs.lib.mapAttrs (_: stage: {
            apply = stageFiles: (urknall { inherit system stageFiles; stage = stage.name; }).urknall.build.apply;
            destroy = stageFiles: (urknall { inherit system stageFiles; stage = stage.name; }).urknall.build.destroy;
          }) instance.config.urknall.stageList;
        };
    }) [ "x86_64-linux" ]));
}
