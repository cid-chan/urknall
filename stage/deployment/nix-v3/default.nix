{ localPkgs, config, stages, stage, lib, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) raw attrsOf enum submodule str bool; in {
    deployments.nix-v3 = mkOption {
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

          configuration = mkOption {
            type = raw;
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
        machine = import "${server.nixpkgs}/nixos/lib/eval-config.nix" {
          inherit (server) system;
          specialArgs = {
            inherit lib stage;
            stages = stages // { 
              "${stage}" = {
                inherit config;
              };
            };
          };
          modules = [
            ({
              imports = [
                server.configuration
              ];
            })
          ];
        };

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
            --to ${if server.substituteOnDestination then "ssh" else "ssh-ng"}://${server.user}@${server.ip} ${machine.config.system.build.toplevel}

          ssh \
            ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
            ${server.user}@${server.ip} \
            -- \
            ${lib.optionalString (server.useRemoteSudo) "sudo"} \
            nix --experimental-features "nix-command" profile install --profile /nix/var/nix/profiles/${server.profile} ${machine.config.system.build.toplevel}

          ssh \
            ${lib.optionalString (!server.checkHostKeys) "-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"} \
            ${server.user}@${server.ip} \
            -- \
            ${lib.optionalString (server.useRemoteSudo) "sudo"} \
            ${machine.config.system.build.toplevel}/bin/switch-to-configuration ${server.applyMode}
        )
      ''
    ) config.deployments.nix-v3);
  };
}

