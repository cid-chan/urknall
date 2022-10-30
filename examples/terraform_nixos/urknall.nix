{ config, localPkgs, lib, ... }:
let
  dc = "fsn1-dc14";
in
{
  config.urknall.stateVersion = "0.1";
  config.stages.terraform = {
    provisioners.terraform.enable = true;
    provisioners.terraform.backend.type = "local";

    provisioners.terraform.clouds.hcloud.enable = true;
    provisioners.terraform.clouds.hcloud.ssh-keys.personal = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKx7k8rivHnvsM+AqUhtXXousbwAwGHDFHa3TFrCQgpB";
    };
    provisioners.terraform.clouds.hcloud.volumes.test = {
      datacenter = dc;
      size = 10;
    };

    provisioners.terraform.clouds.hcloud.networks.test = {
      zone = "eu-central";
      ipRange = "10.0.0.0/16";
      subnets = ["10.0.0.0/24"];
    };

    provisioners.terraform.clouds.hcloud.servers.private-test-2 = {
      type = "cpx11";
      datacenter = dc;
      sshKeys = [
        config.stages.terraform.provisioners.terraform.clouds.hcloud.ssh-keys.personal.id
      ];
      networks = {
        "10.0.0.0/24" = {
          network = "test";
          ip = "10.0.0.3";
        };
      };

      ipv4 = false;

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

              networking.interfaces.enp7s0 = {
                ipv4.routes = [
                  {
                    address = "0.0.0.0";
                    prefixLength = 0;
                    via = "10.0.0.2";
                    options = {
                      onlink = "";
                    };
                  }
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

    provisioners.terraform.clouds.hcloud.servers.test = {
      type = "cpx11";
      datacenter = dc;
      sshKeys = [
        config.stages.terraform.provisioners.terraform.clouds.hcloud.ssh-keys.personal.id
      ];
      volumes = [
        "test"
      ];
      networks = {
        "10.0.0.0/24" = {
          network = "test";
          ip = "10.0.0.2";
          routes = [
            "0.0.0.0/0"
          ];
        };
      };

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
          persist = {
            drive = "/tmp/volumes/test";
            mountPoint = "/persist";
            fsType = "btrfs";
            size = null;
            reformat = false;
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
                device = "/dev/disk/by-label/root";
                fsType = "btrfs";
              };
              fileSystems."/boot" = {
                device = "/dev/disk/by-label/boot";
                fsType = "ext4";
              };
              fileSystems."/persist" = {
                device = "/dev/disk/by-label/persist";
                fsType = "btrfs";
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
              device = "/dev/disk/by-label/root";
              fsType = "btrfs";
            };
            fileSystems."/boot" = {
              device = "/dev/disk/by-label/boot";
              fsType = "ext4";
            };
            fileSystems."/persist" = {
              device = "/dev/disk/by-label/persist";
              fsType = "btrfs";
            };

            boot.cleanTmpDir = true;
            zramSwap.enable = true;
            networking.hostName = lib.mkDefault "test";
            services.openssh.enable = true;

            networking.nat = {
              enable = true;
              # externalIP = config.stages.terraform.provisioners.terraform.clouds.hcloud.servers.test.addresses.ipv4;
              # internalIPs = [ config.stages.terraform.provisioners.terraform.clouds.hcloud.networks.test.ipRange ];
              externalInterface = "enp1s0";
              internalInterfaces = [ "enp7s0" ];
            };
            
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
