{ config, localPkgs, lib, ... }:
{
  config.stages.terraform = {
    provisioners.terraform.enable = true;
    provisioners.terraform.backend.type = "local";

    provisioners.terraform.clouds.hcloud.enable = true;
    provisioners.terraform.clouds.hcloud.ssh-keys.personal = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB";
    };
    provisioners.terraform.clouds.hcloud.servers.test = {
      type = "cpx11";
      datacenter = "fsn1-dc14";
      sshKeys = [
        config.stages.terraform.provisioners.terraform.clouds.hcloud.ssh-keys.personal.id
      ];

      system = {
        drives = {
          root = {
            drive = "/dev/sda";
            mountPoint = "/";
            fsType = "btrfs";
            size = "";
          };
          boot = {
            drive = "/dev/sda";
            mountPoint = "/boot";
            fsType = "ext4";
            size = "2G";
          };
        };

        config =
          ({ pkgs, modulesPath, lib, ... }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
            config = {
              boot.cleanTmpDir = true;
              zramSwap.enable = true;
              networking.hostName = lib.mkDefault "test";
              services.openssh.enable = true;
            
              boot.loader.grub.device = "/dev/sda";
              boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
              boot.initrd.kernelModules = [ "nvme" ];
              users.users.root.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB"
              ];
              fileSystems."/" = {
                device = "/dev/sda2";
                fsType = "btrfs";
              };
              fileSystems."/boot" = {
                device = "/dev/sda1";
                fsType = "ext4";
              };
            };
          });
      };

      rdns = "test.tf-example-terraform-nix.urknall.dev";
      files = {
        "/etc/nixos/terraform.txt".file = 
          localPkgs.writeText "terraform.txt" ''
            This file has been generated on Urknall.
            This file has been provisioned with Hashicorp Terraform.
          '';
      };
    };
  };

  config.stages.deploy = {
    stage.after = [ "terraform" ];
    deployments.nix-v3.test = {
      ip = config.stages.terraform.provisioners.terraform.clouds.hcloud.servers.test.addresses.ipv4;
      checkHostKeys = false;
      substituteOnDestination = true;

      config = 
        { pkgs, ... }:
        {
          config = {
            fileSystems."/" = {
              device = "/dev/sda2";
              fsType = "btrfs";
            };
            fileSystems."/boot" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };
            boot.cleanTmpDir = true;
            zramSwap.enable = true;
            networking.hostName = lib.mkDefault "test";
            services.openssh.enable = true;
            
            boot.loader.grub.device = "/dev/sda";
            boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
            boot.initrd.kernelModules = [ "nvme" ];
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
