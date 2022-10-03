#!/usr/bin/env bash

# "nix copy" and "nix-copy-closure" don't support directly
# pushing to a different nix-store on the target system.
#
# So we do a trick:
# - We copy the entire nix-store as currently installed on the target system
# - Dump and load the database
# - And then mount /mnt/nix as a bind mount to /nix

mkdir -p /mnt/nix/store
cp -a /nix/store/* /mnt/nix/store

nix-store --dump-db > /root/db

# remounting operation kills the profiles defined in nixos.
# Lets manually link the path to /bin/nix-store
ln -sf $(realpath $(which nix-store)) /bin/nix-store
mount --bind /mnt/nix /nix

# Load the database
/bin/nix-store --load-db < /root/db
