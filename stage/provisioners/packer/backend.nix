{ lib, config, stage, ... }:
let
  cfg = config.provisioners.packer;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) listOf attrsOf submodule str raw lines; in {
    provisioners.packer.project = {
      destroys = mkOption {
        type = listOf str;
        default = [];
        description = lib.mkDoc ''
          Code to destroy snapshots when running `urknall destroy`.
        '';
      };

      resolves = mkOption {
        type = listOf str;
        default = [];
        description = lib.mkDoc ''
          Urknall Packer will assume that snapshots are reproducable.
          Because of that, resolves can be done by just querying what snapshots match.
        '';
      };

      excludes = mkOption {
        type = listOf str;
        default = [];
        description = lib.mkDoc ''
          Urknall Packer will assume that snapshots are reproducable.
          This is why snapshot names should have a nix derivation hash in front of them.
          Excluders check if the build already exists.
        '';
      };

      plugins = mkOption {
        default = {};
        type = attrsOf (submodule ({ config, ... }: {
          options = {
            name = mkOption {
              type = str;
              default = config._module.args.name;
              description = lib.mkDoc ''
                The name of the private key.
              '';
            };

            source = mkOption {
              type = str;
              description = lib.mkDoc ''
                The source of the provider.
              '';
            };

            version = mkOption {
              type = str;
              description = lib.mkDoc ''
                The version of the provider.
              '';
            };
          };
        }));
        description = ''
          Defines a list of providers to install with packer.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    provisioners.packer.project.module = ''
      packer {
        ${lib.optionalString (cfg.project.plugins != {}) ''
          required_plugins {
            ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
              ${v.name} = {
                source = "${v.source}"
                version = "${v.version}"
              }
            '') cfg.project.plugins)}
          }
        ''}
      }
    '';

    provisioners.packer.project.setup = lib.mkIf (cfg.project.excludes != []) (lib.mkOrder 1100 ''
      PKR_EXCLUDES=""
      ${builtins.concatStringsSep "\n" (map (excluder: ''
        PKR_EXCLUDED="$(${excluder})"
        if [[ ! -z "$PKR_EXCLUDED" ]]; then
          if [[ -z "$PKR_EXCLUDES" ]]; then
            PKR_EXCLUDES="$PKR_EXCLUDED"
          else
            PKR_EXCLUDES="$PKR_EXCLUDES,$PKR_EXCLUDED"
          fi
        fi
      '') cfg.project.excludes)}

      if [[ ! -z "PKR_EXCLUDES" ]]; then
        PKR_EXCLUDES="-except=$PKR_EXCLUDES"
      fi
      '');

    provisioners.packer.project.arguments = lib.mkIf (cfg.project.excludes != []) "$PKR_EXCLUDES";

    urknall.destroyers = lib.mkIf (cfg.project.destroys != []) ''
      ${builtins.concatStringsSep "\n" (map (destroy: ''
        (
          ${destroy}
        )
      '') cfg.project.destroys)}
    '';

    urknall.resolvers = lib.mkIf (cfg.project.resolves != []) ''
      ${builtins.concatStringsSep "\n" (map (resolver: ''
        (
          ${resolver}
        )
      '') cfg.project.resolves)}
    '';
  };
}
