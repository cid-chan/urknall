{ lib, config, localPkgs, ... }:
let
  notices = "# ${config.urknall.build.assertions} \n # ${config.urknall.build.warnings}";
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) package; in {
    urknall.build = {
      apply = mkOption {
        type = package;
        internal = true;
      };

      destroy = mkOption {
        type = package;
        internal = true;
      };

      resolve = mkOption {
        type = package;
        internal = true;
      };

      shell = mkOption {
        type = package;
        internal = true;
      };
    };
  };

  config = {
    urknall.build.apply = localPkgs.writeShellScript "apply" ''
      ${notices}
      ##
      # This file applies the configuration
      ${config.urknall.appliers}
    '';
    urknall.build.destroy = localPkgs.writeShellScript "destroy" ''
      ${notices}
      ##
      # This file destroys the configuration
      ${config.urknall.destroyers}
    '';
    urknall.build.resolve = localPkgs.writeShellScript "resolve" ''
      ${notices}
      ##
      # This file resolves the futures
      ${config.urknall.resolvers}
    '';

    urknall.build.shell = localPkgs.writeShellScript "shell" ''
      ${notices}
      ##
      # This file resolves the futures
      ${config.urknall.shell}
      exec "$@"
    '';
  };
}
