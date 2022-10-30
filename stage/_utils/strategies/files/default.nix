{ module
, targetRewriter ? (path: path), pathRewriter ? (path: path)
, writeShellScript, callPackage
, lib
}:
# Places provisioning files on the remote server.
# These can be used for secret provisioning and server customization
writeShellScript "place-files" ''
  IPADDR="$1"
  ESC_IPADDR="$IPADDR"
  if [[ "$IPADDR" == *:* ]]; then
    ESC_IPADDR="[$IPADDR]"
  fi

  export SSH_KEY="$(realpath "$2")"
  export PATH=${(callPackage ./../../ssh.nix {}).path}:$PATH

  # Wait for the rescue system to come online.
  while ! ssh root@$IPADDR -- true; do
    sleep 1
  done

  ${builtins.concatStringsSep "\n" (map (f:
    let
      src = pathRewriter f.file;
      dst = targetRewriter f.path;
    in
    if f.file == null then
      ''
        if ssh root@$IPADDR -- test -e ${dst}; then
          ssh root@$IPADDR -- rm -f ${dst}
        fi
      ''
    else
      ''
        ssh root@$IPADDR -- mkdir -p $(dirname ${dst})
        scp ${src} root@$ESC_IPADDR:${dst}
        ssh root@$IPADDR -- chown ${f.user}:${f.group} ${dst}
        ssh root@$IPADDR -- chmod ${f.mode} ${dst}
      ''
  ) (builtins.attrValues module))}
''
