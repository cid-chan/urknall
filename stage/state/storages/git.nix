{ config, lib, localPkgs
, ... }:
{
  config = lib.mkIf (config.state.storage.type == "git") {
    state.storage.pullCommand = ''
      ${localPkgs.git}/bin/git clone "${config.state.storage.target}" "$STAGE_DIR/repo"
      ${localPkgs.rsync}/bin/rsync -a --del --exclude ".git" "$STAGE_DIR/repo/" "$STATE_CURRENT_DIR/"
    '';

    state.storage.pushCommand = ''
      mkdir -p "${config.state.storage.target}"
      ${localPkgs.rsync}/bin/rsync -aH --del --exclude ".git" "$STATE_NEXT_DIR/" "$STAGE_DIR/repo"
      pushd "$STAGE_DIR/repo"
      if [[ ! -z "$(${localPkgs.git}/bin/git status --porcelain)" ]]; then
        ${localPkgs.git}/bin/git add .
        ${localPkgs.git}/bin/git commit -am "State update by $USER ($(${localPkgs.coreutils}/bin/id -u))"
        ${localPkgs.git}/bin/git push
      fi
      popd
    '';
  };
}

