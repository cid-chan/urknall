{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixos-generators.url = "github:nix-community/nixos-generators";
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: 
    let 
      by-system = flake-utils.lib.eachSystem ["x86_64-linux"] (system: 
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.git-crypt
            ];
          };

          devShells.docs = pkgs.mkShell {
            buildInputs = [
              pkgs.hugo
              pkgs.yarn
            ];
          };

          packages.docs = pkgs.callPackage ./docs { inherit self; python3 = pkgs.python310; };

          packages.options = 
            (self.lib.eval.buildUrknall {
              inherit system;
              stage = "!urknall::documentation";
              modules = [ { stages = {}; } ];
            }).config.urknall.build.manual.json;

          packages.urknall = pkgs.writeShellScriptBin "urknall" (
            let
              rawScript = (builtins.readFile ./urknall/runner.sh);
              replacements = {
                urknall_nix = toString ./urknall/urknall.nix;
                flakes_nix = toString ./urknall/flakes.nix;
              };

              names = builtins.attrNames replacements;
              key = map (k: "@${k}@") names;
              values = map (k: toString (replacements.${k})) names;

              replacedScript = nixpkgs.lib.replaceStrings key values rawScript;
            in
            ''
              NIX_BIN_PATH=$(dirname $(realpath $(which nix)))
              export URKNALL_ORIGINAL_PATH="$PATH"
              export PATH=${nixpkgs.lib.makeBinPath [
                pkgs.bash 
                pkgs.jq 
                pkgs.git 
                pkgs.coreutils
                pkgs.util-linux
              ]}:$NIX_BIN_PATH
              ${replacedScript}
            ''
          );
          packages.default = self.packages.${system}.urknall;
        }
      );

      all-systems = {
        lib = import ./lib inputs;
        flakeModules.default = ./etc/flake-parts.nix;
        flakeModule = ./etc/flake-parts.nix;

        templates = {
          empty = {
            path = ./templates/empty;
            description = "A simple empty urknall configuration using a flake.";
          };
          flake-parts = {
            path = ./templates/flake-parts;
            description = "A simple empty urknall configuration using a flake-parts.";
          };
        };
      };
    in
    all-systems // by-system;
}
