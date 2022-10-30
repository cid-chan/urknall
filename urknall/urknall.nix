let
  self =
    (import
      (
        let lock = builtins.fromJSON (builtins.readFile ./../flake.lock); in
        fetchTarball {
          url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
          sha256 = lock.nodes.flake-compat.locked.narHash;
        }
      )
      { src = ./..; }
    ).defaultNix;
in
# Use system pkgs instead the one used by the flake.
{ pkgs ? import <nixpkgs> {}, target ? builtins.getEnv "URKNALL_IMPURE_TARGET", stage ? "!urknall", stageFiles ? null }:
let
  urknall =
    self.lib.buildUrknall {
      inherit pkgs stage;
      futures = self.lib.resolveFutures stageFiles;
      system = builtins.currentSystem;
      modules = [
        target
    
        ({ localPkgs, ... }: {
           urknall.build.evaluator =
             { stage, operation, stageFileVar }:
             "nix-build --no-out-link ${toString ./urknall.nix} -A ${operation} --argstr target \"$URKNALL_IMPURE_TARGET\" --argstr stage ${stage} --argstr stageFiles \"\$${stageFileVar}\"";
        })
      ];
    };
in
{
  inherit urknall;
  modules = [ target ];

  runner = urknall.config.urknall.build.run;
  resolve = urknall.config.stages.${stage}.urknall.build.resolve;
  apply = urknall.config.stages.${stage}.urknall.build.apply;
  destroy = urknall.config.stages.${stage}.urknall.build.destroy;
  shell = urknall.config.stages.${stage}.urknall.build.shell;
}
