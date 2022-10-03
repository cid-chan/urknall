{ lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) lines; in {
    infrastructure = {
      appliers = mkOption {
        type = lines;
        description = ''
          These commands are run when running `urknall run`.
        '';
        default = "";
      };

      destroyers = mkOption {
        type = lines;
        description = ''
          These commands are run when running `urknall destroy`.
        '';
        default = "";
      };

      resolvers = mkOption {
        type = lines;
        description = ''
          These commands return json documents representing resolved futures for the following stage.
        '';
        default = "";
      };
    };
  };

  config = {
    infrastructure.appliers = lib.mkOrder 0
      ''
        # Apply
        # set -xueo pipefail
      '';

    infrastructure.destroyers = lib.mkOrder 0
      ''
        # Apply
        # set -xueo pipefail
      '';
  };
}
