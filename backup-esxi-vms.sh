#!/bin/ash
#! /bin/bash
# DESC: Backup all VMs and DS folders in single ESXi host, simple backup for LAB infrastructure
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

SDIR=/vmfs/volumes/SSD
BDIR=/vmfs/volumes/SATA/vRA7/$(date '+%Y%m%d')

# ----- functions ------
tincopy (){
   FROM="$1"
   TO="$2"
   mkdir -p "$TO"
   echo "INFO: tincopy $FROM/ $TO/$F"
   find "$FROM" -type f -not -iname '*.vmdk' -exec cp -a "{}" "$TO/" \;
   find "$FROM" -type f -iname '*.vmdk' | while read vmdk
   do
      F="`basename $vmdk`"
      vmkfstools -i "$vmdk" -d thin "$TO/$F"
   done
   echo "INFO: tincopy done ----------"
   ls -als "$TO/$F"
   du -hcs "$FROM" "$TO/$F"
}

startupVmName (){
 vmName=$1
 echo "`vim-cmd vmsvc/getallvms | grep " $vmName " | cut -d\  -f1 | xargs vim-cmd vmsvc/power.on` $vmName"
}

removeAllSnapshots(){
  vim-cmd vmsvc/getallvms | grep -v Vmid | awk '{print $1":"$2}' | while read VM
  do
    VMID=$(echo $VM | cut -d: -f1)
    vmName=$(echo $VM | cut -d: -f2)
    echo "INFO: `date '+%Y.%m.%d_%H:%M'`: search Snapshots of VM: $vmName ---"
    vim-cmd vmsvc/get.snapshot $VMID | grep -A5 'snapshot = ' | sed '/id =/!d;s/.*id = //g;s/,//g' | while read SNAPID
    do
      echo exec: vim-cmd vmsvc/snapshot.remove $VMID $SNAPID
      vim-cmd vmsvc/snapshot.remove $VMID $SNAPID
    done
  done
}

shutdownWaitvmName (){
 vmName=$1
 vmId=`vim-cmd vmsvc/getallvms | grep " $vmName " | cut -d\  -f1`
 echo "INFO: `date '+%Y.%m.%d_%H:%M'`: shutdown and wait: $vmName"
 vim-cmd vmsvc/power.shutdown $vmId
 for i in `seq 300`
 do
   if (vim-cmd vmsvc/power.getstate $vmId | grep -q ' off')
   then
     echo
     break
   fi
   sleep 1
   echo -n .
 done
 if (vim-cmd vmsvc/power.getstate $vmId | grep -q ' on')
 then
   echo "WARNING: `date '+%Y.%m.%d_%H:%M'`: VM $vmName is still on, do poweroff now"
   vim-cmd vmsvc/power.off $vmId
 fi
}


# --- shutdown all vms ---
shutdownWaitvmName iaas1
shutdownWaitvmName vra1
shutdownWaitvmName vcenter1
shutdownWaitvmName esx2
shutdownWaitvmName esx1
shutdownWaitvmName ad1
shutdownWaitvmName gateway1

# --- create backups ---
removeAllSnapshots

cd "$SDIR"
mkdir -p "$BDIR"
ls -1d * | while read d
do
   echo "---------- $d ----------"
   echo "exec: tincopy $d $BDIR/$d"
   tincopy "$d" "$BDIR/$d"
done
du -hc $BDIR

#--- start vms after backup ---
startupVmName gateway1
startupVmName ad1
startupVmName esx1
startupVmName esx2
sleep 300
startupVmName vcenter1
sleep 600
startupVmName vra1
sleep 600
startupVmName iaas1

