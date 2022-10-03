# Use system pkgs instead the one used by the flake.
{ path, attr, stage ? "!urknall", stageFiles ? null }:
let
  urknall = builtins.getFlake ./..;

  flake = builtins.getFlake path;
  raw = urknall.lib.tryAttrs ["urknall.${attr}" attr] flake.outputs;

  urknall = raw.${builtins.currentSystem};
in
{
  urknall = urknall.instance;
  modules = [ urknall.modules ];
  runner = urknall.runner;
  resolve = urknall.stages.resolve stageFiles;
  apply = urknall.stages.apply stageFiles;
  destroy = urknall.stages.destroy stageFiles;
}
