The Rescue Provisioning Strategy
================================
Installs NixOS from a ssh-accessible non-nix-based rescue system.

Steps:
1. Install nix on the rescue system (`rescue.sh`)
2. Copy format and mount script and run them.
4. Transfer the closure to the target store.
5. Install the profile and install the boot-loader. (`switch.sh`)

The steps 3 and 4 are done,
so building is done locally (or through distributed builds),
and then just copied to the snapshot machine.

This reduces required memory and minimizes the required resources to create the snapshot.

