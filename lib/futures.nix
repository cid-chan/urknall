{ nixpkgs, ... }:
{
  buildFutures = stage_name: futures:
    rec {
      fromFuture = stage: name:
        if builtins.hasAttr stage futures then (
          if builtins.hasAttr name futures.${stage} then
            futures.${stage}.${name}
          else
            throw "The value ${stage}.${name} has not been resolved yet."
        ) else
          throw "The stage ${stage} has not been resolved yet (when trying to evaluate ${stage}.${name})";

      mkFuture = name: fromFuture stage_name name;
      mkFutureWithDefault = default: name:
        if !(builtins.hasAttr stage_name futures) then
          throw "The stage ${stage_name} has not been resolved yet"
        else (
          if builtins.hasAttr name futures.${stage_name} then
            futures.${stage_name}.${name}
          else
            default
        );
    };
}
