{ lib, config, localPkgs, ... }:
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
    };
  };

  config = {
    urknall.build.apply = localPkgs.writeShellScript "apply" ''
      ##
      # This file applies the configuration
      ${config.urknall.appliers}
    '';
    urknall.build.destroy = localPkgs.writeShellScript "destroy" ''
      ##
      # This file destroys the configuration
      ${config.urknall.destroyers}
    '';
    urknall.build.resolve = localPkgs.writeShellScript "resolve" ''
      ##
      # This file resolves the futures
      ${config.urknall.resolvers}
    '';
  };
}
