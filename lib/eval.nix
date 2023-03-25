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
          mkFuture = 
            if stage == "!urknall::documentation" then
              (_: name: "<future stage='<stage>' name='${name}'>")
            else
              lib.futures.mkFuture futures;

          types = super.types // {
            nixosConfigWith = { extraModules ? [], specialArgs ? {}, system ? null}: 
              super.types.mkOptionType {
                name = "Toplevel NixOS Config.";
                description = ''
                  A specification of the desired configuration of the target.
                '';

                merge = loc: defs: (import "${toString nixpkgs}/nixos/lib/eval-config.nix") {
                  specialArgs = {
                    inherit futures;
                    urknallConfig = urknall.config;
                  } // specialArgs // extraArgs;

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
    , systems ? [ "x86_64-linux" ]
    , ... 
    }@attrs:
    let
      extraAttrs = builtins.removeAttrs attrs [ "futures" "stage" "system" "modules" "pkgs" ];

      fakeFlake = system: (pkgs system).writeTextFile {
        name = "flake.nix";
        text = ''
          {
            inputs.source.url = "@FLAKE_PATH@";
            outputs = { self, source }:
              {
                urknall-resolve.${system}.default = 
                  let 
                    instance = source.@FLAKE_ATTR@.${system};
                    resolved = instance.withFutures "''${toString ./resolves}/";
                  in
                  {
                    urknall = instance.urknall;
                    modules = [ instance.modules ];
                    runner = instance.runner;
                    resolve = resolved."@STAGE@".config.stages."@STAGE@".urknall.build.resolve;
                    apply = resolved."@STAGE@".config.stages."@STAGE@".urknall.build.apply;
                    destroy = resolved."@STAGE@".config.stages."@STAGE@".urknall.build.destroy;
                    shell = resolved."@STAGE@".config.stages."@STAGE@".urknall.build.shell;
                  };
              };
          }
        '';
      };

      evaluator = 
        ({ localPkgs, ... }: {
          urknall.build.evaluator =
            { stage, operation, stageFileVar }:
            let
              nom-evaluator = localPkgs.writeShellScript "nom-evaluator" ''
                "$@" 2> >(${localPkgs.nix-output-monitor}/bin/nom --json >&2)
              '';

              nix-command = toString (localPkgs.writeShellScript "evaluator" ''
                STAGE_FILE_LOC="$1"
                shift 1

                TEMP_FLAKE=$(mktemp -d)
                (
                  export PATH=${nixpkgs.lib.makeBinPath [localPkgs.gnused]}:$PATH
                  cat ${fakeFlake localPkgs.system} | sed s#@FLAKE_PATH@#$URKNALL_FLAKE_PATH#g | sed s/@FLAKE_ATTR@/$URKNALL_FLAKE_ATTR/g | sed 's/@STAGE@/${stage}/g' > $TEMP_FLAKE/flake.nix
                  mkdir $TEMP_FLAKE/resolves
                  if [ ! -z "$STAGE_FILE_LOC" ]; then
                    cp -a $(echo $STAGE_FILE_LOC | sed "s/;/ /g") $TEMP_FLAKE/resolves
                  fi
                )
                nix build "path:''${TEMP_FLAKE}#urknall-resolve.${localPkgs.system}.default.${operation}" --log-format internal-json --json --no-link -v "$@" | ${localPkgs.jq}/bin/jq -r '"\(.[0].outputs.out)"'
                EXITCODE=''${PIPESTATUS[0]}
                rm -rf $TEMP_FLAKE
                exit $EXITCODE
              '');
            in
            "${nom-evaluator} ${nix-command} \"\$${stageFileVar}\" \"$@\"";
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
          stages = nixpkgs.lib.mapAttrs (stage: _: urknall { inherit system stage; }) instance.config.stages;
          withFutures = stageFiles:
            nixpkgs.lib.mapAttrs (stage: _: urknall {
              inherit system stage stageFiles;
            }) instance.config.stages;
        };
    }) systems));
}
