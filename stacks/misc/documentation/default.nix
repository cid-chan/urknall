{ config, options, localPkgs, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) package raw; in {
    urknall.build.manual = {
      raw = mkOption {
        type = raw;
        readOnly = true;
        description = ''
          The raw manual that is generated by the NixOS documentation system.
        '';
      };

      json = mkOption {
        type = package;
        readOnly = true;
        description = ''
          The JSON representation of the options.
        '';
        default = config.urknall.build.manual.raw.optionsJSON;
      };
    };
  };

  config = {
    urknall.build.manual.raw =
      localPkgs.nixosOptionsDoc {
        inherit options;
      };
  };
}
