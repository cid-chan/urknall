{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: 
    {
      urknall.default = { root, after, ... }: 
        {
          terraform = root (
            { config, lib, ... }:
            {
              config = {
                provisioners.terraform.enable = true;
                provisioners.terraform.backend.type = "local";

                provisioners.terraform.clouds.hcloud.enable = true;
                provisioners.terraform.clouds.hcloud.ssh-keys.personal = {
                  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB";
                };
                provisioners.terraform.clouds.hcloud.servers.test = {
                  type = "cpx11";
                  location = "fsn1";
                  sshKeys = [
                    config.provisioners.terraform.clouds.hcloud.ssh-keys.personal.id
                  ];
                };
              };
            }
          );

          deploy = after [ "terraform" ] (
            { config, lib, stages, ... }:
            {
              config = {
                deployments.nix-v3.test = {
                  ip = stages.terraform.provisioners.terraform.clouds.hcloud.servers.test.addresses.ipv4;
                  checkHostKeys = false;
                  substituteOnDestination = true;

                  configuration = 
                    { pkgs, ... }:
                    {
                      imports = [
                        stages.terraform.provisioners.terraform.clouds.hcloud.servers.test.nixosModule
                      ];

                      config = {
                        users.users.root.openssh.authorizedKeys.keys = [
                          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB"
                        ];
                        environment.systemPackages = [
                          pkgs.btop
                        ];
                      };
                    };
                };
              };
            }
          );
        };
    };
}
