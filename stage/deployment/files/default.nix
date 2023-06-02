{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) attrsOf submodule str; in {
    deployments.files = mkOption {
      description = lib.mdDoc ''
        This deployment strategy uploads files with the given permission to a remote system.
      '';
      default = {};
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          host = mkOption {
            type = str;
            default = config._module.args.name;
            description = lib.mdDoc ''
              The host to connect to.
            '';
          };
          files = mkOption {
            type = attrsOf (submodule ./../../_utils/strategies/files/submodule.nix);
            default = {};
            description = lib.mdDoc ''
              The files to upload to the host.
            '';
          };
        };
      }));
    };
  };

  config = {
    urknall.appliers = lib.mkIf (config.deployments.files != {}) (
      let
        commands = localPkgs.writeText "command-list" (
          builtins.concatStringsSep "\n" (map (v: ''
            ${localPkgs.callPackage ./../../_utils/strategies/files/default.nix {
              module = v.files;
            }} ${v.host}
          '') (builtins.attrValues config.deployments.files))
        );
      in
      ''
        cat ${commands} | ${localPkgs.parallel}/bin/parallel --verbose --linebuffer -j${toString config.deployments.concurrency} "${localPkgs.bash}/bin/bash -c {}"
      '' 
    );
  };
}
