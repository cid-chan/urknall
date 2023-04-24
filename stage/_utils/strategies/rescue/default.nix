{ module, tableType
, preActivate ? "", rebootAfterInstall ? false
, writeShellScript, writeShellScriptBin
, openssh, nix
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
  export PATH=${(callPackage ./../../ssh.nix { debug = true; }).path}:$PATH
  export SHELL=/bin/sh

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

  ${lib.optionalString (module.kexec.enable) ''
    if ! ssh root@$IPADDR -- test -e /run/current-system/sw/is_kexec ; then
      # Push the kexec-bundle to the remote system.
      echo Uploading kexec_bundle from ${module.kexec.config.config.system.build.kexec_bundle_2}

      if ! ssh root@$IPADDR -- test -e /root/kexec ; then
        scp ${module.kexec.config.config.system.build.kexec_bundle_2} root@$ESC_IPADDR:/root/kexec
      fi
      ssh root@$IPADDR -- /root/kexec &

      sleep 10

      # Wait for the kexec'd rescue system to come online.
      while ! ssh root@$IPADDR -- test -e /run/current-system/sw/is_kexec; do
        echo "Not kexec."
        ssh root@$IPADDR -- ls /run/current-system/sw || true
        sleep 1
      done

      kill %1
    fi
  ''}

  function copyClosureSafe() {
    nix-copy-closure --to root@$IPADDR $1 -s || (nix-store --export $(nix-store -qR $1) | ssh root@$IPADDR -- nix-store --import) || exit 1
  }

  # Install Nix
  runScript ${./rescue.sh} rescue.sh

  # Build the important scripts
  copyClosureSafe ${nix}
  copyClosureSafe ${partition.mount}
  copyClosureSafe ${partition.format}

  # Transfer the helper file
  ${partition.upload "ssh root@$IPADDR" (src: dst: "scp \"${src}\" \"root@$IPADDR:${dst}\"")}
  ssh root@$IPADDR -- ${partition.format} >/dev/null
  ssh root@$IPADDR -- ${partition.mount} >/dev/null

  # Install the target closure.
  ${
    if module.direct then ''
      nix-store --export $(nix-store -qR ${system}) | ssh root@$IPADDR -- ${nix}/bin/nix-store --store /mnt --import
    '' else ''
      copyClosureSafe ${system}
      ssh root@$IPADDR -- ${nix}/bin/nix --experimental-features nix-command copy --to /mnt ${system} --no-check-sigs
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

