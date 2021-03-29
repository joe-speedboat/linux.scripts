#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
DISK=vda
if [ $(lsblk | grep ^vda | awk '{print $4}' ) != $(df -hP / | grep /dev/$DISK | awk '{print $2}') ]
then
  echo -e 'd\nw\n' | fdisk /dev/$DISK
  echo -e 'n\np\n\n\n\n\nw\n' | fdisk /dev/$DISK
  partprobe /dev/$DISK
  xfs_growfs /
fi
