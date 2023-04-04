{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) raw listOf attrsOf nullOr submodule str bool package; in {
    deployments.nix-copy = mkOption {
      description = ''
        This deployment strategry deploys a NixOS System to a remote NixOS server.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          target = mkOption {
            type = str;
            description = ''
              The target store to copy to.
            '';
          };

          substituteOnDestination = mkOption {
            type = bool;
            default = false;
            description = ''
              Substitute on the remote server.
            '';
          };

          checkHostKeys = mkOption {
            type = bool;
            default = true;
            description = ''
              Check host keys when connecting to the server.
            '';
          };

          signingKeyFile = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              If null, the derivations will be signed before uploading.
            '';
          };

          noCheckSigs = mkOption {
            type = nullOr str;
            default = config.user == "root";
            description = ''
              Check if valid signatures are on the remote store path.
            '';
          };

          derivations = mkOption {
            type = listOf package;
            description = ''
              The derivations to pusb
            '';
          };

          v3 = mkOption {
            type = bool;
            default = false;
            description = ''
              Use nix copy instead of nix-copy-closure to upload the derivations.
            '';
          };
        };
      }));
      default = {};
    };
  };

  config = {
    urknall.appliers = 
      let
        configs = lib.mapAttrsToList (name: server: 
          let
            toplevel = builtins.concatStringsSep " " (map (drv: "${drv}") server.derivations);

            fakeSSH = localPkgs.writeShellScriptBin "ssh" ''
              exec ${localPkgs.openssh}/bin/ssh \
                ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
                "$@"
            '';
          in
          localPkgs.writeShellScript "deploy-${name}" (
            if server.v3 then 
             ''
              PATH="${fakeSSH}/bin:$PATH" nix \
                --experimental-features "nix-command" \
                copy \
                ${lib.optionalString (server.noCheckSigs) "--no-check-sigs"} \
                ${lib.optionalString (server.substituteOnDestination) "--substitute-on-destination"} \
                --to ${server.target} ${toplevel}
             ''
            else
              ''
              PATH="${fakeSSH}/bin:$PATH" nix-copy-closure \
                ${lib.optionalString (server.substituteOnDestination) "--use-substitutes"} \
                --to ${server.target} ${toplevel}
              ''
        )) config.deployments.nix-copy;
      in
      lib.mkIf (config.deployments.nix-copy != {}) (
        let
          signedCopies = builtins.filter (cfg: cfg.signingKeyFile != null) (builtins.attrValues config.deployments.nix-copy);
        in
        ''
          set -e
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (keyFile: configs: ''
            nix --experimental-features "nix-command" store sign -rk ${keyFile} ${builtins.concatStringsSep " " (lib.flatten (map (c: c.derivations) configs))}
          '') (builtins.groupBy (cfg: cfg.signingKeyFile) signedCopies))}
          cat ${localPkgs.writeText "deployCommands" (builtins.concatStringsSep "\n" (map (c: "${c}") configs))} | ${localPkgs.parallel}/bin/parallel --verbose --linebuffer -j${toString config.deployments.concurrency} "${localPkgs.bash}/bin/bash -c {}"
        ''
      );
  };
}


