{ module, tableType, writeShellScript, writeShellScriptBin, openssh, callPackage, lib }:
let
  partition = callPackage ./../_partitioner {
    inherit lib;
    inherit tableType;
    driveSet = module.drives;
  };

  fakeSSH = writeShellScriptBin "ssh" ''
    exec ${openssh}/bin/ssh \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      -i "$SSH_KEY" \
      "$@"
  '';

  fakeSCP = writeShellScriptBin "scp" ''
    exec ${openssh}/bin/scp \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      -i "$SSH_KEY" \
      "$@"
  '';

  system = module.nixosSystem.config.system.build.toplevel;
in
writeShellScript "provision" ''
  IPADDR="$1"
  export SSH_KEY="$(realpath "$2")"
  export PATH=${fakeSSH}/bin:${fakeSCP}/bin:$PATH

  runScript() {
    local name=$1
    local localname=$2
    shift
    shift

    scp $name root@$IPADDR:/root/$localname
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
  ssh root@$IPADDR -- ${partition.format}
  ssh root@$IPADDR -- ${partition.mount}

  # Prepare the nix store for direct push
  runScript ${./move-nix-store.sh} move-nix-store.sh

  # Install the target closure.
  nix-copy-closure --to root@$IPADDR ${system} -s

  # Disable the hack we just did to copy the installed system
  ssh root@$IPADDR -- umount /nix

  # Prepare the nix store for direct push
  runScript ${./switch.sh} switch.sh ${system}

  # We have liftoff!
  echo '=== === DONE === ==='
''

