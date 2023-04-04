{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) raw listOf attrsOf enum submodule str bool; in {
    deployments.nix = mkOption {
      description = ''
        This deployment strategry deploys a NixOS System to a remote NixOS server.
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          ip = mkOption {
            type = str;
            description = ''
              The IP to connect to.
            '';
          };

          nixpkgs = mkOption {
            type = raw;
            default = localPkgs.path;
            description = ''
              The path to nixpkgs to use.
            '';
          };

          user = mkOption {
            type = str;
            default = "root";
            description = ''
              The SSH user.
            '';
          };

          profile = mkOption {
            type = str;
            default = "system";
            description = ''
              The profile to install the system on.
            '';
          };

          system = mkOption {
            type = str;
            default = "x86_64-linux";
            description = ''
              The CPU-Architecture the remote server runs on.
            '';
          };

          applyMode = mkOption {
            type = enum [ "switch" "boot" "test" ];
            default = "switch";
            description = ''
              What nixos-rebuild command should be used.
            '';
          };

          useRemoteSudo = mkOption {
            type = bool;
            default = config.user != "root";
            description = ''
              Use sudo on the remote machine.
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

          noCheckSigs = mkOption {
            type = bool;
            default = config.user == "root";
            description = ''
              Check if valid signatures are on the remote store path.
            '';
          };

          config = mkOption {
            type = lib.types.nixosConfigWith {
              inherit (config) system;
              extraModules = {
                networking.hostName = lib.mkDefault config._module.args.name;
              };
            };
            description = ''
              The NixOS Configuration to deploy.
            '';
          };

          postActivationCommands = mkOption {
            type = listOf str;
            default = [];
            description = lib.mdDoc ''
              Run these commands after activation.
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
            toplevel = server.config.config.system.build.toplevel;

            fakeSSH = localPkgs.writeShellScriptBin "ssh" ''
              exec ${localPkgs.openssh}/bin/ssh \
                ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
                "$@"
            '';
          in
          {
            inherit name server;

            deploy = localPkgs.writeShellScript "deploy-${name}" ''
              PATH="${fakeSSH}/bin:$PATH" nix-copy-closure \
                ${lib.optionalString (server.substituteOnDestination) "--use-substitutes"} \
                --to ${server.user}@${server.ip} ${toplevel}
            '';

            switch = ''
              PATH="${fakeSSH}/bin:$PATH" nix-copy-closure \
                ${lib.optionalString (server.substituteOnDestination) "--use-substitutes"} \
                --to ${server.user}@${server.ip} ${toplevel}

              ${fakeSSH}/bin/ssh \
                ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
                ${server.user}@${server.ip} \
                -- \
                ${lib.optionalString (server.useRemoteSudo) "sudo"} \
                nix-env --profile /nix/var/nix/profiles/${server.profile} --set ${toplevel}

              ${fakeSSH}/bin/ssh \
                ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
                ${server.user}@${server.ip} \
                -- \
                ${lib.optionalString (server.useRemoteSudo) "sudo"} \
                ${toplevel}/bin/switch-to-configuration ${server.applyMode}

              ${builtins.concatStringsSep "\n" (map (cmd: ''
                ${fakeSSH}/bin/ssh \
                  ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
                  ${server.user}@${server.ip} \
                  -- \
                  ${lib.optionalString (server.useRemoteSudo) "sudo"} \
                  ${cmd}
              '') server.postActivationCommands)}
            '';
          }
        ) config.deployments.nix;

      in
      lib.mkIf (config.deployments.nix != {}) ''
        set -e
        cat ${localPkgs.writeText "deployCommands" (builtins.concatStringsSep "\n" (map (c: "${c.deploy}") configs))} | ${localPkgs.parallel}/bin/parallel --verbose --linebuffer -j${config.deployments.concurrency} "${localPkgs.bash}/bin/bash -c {}"
        ${builtins.concatStringsSep "\n" (map (c: ''
          echo "Deploying NixOS ${c.name} to ${c.server.ip} (with user: ${c.server.user})"
          ${c.switch}
        '') configs)}
      '';
  };
}


