#!/bin/bash

# AUTHOR: Tommy Butler
# MODIFIED BY: ChatGPT
#
# DESCRIPTION:
# Run this script to offline and delete a disk from your Linux system.
# Enhanced to show disk/partition mounts before removal.
#
# LICENSE: Perl Artistic License - http://dev.perl.org/licenses/artistic.html
#
# DISCLAIMER AND LIMITATION OF WARRANTY:
# This software is distributed in the hope that it will be useful, but without 
# any warranty; without even the implied warranty of merchantability or fitness 
# for a particular purpose.  USE AT YOUR OWN RISK.  I ASSUME NO LIABILITY.

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

DISK=$1

if [[ `id -u` -ne 0 ]]; then
   exec sudo bash "$0"
fi

while true; do
   [[ "$DISK" != "" ]] && break
   read -p 'Enter the name of the disk you want to offline and delete: ' DISK
done

if [[ "$( expr substr $DISK 1 4 )" == '/dev' ]]; then
   DISK=$( expr substr $DISK 6 10 )
fi

if [[ ! -e /sys/block/$DISK ]]; then
   echo "Error: Disk /dev/$DISK not found in /sys/block/ - Cannot continue"
   exit 1
fi

# 显示磁盘和分区挂载信息
echo "┌─────────────────────────────────────────────────────┐"
echo "│ Disk Information for /dev/$DISK                     │"
echo "├─────────────────────────────────────────────────────┤"

# 检查磁盘本身是否挂载
disk_mount=$(findmnt -n -o TARGET "/dev/$DISK" 2>/dev/null)
if [[ -n "$disk_mount" ]]; then
    echo "│ Disk:      /dev/$DISK"
    echo "│ Mounted at: $disk_mount"
else
    echo "│ Disk:      /dev/$DISK (not mounted)"
fi

# 检查分区挂载情况
shopt -s nullglob
mounted_partitions=()
for part in /dev/${DISK}[0-9]*; do
    part_name=$(basename "$part")
    mount_point=$(findmnt -n -o TARGET "$part" 2>/dev/null)
    if [[ -n "$mount_point" ]]; then
        mounted_partitions+=("$part_name: $mount_point")
    else
        mounted_partitions+=("$part_name: (not mounted)")
    fi
done
shopt -u nullglob

if [[ ${#mounted_partitions[@]} -gt 0 ]]; then
    echo "├─────────────────────────────────────────────────────┤"
    echo "│ Partitions:                                         │"
    for p in "${mounted_partitions[@]}"; do
        printf "│ %-51s │\n" "$p"
    done
else
    echo "├─────────────────────────────────────────────────────┤"
    echo "│ No partitions found                                │"
fi
echo "└─────────────────────────────────────────────────────┘"

# 挂载警告
if [[ -n "$disk_mount" ]] || [[ ${#mounted_partitions[@]} -gt 0 ]]; then
    echo -e "\033[1;31mWARNING:\033[0m"
    echo -e "• The disk or its partitions are currently mounted"
    echo -e "• Data corruption may occur if mounted paths are in use"
    echo -e "• Strongly recommend to unmount all related paths first\n"
fi

echo -e "\033[1;33mAre you ABSOLUTELY sure you want to continue?\033[0m"
select yn in "Yes-Continue" "No-Abort"; do
   case $yn in
      Yes-Continue ) 
          echo -e "\nInitiating removal process..."
          break
          ;;
      No-Abort ) 
          echo "Operation cancelled by user"
          exit 0
          ;;
   esac
done

echo offline > /sys/block/$DISK/device/state
echo 1 > /sys/block/$DISK/device/delete

echo -e "\n\033[1;32mSUCCESS:\033[0m /dev/$DISK has been offlined and deleted"
echo "Note: This change may require a system reboot to take full effect"

exit 0
