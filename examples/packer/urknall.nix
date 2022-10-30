{ ... }:
{
  imports = [
    ./packer.nix
    ./terraform.nix
  ];
  urknall.stateVersion = "0.1";
}
