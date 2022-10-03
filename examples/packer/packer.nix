{ localPkgs, ... }:
{
  config.stages.packer = {
    provisioners.packer.enable = true;
    provisioners.packer.hcloud.test = {
      serverType = "cx11";
      location = "fsn1";

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

      nixosSystem = (import "${localPkgs.path}/nixos/lib/eval-config.nix" {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, modulesPath, lib, ... }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
            config = {
              boot.cleanTmpDir = true;
              zramSwap.enable = true;
              networking.hostName = lib.mkDefault "test3";
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
          })
        ];
      });
    };
  };
}
