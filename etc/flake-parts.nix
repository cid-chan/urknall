self:
{ config, lib
, withSystem
, ...
}:
let
  urknallType = lib.mkOptionType {
    name = "Toplevel Urknall Configuration.";
    description = ''
      A specification of a urknall-based infrastructure.
    '';

    merge = loc: defs:
      self.lib.mkUrknall {
        pkgs = system: withSystem system ({pkgs, ...}: pkgs);
        systems = config.systems;
        modules = defs;
      };
  };
in
{
  options = {
    urknallConfigurations = lib.mkOption {
      type = lib.types.attrsOf urknallType;
      default = {};
      description = "Urknall configurations";
    };
  };

  config = {
    flake.urknall = config.urknall;
  };
}
