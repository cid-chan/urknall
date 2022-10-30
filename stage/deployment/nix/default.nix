{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) raw attrsOf enum submodule str bool; in {
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
        };
      }));
      default = {};
    };
  };

  config = {
    urknall.appliers = lib.mkMerge (lib.mapAttrsToList (name: server: 
      let
        toplevel = server.config.config.system.build.toplevel;

        fakeSSH = localPkgs.writeShellScriptBin "ssh" ''
          exec ${localPkgs.openssh}/bin/ssh \
            ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
            "$@"
        '';
      in
      ''
        echo "Deploying NixOS ${name} to ${server.ip} (with user: ${server.user})"
        (
          PATH="${fakeSSH}/bin:$PATH" nix-copy-closure \
            ${lib.optionalString (server.substituteOnDestination) "--use-substitutes"} \
            --to ssh://${server.user}@${server.ip} ${toplevel}

          ${fakeSSH}/bin/ssh \
            ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
            ${server.user}@${server.ip} \
            -- \
            ${lib.optionalString (server.useRemoteSudo) "sudo"} \
            nix-env --profile /nix/var/nix/profiles/${server.profile} -i ${toplevel}

          ${fakeSSH}/bin/ssh \
            ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
            ${server.user}@${server.ip} \
            -- \
            ${lib.optionalString (server.useRemoteSudo) "sudo"} \
            ${toplevel}/bin/switch-to-configuration ${server.applyMode}
        )
      ''
    ) config.deployments.nix);
  };
}


