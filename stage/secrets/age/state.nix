{ lib, config, ...
}:
let
  cfg = config.secrets.age;
in
{
  options = let inherit (lib) mkOption; inherit (lib.types) str; in {
    state.encryption.age.publicKey = mkOption {
      type = str;
      description = "The public key to encrypt the files with.";
    };

    state.encryption.age.privateKeyFile = mkOption {
      type = str;
      description = "The path to the private key to decrypt the files with.";
    };
  };

  config = lib.mkIf (config.state.encryption.type == "age") {
    state.encryption.encryptionCommand = ''
      ${cfg.ageCommand} -e -r "${config.state.encryption.age.publicKey}" --armor -o "$2" "$1"
    '';

    state.encryption.decryptionCommand = ''
      ${cfg.ageCommand} -d -i "${config.state.encryption.age.privateKeyFile}" -o "$2" "$1"
    '';
  };
}
