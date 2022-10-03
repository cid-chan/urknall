#!/usr/bin/env bash
(
  ARGS=""
  if [[ ! -z "$2" ]]; then
      ARGS="$ARGS -i $2"
  fi

  while ! ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $ARGS root@$1 -- test -e /run/booted-system; do
    sleep 1
  done
) # 2>&1 | awk 'f!=$0&&f=$0' 1>&2
