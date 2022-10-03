{ name, btrfs }:
{ modulesPath, lib, ... }:
{
  boot.cleanTmpDir = true;
  zramSwap.enable = true;
  networking.hostName = lib.mkDefault name;
  services.openssh.enable = true;

  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = if btrfs then "btrfs" else "ext4";
  };
  fileSystems."/boot" = lib.mkIf btrfs {
    device = "/dev/sda15";
    fsType = "ext2";
  };
}
