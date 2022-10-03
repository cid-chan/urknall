{ nixpkgs, flakes, ... }:
{
  getDataAttr = default: path:
    if nixpkgs.lib.hasInfix "#" path then
      builtins.head (builtins.tail (nixpkgs.lib.splitString "#" path))
    else
      default;

  getFlakePath = path:
    if nixpkgs.lib.hasInfix "#" path then
      builtins.head (nixpkgs.lib.splitString "#" path)
    else
      path;

  followPath = attr: root:
    builtins.foldl' (p: a: p.${a}) root (nixpkgs.lib.splitString "." attr);

  tryAttrs = attrs: root:
    let
      resolver = current: attr:
        if current != null then
          current
        else
          let
            attempt = builtins.tryEval (flakes.followPath attr root);
          in
          if attempt.success then
            { inherit (attempt) value; }
          else
            null;
    in
    (builtins.foldl' resolver null attrs).value;
}
