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
  options = let inherit (lib) mkOption; inherit (lib.types) str int oneOf enum nullOr bool; in {
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
      type = nullOr str;
      description = ''
        The size of the partition.
        Tmpfs can only suffixed sizes.
        Everything else is managed by gparted.

        If the size is null, no partition table will be written.
        It is UB if size is null, but more than one partition is given for the same drive.
      '';
    };

    reformat = mkOption {
      type = bool;
      default = true;
      description = ''
        If the partition type is already matching,
        and it's label matches the label given to it,
        and the drive has no partition-table,
        and this value is set to false,
        then reformatting will be skipped.
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
    partitionType = lib.mkDefault (utils.byMap partitionTypeDefaultMap "linux" config.fsType);
  };
}
