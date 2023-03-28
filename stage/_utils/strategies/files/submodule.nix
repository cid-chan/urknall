{ config, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) str int oneOf enum nullOr path; in {
    path = mkOption {
      type = str;
      default = config._module.args.name;
      description = ''
        The name of the server.
      '';
    };

    user = mkOption {
      type = str;
      default = "root";
      description = ''
        The user that should own the file.
      '';
    };

    group = mkOption {
      type = str;
      default = "root";
      description = ''
        The group that should own the file.
      '';
    };

    mode = mkOption {
      default = "0644";
      type = str;
      description = ''
        The mode that the file should have.
      '';
    };

    file = mkOption {
      type = nullOr (oneOf [ path str ]);
      description = ''
        The file to copy.
      '';
    };
  };

}
