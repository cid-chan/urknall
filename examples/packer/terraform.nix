{ config, lib, stages, ... }:
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
    };
  };
}
