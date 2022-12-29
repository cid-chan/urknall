{ nixpkgs, ... }:
{
  resolveFutures = stageFiles:
    if stageFiles == "" || stageFiles == null then
      {}
    else
      let 
        pathes = 
          if nixpkgs.lib.hasSuffix "/" stageFiles then
            let
              fileNames = builtins.attrNames (builtins.readDir stageFiles);
            in
            (map (name: "${stageFiles}${name}") fileNames)
          else
            nixpkgs.lib.splitString ";" stageFiles;
        
        ensureIsObject = v:
          if v == null then
            {}
          else
            v;
      in 
      builtins.foldl' (p: n: p//n) {} (map (path: ensureIsObject (builtins.fromJSON (builtins.readFile path))) pathes);

  mkFuture = futures: stage: name:
    if (builtins.hasAttr stage futures && futures.${stage} != null) then (
      if builtins.hasAttr name futures.${stage} then
        futures.${stage}.${name}
      else
        throw "The value ${stage}.${name} has not been resolved yet."
    ) else
      throw "The stage ${stage} has not been resolved yet (when trying to evaluate ${stage}.${name})";
}
