#!/usr/bin/env bash

if [[ "$1" == "--help" ]]; then
    echo "$0 (run|destroy) [FLAKE]"
    echo "$(basename $0) manages declaratively defined infrastructures."
    echo ""
    echo "   run      - Creates updates the infrastructure"
    echo "   destroy  - Destroys the infrastructure"
    exit 0
fi
OPERATION="$1"

if [[ "$2" == "--help" ]]; then
    case "$1" in
        run)
            echo "$0 $OPERATION [FLAKE]"
            echo "$(basename $0) creates the given infrastructure when using this command"
            exit 0
            ;;

        destroy)
            echo "$0 $OPERATION [FLAKE]"
            echo "$(basename $0) destroys the given infrastructure when using this command"
            exit 0
            ;;
    esac
fi

FLAKE_PATH=$(realpath "$2")
shift
shift

export URKNALL_FLAKE_PATH="$FLAKE_PATH"
export URKNALL_LOCAL_DIRECTORY="$PWD"
export NIX_ARGS="$@"
nix-instantiate --eval @urknall@ --json --arg flake_path "\"$FLAKE_PATH\"" --arg root_flake '"@root_path@"' -A "scripts.$OPERATION" "$@" | jq -r | bash
