self:
{ config, lib, ... }:
let
  urknallType = { system, pkgs }: lib.mkOptionType {
    name = "Toplevel Urknall Configuration.";
    description = ''
      A specification of a urknall-based infrastructure.
    '';

    merge = loc: defs:
      self.lib.mkUrknall {
        pkgs = _: pkgs;
        systems = [ system ];
        modules = defs;
      };
  };
in
{
  config = {
    perSystem = { system, pkgs, ... }:
      {
        options = {
          urknall = mkOption {
            type = lazyAttrsOf (urknallType { inherit system pkgs; });
            description = ''
              A named set of urknall configurations.
            '';
            default = {};
          };
        };
      }
    flake = {
      perSystem.flake.urknall = lib.mapAttrs (k: v: v.urknall) config.systems;
    };
  };
}
