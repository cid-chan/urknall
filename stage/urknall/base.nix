{ lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) lines; in {
    urknall = {
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

      shell = mkOption {
        type = lines;
        description = ''
          These commands set up a shell environment for the user to implement manual interventions.
        '';
        default = "";
      };
    };
  };
}
