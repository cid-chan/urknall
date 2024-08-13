{ writeShellScriptBin, openssh, lib, withExec ? true, nixSsh ? true, debug ? false }:
rec {
  fakeSSH = writeShellScriptBin "ssh" ''
    mkdir -p $URKNALL_ROOT_DIR/controlmasters
    ${lib.optionalString withExec "exec"} ${lib.optionalString nixSsh "${openssh}/bin/"}ssh \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      -oControlPath=$URKNALL_ROOT_DIR/controlmasters/%r@%h:%p -oControlMaster=auto -oControlPersist=yes \
      ${lib.optionalString debug "-vvvv"} \
      ''${SSH_KEY:+-i "$SSH_KEY"} \
      "$@"
  '';

  fakeSCP = writeShellScriptBin "scp" ''
    mkdir -p $URKNALL_ROOT_DIR/controlmasters
    ${lib.optionalString withExec "exec"} ${lib.optionalString nixSsh "${openssh}/bin/"}scp \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      -oControlPath=$URKNALL_ROOT_DIR/controlmasters/%r@%h:%p -oControlMaster=auto -oControlPersist=yes \
      ${lib.optionalString debug "-vvvv"} \
      ''${SSH_KEY:+-i "$SSH_KEY"} \
      "$@"
  '';

  path = lib.makeBinPath [ fakeSSH fakeSCP ];
}
