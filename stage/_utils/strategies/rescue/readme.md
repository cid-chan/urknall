The Rescue Provisioning Strategy
================================
Installs NixOS from a ssh-accessible non-nix-based rescue system.

Steps:
1. Install nix on the rescue system (`rescue.sh`)
2. Copy format and mount script and run them.
3. **Move the /nix/store to the target nix store** and bind-mount it to `/nix` (`move-nix-store.sh`)
4. nix-copy-closure to the rescue system (This will land on the target disk)
5. Install the profile and install the boot-loader. (`switch.sh`)

The steps 3 and 4 are done,
so building is done locally (or through distributed builds),
and then just copied to the snapshot machine.

This reduces required memory and minimizes the required resources to create the snapshot.

