{ config, localPkgs, lib, ... }:
{
  config.urknall.stateVersion = "0.1";
  config.stages.terraform = {
    provisioners.terraform.enable = true;
    provisioners.terraform.backend.type = "local";
    provisioners.terraform.clouds.null.servers.test = {
      generation = "2";
      host = "192.168.33.2";

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

        direct = false;
        kexec.enable = true;
        kexec.config = {
          services.openssh.enable = true;
          networking.interfaces.ens3 = {
            ipv4.addresses = [
              {
                address = "192.168.33.2";
                prefixLength = 24;
              }
            ];
            ipv4.routes = [
              {
                address = "0.0.0.0";
                prefixLength = 0;
                via = "192.168.33.2";
              }
            ];
          };
          networking.nameservers = [
            "1.1.1.1"
            "8.8.8.8"
          ];

          users.users.root.initialPassword = "hunter2";
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB"
          ];
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

              networking.interfaces.ens3 = {
                ipv4.addresses = [
                  {
                    address = "192.168.33.2";
                    prefixLength = 24;
                  }
                ];
                ipv4.routes = [
                  {
                    address = "0.0.0.0";
                    prefixLength = 0;
                    via = "192.168.33.2";
                  }
                ];

                ];
              };

              users.users.root.initialPassword = "hunter2";
              users.users.root.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB"
              ];
              fileSystems."/" = {
                device = "/dev/disk/by-label/root";
                fsType = "btrfs";
              };
              fileSystems."/boot" = {
                device = "/dev/disk/by-label/boot";
                fsType = "ext4";
              };
            };
          });
      };
    };
  };
}
