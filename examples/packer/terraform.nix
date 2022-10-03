{ config, lib, stages, ... }:
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
      datacenter = "fsn1-dc14";
      snapshot = stages.packer.provisioners.packer.hcloud.test.snapshotId;
      rdns = "test.tf-example-packer.urknall.dev";
    };
  };
}
