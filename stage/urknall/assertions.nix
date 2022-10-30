{ lib, config, ... }:
{
  options = let inherit (lib) mkOption; inherit (lib.types) listOf submodule bool str; in {
    urknall.build.assertions = mkOption {
      type = str;
      internal = true;
    };
    urknall.build.warnings = mkOption {
      type = str;
      internal = true;
    };

    urknall.assertions = mkOption {
      default = [];
      type = listOf (submodule ({ options = {
        condition = mkOption {
          type = bool;
          description = ''
            The condition to check.

            If the condition evaluates to true,
            the build will fail,
            with each warning being printed.
          '';
        };
        message = mkOption {
          type = str;
          description = ''
            The message to print out.
          '';
        };
      }; }));
    };

    urknall.warnings = mkOption {
      default = [];
      type = listOf (submodule ({ options = {
        condition = mkOption {
          type = bool;
          description = ''
            The condition to check.

            If the condition evaluates to true,
            with a warning will be printed.
          '';
        };
        message = mkOption {
          type = str;
          description = ''
            The message to print out.
          '';
        };
      }; }));
    };
  };

  config = {
    urknall.build.assertions =
      let
        messages = lib.urknall.formatAssertions config.urknall.assertions;
      in
      if messages == null then
        ""
      else
        throw "Failed assertions in stage \"${config.stage.name}\":\n${messages}";

    urknall.build.warnings =
      let
        messages = lib.urknall.formatAssertions config.urknall.warnings;
      in
      if messages == null then
        ""
      else
        lib.warn "Some warnings have been emitted in stage \"${config.stage.name}\":\n${messages}" "";

    };
}
