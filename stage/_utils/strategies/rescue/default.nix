{ module, tableType
, preActivate ? "", rebootAfterInstall ? false
, writeShellScript, writeShellScriptBin
, openssh
, callPackage, lib
}:
let
  partition = callPackage ./../_partitioner {
    inherit lib;
    inherit tableType;
    driveSet = module.drives;
  };

  system = module.config.config.system.build.toplevel;
in
writeShellScript "provision" ''
  IPADDR="$1"
  ESC_IPADDR="$IPADDR"
  if [[ "$IPADDR" == *:* ]]; then
    ESC_IPADDR="[$IPADDR]"
  fi

  export SSH_KEY="$(realpath "$2")"
  export PATH=${(callPackage ./../../ssh.nix {}).path}:$PATH

  runScript() {
    local name=$1
    local localname=$2
    shift
    shift

    scp $name root@$ESC_IPADDR:/root/$localname
    ssh root@$IPADDR -- chmod +x /root/$localname
    ssh root@$IPADDR -- /root/$localname "$@"
  }

  # Wait for the rescue system to come online.
  while ! ssh root@$IPADDR -- true; do
    sleep 1
  done

  # Install Nix
  runScript ${./rescue.sh} rescue.sh

  # Build the important scripts
  nix-copy-closure --to root@$IPADDR ${partition.mount} -s
  nix-copy-closure --to root@$IPADDR ${partition.format} -s

  # Transfer the helper file
  ${partition.upload "ssh root@$IPADDR" (src: dst: "scp \"${src}\" \"root@$IPADDR:${dst}\"")}
  ssh root@$IPADDR -- ${partition.format} >/dev/null
  ssh root@$IPADDR -- ${partition.mount} >/dev/null

  # Install the target closure.
  ${
    if module.direct then ''
      nix-store --export $(nix-store -qR ${system}) | ssh root@$IPADDR -- nix-store --store /mnt --import
    '' else ''
      mkdir -p /mnt/nix/store
      nix-copy-closure --to root@$IPADDR ${system} -s
      ssh root@$IPADDR -- nix-copy-closure --to /mnt/nix/store ${system}
    ''
  }

  # Pre-Activate-Script
  (
    ${preActivate}
  ) || exit 1

  # Prepare the nix store for direct push
  runScript ${./switch.sh} switch.sh ${system}

  ${lib.optionalString rebootAfterInstall ''
    ssh root@$IPADDR -- reboot
  ''}

  # We have liftoff!
  echo '=== === DONE === ==='
''

