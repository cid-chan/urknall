#!/usr/bin/env bash

# Help messages
if [[ -z "$1" ]]; then
  echo "$0 (apply|destroy|shell) [OPTIONS...]"
  echo "run '$0 --help' for more information"
  exit 1
fi

if [[ "$1" == "--help" ]]; then
  echo "$(basename $0) manages declaratively defined infrastructures."
  echo ""
  echo "$(basename $0) apply [NIX_FILE|FLAKE] [OPTIONS...]"
  echo "  Creates or updates the infrastructure"
  echo ""
  echo "$(basename $0) destroy [NIX_FILE|FLAKE] [OPTIONS...]"
  echo "  Destroys the infrastructure"
  echo ""
  echo "$(basename $0) shell [NIX_FILE|FLAKE] [STAGE] [OPTIONS...]"
  echo "  Enters a shell for the given stage."
  exit 0
fi

# Some book-keeping
OPERATION=$1
TARGET="$2"
shift
shift

RUNNER_ARGS=()
if [[ "$OPERATION" == "shell" ]]; then
    RUNNER_ARGS+=( "$1" )
    shift
fi

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

  export CURRENT_SYSTEM=$(nix-instantiate --eval --json -E "builtins.currentSystem")
  export URKNALL_FLAKE_PATH=$(echo "$TARGET" | cut -d'#' -f1)
  export URKNALL_FLAKE_ATTR=$(echo "$TARGET" | cut -d'#' -f2)

  RUNNER=$(nix-build --no-out-link @flakes_nix@ --argstr path "$URKNALL_FLAKE_PATH" --argstr attr "$URKNALL_FLAKE_ATTR" -A runner "$@")
fi

# Prepare the urknall environment
export URKNALL_ROOT_DIR=$(mktemp -d)
export URKNALL_LOCAL_DIRECTORY="$PWD"

# Fix a bug about nix-copy-closure failing when the wrong shell is set.
export SHELL=/bin/sh

# Run the actual script
$RUNNER $OPERATION $RUNNER_ARGS "$@"

# Preserve Exit-Code and clean up.
EXITCODE=$?
rm -rf $URKNALL_ROOT_DIR
exit $EXITCODE
