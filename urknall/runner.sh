#!/usr/bin/env bash

# Help messages
if [[ -z "$1" ]]; then
  echo "$0 (apply|destroy) [OPTIONS...]"
  echo "run '$0 --help' for more information"
  exit 1
fi

if [[ "$1" == "--help" ]]; then
  echo "$0 (run|destroy) [NIX_FILE|FLAKE] [OPTIONS...]"
  echo "$(basename $0) manages declaratively defined infrastructures."
  echo ""
  echo "   run      - Creates updates the infrastructure"
  echo "   destroy  - Destroys the infrastructure"
  exit 0
fi

# Some book-keeping
OPERATION=$1
TARGET="$2"
shift

# Load the runner
# Rewrites for legacy.
if [[ -e "$TARGET/urknall.nix" ]]; then
    TARGET="$TARGET/urknall.nix"
elif [[ -e "$TARGET/default.nix" ]]; then
    TARGET="$TARGET/default.nix";
fi

if [[ "$TARGET" == *.nix ]]; then
  export URKNALL_IMPURE_TARGET=$(realpath "$TARGET")
  RUNNER=$(nix-build --no-out-link @urknall_nix@ -A runner)

else
  if [[ "$TARGET" != *#* ]]; then
    TARGET="${TARGET}#urknall.default"
  fi
  shift

  export CURRENT_SYSTEM=$(nix-instantiate --eval --json -E "builtins.currentSystem")
  export URKNALL_FLAKE_PATH=$(echo "$TARGET" | cut -d'#' -f1)
  export URKNALL_FLAKE_ATTR=$(echo "$TARGET" | cut -d'#' -f2)

  RUNNER=$(nix-build --no-out-link @flakes_nix@ --argstr path "$URKNALL_FLAKE_PATH" --argstr attr "$URKNALL_FLAKE_ATTR" -A runner "$@")
fi

# Prepare the urknall environment
export URKNALL_ROOT_DIR=$(mktemp -d)
export URKNALL_LOCAL_DIRECTORY="$PWD"

# Run the actual script
$RUNNER $OPERATION "$@"

# Preserve Exit-Code and clean up.
EXITCODE=$?
rm -rf $URKNALL_ROOT_DIR
exit $EXITCODE
