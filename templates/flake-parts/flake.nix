
{
  description = "An empty urknall project.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.urknall.url = "github:cid-chan/urknall";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = { self, nixpkgs, flake-parts, ... }@inputs: 
    flake-parts.flake.mkFlake { inherit inputs; }
    {
      imports = [
        inputs.urknall.flakeModule
      ];

      systems = [ "x86_64-linux" ];
      urknall.default =
        { ... }:
        {
          imports = [
            ./urknall.nix
          ];
        };
    };
}
