{ config, lib, stages, localPkgs, ... }:
{
  config.stages.terraform = {
    stage.after = [ "packer" ];

    provisioners.terraform.enable = true;
    provisioners.terraform.backend.type = "local";

    provisioners.terraform.clouds.hcloud.enable = true;
    provisioners.terraform.clouds.hcloud.servers.test = {
      type = "cpx11";
      datacenter = "fsn1-dc14";
      snapshot = stages.packer.provisioners.packer.hcloud.test.snapshotId;
      rdns = "test.tf-example-packer.urknall.dev";
      files = {
        "/etc/nixos/terraform.txt".file = 
          localPkgs.writeText "terraform.txt" ''
            This file has been generated on Urknall.
            This file has been provisioned with Hashicorp Terraform.
          '';
      };
    };
  };
}
