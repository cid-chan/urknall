{ writeShellScriptBin, openssh, lib, withExec ? true, nixSsh ? true, debug ? false }:
rec {
  fakeSSH = writeShellScriptBin "ssh" ''
    ${lib.optionalString withExec "exec"} ${lib.optionalString nixSsh "${openssh}/bin/"}ssh \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      ${lib.optionalString debug "-vvvv"} \
      ''${SSH_KEY:+-i "$SSH_KEY"} \
      "$@"
  '';

  fakeSCP = writeShellScriptBin "scp" ''
    ${lib.optionalString withExec "exec"} ${lib.optionalString nixSsh "${openssh}/bin/"}scp \
      -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no \
      ${lib.optionalString debug "-vvvv"} \
      ''${SSH_KEY:+-i "$SSH_KEY"} \
      "$@"
  '';

  path = lib.makeBinPath [ fakeSSH fakeSCP ];
}
