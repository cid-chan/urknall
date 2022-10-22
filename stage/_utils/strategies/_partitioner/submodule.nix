{ config, lib, ... }:
let
  utils = import ./utils.nix { inherit lib; };
  partitionTypeDefaultMap = {
    "swap" = "swap";
    "fat" = "efi";
    "tmpfs" = "none";
    "bind" = "none";
  };
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) str int oneOf enum nullOr; in {
    label = mkOption {
      type = str;
      default = config._module.args.name;
      description = ''
        The name of the server.
      '';
    };

    drive = mkOption {
      type = str;
      description = ''
        The drive to put the partition on.
        If the drive is a bind-mount, this defines the bind folder.
      '';
    };

    size = mkOption {
      type = str;
      description = ''
        The size of the partition.
        Tmpfs can only suffixed sizes.
        Everything else is managed by gparted.
      '';
    };

    fsType = mkOption {
      type = enum [ "ext2" "ext3" "ext4" "btrfs" "tmpfs" "bind" "swap" "fat" ];
      description = ''
        The filesystem type.
      '';
    };

    partitionType = mkOption {
      type = enum [ "efi" "swap" "linux" "none"];
      default = utils.byMap partitionTypeDefaultMap "linux" config.fsType;
      description = ''
        Defines the partition type.
        It is usually automatically detected by the used filesystem.
      '';
    };

    mountPoint = mkOption {
      type = nullOr str;
      description = ''
        Defines where the partition should be mounted.
        Omit this option if this is a swap partition.
      '';
    };
  };

  config = {
    mountPoint = lib.mkDefault (lib.mkIf (config.fsType == "swap") null);
    drive = lib.mkDefault (lib.mkIf (config.fsType == "tmpfs") "none");
  };
}
