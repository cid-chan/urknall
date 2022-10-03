#!/usr/bin/env bash
echo '=====> Ensuring installing required packages is installed <===='

install() {
  if command -v apt; then
    apt install "$1" --yes
  fi

  if command -v yum; then
    yum install "$1" -y
  fi

  if command -v apk; then
    apk add "$1"
  fi

  if command -v pacman; then
    pacman -Syy "$1"
  fi
}

if ! command -v sudo; then
  install sudo
fi

if ! command -v curl; then
  if command -v wget; then
    curl() {
      eval "wget $(
        (local isStdout=1
        for arg in "$@"; do
          case "$arg" in
            "-o")
              echo "-O";
              isStdout=0
              ;;
            "-O")
              isStdout=0
              ;;
            "-L")
              ;;
            *)
              echo "$arg"
              ;;
          esac
        done;
        [[ $isStdout -eq 1 ]] && echo "-O-"
        )| tr '\n' ' '
      )"
    }
  else
    install curl
  fi
fi

echo '=====> Preparing nix <====='
mkdir -p /etc/nix
echo "build-users-group =" > /etc/nix/nix.conf

echo '=====> Installing nix <====='
curl -L https://nixos.org/nix/install | sh
. $HOME/.nix-profile/etc/profile.d/nix.sh
ln -sf $(realpath $(which nix-store)) /bin/nix-store
ln -sf $(realpath $(which nix-env)) /bin/nix-env

echo '=====> Ready <====='
