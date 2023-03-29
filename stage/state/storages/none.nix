{
  config = lib.mkIf (config.state.storage.type == "none") {
    state.storage.pullCommand = "";
    state.storage.pushCommand = "";
  };
}
