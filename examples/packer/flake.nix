{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: 
    {
      urknall.default = { root, after, ... }: 
        {
          packer = root (module: import ./packer.nix (module // inputs));
          terraform = after [ "packer" ] (module: import ./terraform.nix (module // inputs));
        };
    };
}
