{ driveSet, tableType
, writeShellScript, writeText, lib
, coreutils, util-linux, systemd, parted
, e2fsprogs, btrfs-progs, dosfstools
}:
let
  utils = import ./utils.nix { inherit lib; };

  driveList = builtins.attrValues driveSet;

  ## Finds the parent drives
  # drive -> [string]
  parentFinder = d:
    let
      findParentsBy = f: mount:
        # (mount -> str) -> submodule -> [string]
        let
          mountPoint = f mount;
          parents = builtins.filter (drive: 
            drive.mountPoint != null &&
            lib.strings.hasPrefix drive.mountPoint mountPoint
          ) driveList;

          result = map (drive: drive.label) parents;
        in
        result;
        
      funcMap = {
        "swap" = mount: [];
        "bind" = mount: lib.unique (findParentsBy (f: f.drive) mount) ++ (findParentsBy (f: f.mountPoint) mount);
      };
    in
    (utils.byMap funcMap (findParentsBy (f: f.mountPoint)) d.fsType) d;

  mountScript = d:
    let
      simpleMount = drive: ''
        mkdir -p /mnt${drive.mountPoint}
        mount /dev/disk/by-label/${drive.label} /mnt${drive.mountPoint}
      '';
      funcMap = {
        swap = drive: "swapon /dev/disk/by-label/${drive.label}";
        bind = drive: ''
          mkdir -p /mnt${drive.mountPoint}
          mkdir -p /mnt${drive.drive}
          mount --bind /mnt${drive.drive} /mnt${drive.mountPoint}
        '';
        tmpfs = drive: ''
          mkdir -p /mnt${drive.mountPoint}
          mount -t tmpfs none /mnt${drive.mountPoint} -o size=${drive.size}
        '';
      };
    in
    (utils.byMap funcMap simpleMount d.fsType) d;

  partionAndFormatThese =
    builtins.filter
    (drive: builtins.elem drive.fsType [ "ext2" "ext3" "ext4" "btrfs" "vfat" "swap" ])
    driveList;

  requiresReformatCheckScript = drive: part:
    let
      funcMap = {
        tmpfs = device: drive: "return 1";
        swap = device: drive: ''
          if [[ "$(${util-linux}/bin/blkid -o value -s TYPE ${drive})" != "swap" ]]; then
            return 0
          fi

          return 0
        '';
      };
    in
    (utils.byMap funcMap (drive: part: ''
       if [[ "$(${util-linux}/bin/blkid -o value -s TYPE ${drive})" != "${part.fsType}" ]]; then
         return 0
       fi

       if [[ "$(${util-linux}/bin/blkid -o value -s LABEL ${drive})" != "${part.label}" ]]; then
         return 0
       fi

       return 1
    '') part.fsType) drive part;

  formatScript = d: part:
    let
      funcMap = {
        swap = device: drive: "mkswap -L '${drive.label}' ${device}";
        ext2 = device: drive: "mkfs.ext2 -L '${drive.label}' ${device}";
        ext3 = device: drive: "mkfs.ext3 -L '${drive.label}' ${device}";
        ext4 = device: drive: "mkfs.ext4 -L '${drive.label}' ${device}";
        btrfs = device: drive: "mkfs.btrfs -f -L '${drive.label}' ${device}";
        vfat = device: drive: "mkfs.vfat -F32 -L '${drive.label}' ${device}";
      };
    in
    (utils.byMap funcMap (drive: throw "Unknown partition type") part.fsType) d part;

  partitioner = {
    gpt = drive: partitions: 
      let
        types = {
          "linux" = "0FC63DAF-8483-4772-8E79-3D69D8477DE4";
          "efi" = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
          "swap" = "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F";
        };

        script =
          lib.lists.imap1 (i: part:
            "${toString i}: size=${part.size},type=${types.${part.partitionType}},name=${part.label}"
          ) partitions;
      in 
      ''
        label: gpt
        device: ${drive}
        unit: sectors

        ${builtins.concatStringsSep "\n" script}
      '';

    dos = drive: partitions:
      let
        types = {
          "linux" = "83";
          "efi" = "EF";
          "swap" = "82";
        };

        script =
          lib.lists.imap1 (i: part:
            "${utils.addPartitionIndex drive i} : size=${part.size},type=${types.${part.partitionType}}"
          ) partitions;
      in
      ''
        label: dos
        device: ${drive}
        unit: sectors

        ${builtins.concatStringsSep "\n" script}
      '';
  };
in
{
  format =
    let
      byDrive = builtins.groupBy (drive: drive.drive) partionAndFormatThese;
      formatters = lib.mapAttrsToList (drive: partitions:
        let 
          sfdiskScript = writeText "sfdisk-script" (partitioner.${tableType} drive partitions);
          format = lib.lists.imap1 (i: part: formatScript (utils.addPartitionIndex drive i) part) partitions;

          firstPart = builtins.head partitions;

          table = 
            (builtins.length partitions == 1)
            -> firstPart.size != null;

          checkScript =
            if firstPart.reformat then
              "return 0"
            else
              requiresReformatCheckScript drive firstPart;
        in 
        if table then
          ''
            ${lib.optionalString (drive != "none") ''
              wipefs -fa ${drive}
              cat ${sfdiskScript} | sfdisk ${drive}
            ''}
            ${builtins.concatStringsSep "\n" format}
          ''
        else
          ''
            if (__chk() { ${checkScript} }; __chk); then
              ${lib.optionalString (drive != "none") "wipefs -fa ${drive}"}
              ${formatScript drive firstPart}
            fi
          ''
      ) byDrive;
    in
    writeShellScript "format" ''
      export PATH=${lib.makeBinPath [coreutils util-linux e2fsprogs btrfs-progs]}
      ${builtins.concatStringsSep "\n" formatters}
    '';

  mount = 
    let 
      dag = lib.mapAttrs (k: v: 
        lib.urknall.dag.entryAfter (parentFinder v) v
      ) driveSet;

      sorted = lib.urknall.dag.topoSort dag;
      mounters = map (entry: mountScript entry.data) sorted.result;
    in 
    writeShellScript "mount" ''
      export PATH=${lib.makeBinPath [coreutils util-linux systemd parted]}
      set -xueo pipefail
      ${builtins.concatStringsSep "\n" (map (drive: ''
        echo Waiting for the partitions to show up...

        while [[ ! -e /dev/disk/by-label/${drive.label} ]]; do
          if command -v partprobe; then
            partprobe ${drive.drive}
          fi
          if command -v udevadm; then
            udevadm trigger
          fi
          sleep 1
        done
      '') partionAndFormatThese)}

      echo Mounting...
      ${builtins.concatStringsSep "\n" mounters}
    '';
}
