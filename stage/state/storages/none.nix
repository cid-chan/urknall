{
  config = lib.mkIf (config.state.storage.type == "none") {
    state.storage.pullCommand = ''
      mkdir -p "${config.state.storage.target}"
    '';
    state.storage.pushCommand = "";
}
