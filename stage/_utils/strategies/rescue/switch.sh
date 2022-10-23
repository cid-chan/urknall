#!/usr/bin/env bash

# Prepare for chroot action!
mkdir /mnt/{dev,proc,sys}
mount -o bind /dev /mnt/dev
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys

# Add a /tmp on tmpfs if required.
if [[ ! -d /mnt/tmp ]]; then
  mkdir /mnt/tmp
  mount -t tmpfs -o size=512M none /mnt/tmp
fi

# Mark the system as a NixOS System
mkdir /mnt/etc/
touch /mnt/etc/NIXOS

# Install the system profile with a temporary nix-env in tmp.
ln -sf $(realpath $(which nix-env)) /mnt/tmp/nix-env
chroot /mnt /tmp/nix-env -p /nix/var/nix/profiles/system --set $1
rm /mnt/tmp/nix-env

# Activate and boot (with bootloader install)
chroot /mnt /nix/var/nix/profiles/system/activate
chroot /mnt /run/current-system/bin/switch-to-configuration boot
