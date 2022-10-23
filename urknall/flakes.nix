# Use system pkgs instead the one used by the flake.
{ path, attr, stage ? "!urknall", stageFiles ? null }:
let
  urknall = builtins.getFlake "path:${toString ./..}";

  flake = builtins.getFlake path;
  raw = urknall.lib.tryAttrs ["urknall.${attr}" attr] flake.outputs;

  instance = raw.${builtins.currentSystem};
in
{
  urknall = instance.urknall;
  modules = [ instance.modules ];
  runner = instance.runner;
  resolve = instance.urknall.config.stages.${stage}.urknall.build.resolve;
  apply = instance.urknall.config.stages.${stage}.urknall.build.apply;
  destroy = instance.urknall.config.stages.${stage}.urknall.build.destroy;
}
