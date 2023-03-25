{ lib, config, localPkgs, ...
}:
{
  options = let inherit (lib) mkOption; inherit (lib.types) listOf str; in {
    state.encryption.gpg.recipients = mkOption {
      type = listOf str;
      description = "The public key to encrypt the files with.";
    };
  };

  config = lib.mkIf (config.state.encryption.type == "gpg") {
    state.encryption.encryptionCommand = ''
      ${localPkgs.gnupg}/bin/gpg -q --armor --encrypt ${builtins.concatStringsSep " " (map (name: "--recipient ${name}") config.state.encryption.gpg.recipients)} --output "$2" "$1"
    '';

    state.encryption.decryptionCommand = ''
      ${localPkgs.gnupg}/bin/gpg -q -d "$1" > $2
    '';
  };
}
