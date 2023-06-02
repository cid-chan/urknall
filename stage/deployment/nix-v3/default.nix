{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) raw attrsOf enum submodule str bool; in {
    deployments.nix-v3 = mkOption {
      description = lib.mkDoc ''
        This deployment strategy uses the new Nix v3 commands to
        deploy a new NixOS System on a remote nix-server.

        Warning: This mode is experimental!
      '';
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          ip = mkOption {
            type = str;
            description = lib.mdDoc ''
              The IP to connect to.
            '';
          };

          nixpkgs = mkOption {
            type = raw;
            default = localPkgs.path;
            description = lib.mdDoc ''
              The path to nixpkgs to use.
            '';
          };

          user = mkOption {
            type = str;
            default = "root";
            description = lib.mkDoc ''
              The SSH user.
            '';
          };

          profile = mkOption {
            type = str;
            default = "system";
            description = lib.mkDoc ''
              The profile to install the system on.
            '';
          };

          system = mkOption {
            type = str;
            default = "x86_64-linux";
            description = lib.mkDoc ''
              The CPU-Architecture the remote server runs on.
            '';
          };

          applyMode = mkOption {
            type = enum [ "switch" "boot" "test" ];
            default = "switch";
            description = lib.mkDoc ''
              What nixos-rebuild command should be used.
            '';
          };

          useRemoteSudo = mkOption {
            type = bool;
            default = config.user != "root";
            description = lib.mkDoc ''
              Use sudo on the remote machine.
            '';
          };

          substituteOnDestination = mkOption {
            type = bool;
            default = false;
            description = lib.mkDoc ''
              Substitute on the remote server.
            '';
          };

          checkHostKeys = mkOption {
            type = bool;
            default = true;
            description = lib.mkDoc ''
              Check host keys when connecting to the server.
            '';
          };

          noCheckSigs = mkOption {
            type = bool;
            default = config.user == "root";
            description = lib.mkDoc ''
              Check if valid signatures are on the remote store path.
            '';
          };

          config = mkOption {
            type = lib.types.nixosConfigWith {
              inherit (config) system;
              extraModules = [
                {
                  networking.hostName = lib.mkDefault config._module.args.name;
                }
              ];
            };
            description = lib.mkDoc ''
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
          PATH="${fakeSSH}/bin:$PATH" nix \
            --experimental-features "nix-command" \
            copy \
            ${lib.optionalString (server.noCheckSigs) "--no-check-sigs"} \
            ${lib.optionalString (server.substituteOnDestination) "--substitute-on-destination"} \
            --to ${if server.substituteOnDestination then "ssh" else "ssh-ng"}://${server.user}@${server.ip} ${toplevel}

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
        )
      ''
    ) config.deployments.nix-v3);
  };
}

