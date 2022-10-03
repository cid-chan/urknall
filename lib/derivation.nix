{ nixpkgs, ... }:
let
  inherit (builtins) head;
  inherit (nixpkgs.lib.strings) hasPrefix removePrefix splitString;
in
{
  # drv -> string
  derivationHash = drv:
    let
      inherit (drv) outPath;
    in
    if !(hasPrefix "/nix/store/" outPath) then
      throw "'${toString drv}' is not a derivation."
    else
      head (splitString "-" (removePrefix "/nix/store/" outPath));
}
