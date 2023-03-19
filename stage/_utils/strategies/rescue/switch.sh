#!/usr/bin/env bash

# Prepare for chroot action!
mkdir /mnt/{dev,proc,sys}
mount -o bind /dev /mnt/dev
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys
if [ -e /sys/firmware/efi/efivars ]; then
    mount -o bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
fi

# Add a /tmp on tmpfs if required.
if [[ ! -d /mnt/tmp ]]; then
  mkdir /mnt/tmp
  mount -t tmpfs -o size=512M none /mnt/tmp
fi

# Mark the system as a NixOS System
mkdir /mnt/etc/
touch /mnt/etc/NIXOS

# Install the system profile with a temporary nix-env in tmp.
chroot /mnt $1/sw/bin/nix-env -p /nix/var/nix/profiles/system --set $1
#
# Activate and boot (with bootloader install)
chroot /mnt /nix/var/nix/profiles/system/activate
chroot /mnt /run/current-system/bin/switch-to-configuration boot

