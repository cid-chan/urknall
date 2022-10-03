{ lib, config, localPkgs, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf string; in {
    urknall = {
      resolveCommands = mkOption {
        type = attrsOf string;
        default = {};
        description = ''
          Each value in this set is a command that is executed.
          The output of this command is the resolved json-value with the given name.
        '';
      };
    };
  };

  config = {
    urknall.resolvers = lib.mkMerge (lib.mapAttrsToList (key: value: ''
      ${value} | ${localPkgs.jq}/bin/jq '{ "${key}": . }'
    '') config.urknall.resolveCommands);
  };
}
