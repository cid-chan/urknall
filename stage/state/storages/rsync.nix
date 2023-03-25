{ config, lib, localPkgs
, ... }:
{
  config = lib.mkIf (config.state.storage.type == "rsync") {
    state.storage.pullCommand = ''
      if [[ -d "${config.state.storage.target}" ]]; then
        ${localPkgs.rsync}/bin/rsync -a --del "${config.state.storage.target}" "$STATE_CURRENT_DIR/"
      fi
    '';

    state.storage.pushCommand = ''
      mkdir -p "${config.state.storage.target}"
      ${localPkgs.rsync}/bin/rsync -aH --del "$STATE_NEXT_DIR/" "${config.state.storage.target}"
    '';
  };
}
