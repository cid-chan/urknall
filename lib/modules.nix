{ nixpkgs, ... }:
{
  mkOptionDefault = nixpkgs.lib.mkOverride 1500;
}
