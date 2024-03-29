{ driveSet, tableType
, runCommand, writeShellScript, writeText, lib
, coreutils, util-linux, systemd, parted, gnused, gnugrep
, e2fsprogs, btrfs-progs, dosfstools, cryptsetup, lvm2
, multipath-tools, mdadm
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
        "none" = mount: [];
      };
    in
    (utils.byMap funcMap (findParentsBy (f: f.mountPoint)) d.fsType) d;

  getattr = name: default: map:
    if builtins.hasAttr name map then
      map."${name}"
    else
      default;

  mountScript = d:
    let
      simpleMount = drive: ''
        mkdir -p /mnt${drive.mountPoint}
        mount /dev/disk/by-label/${drive.label} /mnt${drive.mountPoint}
      '';
      funcMap = {
        none = drive: "";
        luks = drive: 
          let
            password = getattr "password" null drive.extras;
            keyFile = getattr "keyFile" null drive.extras;

            unlocker = 
              if keyFile != null then
                "${cryptsetup}/bin/cryptsetup luksOpen /dev/disk/by-label/${drive.label} ${drive.label} -d /tmp/part-${drive.label}/${keyFile}"
              else
                "cat /tmp/part-${drive.label}/${password} | (${cryptsetup}/bin/cryptsetup luksOpen /dev/disk/by-label/${drive.label} ${drive.label})";
          in
          ''
            ${unlocker}
            ${mountScript (__luks_build_full_config drive)}
          '';

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
    (drive: builtins.elem drive.fsType [ "ext2" "ext3" "ext4" "btrfs" "fat" "swap" "luks" "none"])
    driveList;

  mountThese =
    builtins.filter
    (drive: builtins.elem drive.fsType [ "ext2" "ext3" "ext4" "btrfs" "fat" "swap" "luks"])
    partionAndFormatThese;

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
        luks = device: drive: ''
          if [[ "$(${util-linux}/bin/blkid -o value -s TYPE ${drive})" != "crypto_LUKS" ]]; then
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

  __luks_build_full_config = drive:
    let
      defaults = {
        extras = {};
      };

      forwardedConfig = {
        mountPoint = drive.mountPoint;
        drive = "/dev/mapper/${drive.label}";
        partitionType = "none";
      };
    in
    defaults // drive.extras.fs // forwardedConfig;

  formatScript = d: part:
    let
      funcMap = {
        none = device: drive: "";
        swap = device: drive: "mkswap -L '${drive.label}' ${device}";
        ext2 = device: drive: "mkfs.ext2 -L '${drive.label}' ${device}";
        ext3 = device: drive: "mkfs.ext3 -L '${drive.label}' ${device}";
        ext4 = device: drive: "mkfs.ext4 -L '${drive.label}' ${device}";
        btrfs = device: drive: 
          let
            raidDrives = getattr "raidDevices" [] drive.extras;
            ifRaid = noRaid: withRaid:
              if (builtins.length raidDrives) > 0 then
                withRaid
              else
                noRaid;

            dataRaidLevel = getattr "dataRaidLevel" (ifRaid "single" "raid0") drive.extras;
            metaRaidLevel = getattr "metaRaidLevel" (ifRaid "dup" "raid1") drive.extras;

            driveList = [ device ] ++ raidDrives;
            drives = builtins.concatStringsSep " " driveList;
          in 
          "mkfs.btrfs -f -L '${drive.label}' ${device} -m ${metaRaidLevel} -d ${dataRaidLevel} ${drives}";
        fat = device: drive: "mkfs.vfat -F32 -n '${drive.label}' ${device}";
        luks = device: drive:
          let
            password = getattr "password" null drive.extras;
            keyFile = getattr "keyFile" null drive.extras;

            format1 =
              if (password != null) then
                ''
                  (cat /tmp/part-${drive.label}/${password}) | cryptsetup -q luksFormat ${device} --label '${drive.label}' --type luks2
                  ${lib.optionalString (keyFile != null) ''
                    cat /tmp/part-${drive.label}/${password} | cryptsetup -q luksAddKey ${device} /tmp/part-${drive.label}/${keyFile}
                  ''}
                  (cat /tmp/part-${drive.label}/${password}) | cryptsetup -q luksOpen ${device} ${drive.label}
                ''
              else
                ''
                  cryptsetup -q luksFormat ${device} --label '${drive.label}' --type luks2 -d /tmp/part-${drive.label}/${keyFile}
                  cryptsetup -q luksOpen ${device} ${drive.label} -d /tmp/part-${drive.label}/${keyFile}
                '';
          in
          ''
            ${format1}
            ${formatScript "/dev/mapper/${drive.label}" (__luks_build_full_config drive)}
            cryptsetup -q luksClose ${drive.label}
          '';
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
            "${utils.addPartitionIndex drive i} : ${lib.optionalString (part.size != "") "size=${part.size},"}type=${types.${part.partitionType}}"
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
  upload = ssh: scp:
    let
      data = 
        map (drive: builtins.concatStringsSep "\n" (
          lib.mapAttrsToList (name: path: ''
            ${ssh} -- mkdir -p /tmp/part-${drive.label}
            ${scp path "/tmp/part-${drive.label}/${name}"}
          '') drive.temporary-files
        )) partionAndFormatThese;
    in
    builtins.concatStringsSep "\n" data;

  format =
    let
      byDrive = builtins.groupBy (drive: drive.drive) partionAndFormatThese;
      formatters = lib.mapAttrsToList (drive: partitions:
        let 
          sfdiskScript = writeText "sfdisk-script" (partitioner.${tableType} drive partitions);

          firstPart = builtins.head partitions;

          table = (builtins.length partitions > 1) || firstPart.size != null;
          format = lib.lists.imap1 (i: part: formatScript (
            if table then
              utils.addPartitionIndex drive i
            else
              drive
          ) part) partitions;

          checkScript =
            if firstPart.reformat then
              "return 0"
            else
              requiresReformatCheckScript drive firstPart;
        in 
        if table then
          {
            partitions = 
              lib.optionalString (drive != "none") ''
                blkdeactivate -u -d force,retry -l wholevg ${drive}
                wipefs -fa ${drive}
                cat ${sfdiskScript} | sfdisk ${drive}
              '';
            formatters = "${builtins.concatStringsSep "\n" format}";
          }
        else
          {
            partitions = "";
            formatters = ''
              if (__chk() { ${checkScript} }; __chk); then
                ${lib.optionalString (drive != "none") "wipefs -fa ${drive}"}
                ${formatScript drive firstPart}
              fi
            '';
          }
      ) byDrive;

      blkdeactivate =
        runCommand "blkdeactivate" {} ''
          mkdir -p $out/bin
          cat ${lvm2.bin}/bin/blkdeactivate | ${gnused}/bin/sed s#/run/current-system/sw/bin/##g > blkdeactivate.raw
          cat blkdeactivate.raw | ${gnused}/bin/sed '/^TOOL=.*/i PATH=''$PATH:${lib.makeBinPath [multipath-tools mdadm gnugrep]}' > $out/bin/blkdeactivate
          chmod +x $out/bin/blkdeactivate
        '';
        
    in
    writeShellScript "format" ''
      BLKDEACTIVATE="$(which blkdeactivate 2>/dev/null)"
      if [[ -z "$BLKDEACTIVATE" ]]; then
        BLKDEACTIVATE=${blkdeactivate}/bin/blkdeactivate
      fi
      TMPBIN=$(mktemp -d)
      ln -s $BLKDEACTIVATE $TMPBIN/blkdeactivate
      set -xueo pipefail
      export PATH=$TMPBIN:${lib.makeBinPath [coreutils util-linux e2fsprogs btrfs-progs cryptsetup dosfstools blkdeactivate gnused gnugrep]}

      umount --recursive /mnt || true
      ${builtins.concatStringsSep "\n" (map (f: f.partitions) formatters)}
      ${builtins.concatStringsSep "\n" (map (f: f.formatters) formatters)}
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
      '') mountThese)}

      echo Mounting...
      ${builtins.concatStringsSep "\n" mounters}
    '';
}
