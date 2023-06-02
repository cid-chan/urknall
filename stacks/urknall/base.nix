{ lib, config, ... }:
let
  CURRENT_VERSION = "0.1";
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) listOf nullOr submodule bool package str; in {
    urknall.stateVersion = mkOption {
      type = nullOr str;
      description = lib.mdDoc ''
        The stateVersion defines when the project was first created.
        You should set this value once,
        namely at the start of the project.

        If you update your urknall version,
        it will then automatically add the neccessary upgrade code to each stage.
        This minimizes recreating resources.
      '';
      default = null;
    };

    urknall.build.assertions = mkOption {
      type = str;
      internal = true;
    };

    urknall.build.warnings = mkOption {
      type = str;
      internal = true;
    };

    urknall.assertions = mkOption {
      description = ''
        A set of assertions that aborts the evaluation when their condition evaluates to `true`.
      '';
      default = [];
      type = listOf (submodule ({ options = {
        condition = mkOption {
          type = bool;
          description = lib.mdDoc ''
            The condition to check.

            If the condition evaluates to true,
            the build will fail,
            with each warning being printed.
          '';
        };
        message = mkOption {
          type = str;
          description = lib.mdDoc ''
            The message to print out.
          '';
        };
      }; }));
    };

    urknall.warnings = mkOption {
      description = ''
        A set of warnings that should be printed when their condition evaluates to `true`.
      '';
      default = [];
      type = listOf (submodule ({ options = {
        condition = mkOption {
          type = bool;
          description = lib.mdDoc ''
            The condition to check.

            If the condition evaluates to true,
            with a warning will be printed.
          '';
        };
        message = mkOption {
          type = str;
          description = lib.mdDoc ''
            The message to print out.
          '';
        };
      }; }));
    };
  };

  config = {
    urknall.assertions = [
      {
        condition = config.urknall.stateVersion == null;
        message = ''
          You did not specify 'urknall.stateVersion'.
          Please set it once, and if possible, never change it.

          Example: 'urknall.stateVersion = "${CURRENT_VERSION}".'
        '';
      }
    ];

    urknall.build.assertions =
      let
        messages = lib.urknall.formatAssertions config.urknall.assertions;
      in
      if messages == null then
        ""
      else
        throw "Failed assertions:\n${messages}";

    urknall.build.warnings =
      let
        messages = lib.urknall.formatAssertions config.urknall.warnings;
      in
      if messages == null then
        ""
      else
        lib.warn "Some warnings have been emitted:\n${messages}" "";
  };
}
