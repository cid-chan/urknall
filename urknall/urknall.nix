{ flake_path, root_flake, stageFiles ? null }:
let
  urknall = builtins.getFlake root_flake;
  nixpkgs = urknall.inputs.nixpkgs;

  strace = s: builtins.trace s s;

  stageResolves =
    if stageFiles == "" || stageFiles == null then
      {}
    else
      let 
        pathes = nixpkgs.lib.splitString ";" stageFiles;
        
        ensureIsObject = v:
          if v == null then
            {}
          else
            v;
      in 
      builtins.foldl' (p: n: p//n) {} (map (path: ensureIsObject (builtins.fromJSON (builtins.readFile path))) pathes);

  path = urknall.lib.flakes.getFlakePath flake_path;
  attr = urknall.lib.flakes.getDataAttr "default" flake_path;

  flake = builtins.getFlake path;

  rawDag = urknall.lib.tryAttrs ["urknall.${attr}" attr] flake.outputs;
  stages = urknall.lib.eval.evaluate {
    stages = rawDag;
    futures = stageResolves;
  };

  buildOperations = name:
    builtins.listToAttrs (map (stage: {
      name = stage.name;
      value = nixpkgs.legacyPackages.${builtins.currentSystem}.writeShellScript "${stage.name}-${name}.sh" 
        stage.eval.config.infrastructure.${name};
    }) stages);
in
  {
    operations = {
      run = buildOperations "appliers";
      destroy = buildOperations "destroyers";
      resolvers = buildOperations "resolvers";
    };

    scripts = {
      run = urknall.lib.buildScript { operation = "run"; inherit stages; };
      destroy = ''
        ${urknall.lib.buildScript { operation = "none"; inherit stages; }}
        ${urknall.lib.buildScript { operation = "destroy"; stages = (nixpkgs.lib.reverseList stages); doResolves = false;}}
      '';
    };
  }
