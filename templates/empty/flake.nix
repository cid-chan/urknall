{
  description = "An empty urknall project.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.urknall.url = "github:cid-chan/urknall";

  outputs = { self, nixpkgs, urknall, ... }@inputs:
    {
      urknall.default = urknall.lib.mkUrknall {
        pkgs = (system: import "${nixpkgs.outpath}" {
          inherit system;

          # You can add some nixpkgs configuration here
        });

        # This allows you to access your flake inputs using
        # the inputs argument to a module.
        extraArgs = {
          inherit inputs;
        };

        # This tells urknall where your root module is.
        modules = [
          ./urknall.nix
        ];
      };
    }
}
