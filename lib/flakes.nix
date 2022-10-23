{ nixpkgs, flakes, ... }:
{
  followPath = attr: root:
    builtins.foldl' ({ value, success }@current: a: 
      if !success then
        current
      else if builtins.hasAttr a value then
        { value = value.${a}; success = true; }
      else
        { value = null; success = false; }
    ) { value = root; success = true; } (nixpkgs.lib.splitString "." attr);

  tryAttrs = attrs: root:
    let
      resolver = current: attr:
        if current != null then
          current
        else
          let
            attempt = flakes.followPath attr root;
          in
          if attempt.success then
            { inherit (attempt) value; }
          else
            null;
    in
    (builtins.foldl' resolver null attrs).value;
}
