#!/usr/bin/env bash
IP=$1
(
  ARGS=""
  if [[ ! -z "$2" ]]; then
      ARGS="$ARGS -i $2"
  fi

  fssh() {
      ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $ARGS root@$IP -- "$@"
      return $?
  }

  while ! fssh true; do
      echo "Waiting for the host to show up."
      sleep 1
  done

  fssh mkdir -p /tmp/volumes
  for raw in $VOLUMES; do
      volume=$(cut -d= -f1 <<< "$raw")
      id=$(cut -d= -f2 <<< "$raw")

      while ! fssh test -e /dev/disk/by-id/scsi-0HC_Volume_$id; do
          echo "Waiting for the volume $volume (id: $id) to show up..."
          sleep 1
      done
      fssh ln -s /dev/disk/by-id/scsi-0HC_Volume_$id /tmp/volumes/$volume
  done
)

