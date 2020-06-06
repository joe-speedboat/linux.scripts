#!/bin/bash
# DESC: backup and restore KVM VMs with qcow2 and virsh

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#---------- GLOBAL VARS --------------------------------------------------
export LANG="en_US.UTF-8"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TOP_PID=$$
set -o pipefail

#---------- MY VARS --------------------------------------------------
EXT_CFG=/etc/virsh-qcow-backup.cfg
BACKUP_DIR=/srv/backup/dev
DEBUG=0
DOWARN=1
MAIL_ERR=1
TO=root

#---------- INTERNAL VARS ----------------------------------------------
BDATE="$(date '+%Y.%m.%d_%H.%M.%S')"
BDATE_PATTERN='[0-9]{4}\.[0-9]{2}\.[0-9]{2}\_[0-9]{2}\.[0-9]{2}\.[0-9]{2}'
SNAPSHOT_ID="qvm-snap"
BACKUP_ID="qvm-bkp"
LOGDIR=$BACKUP_DIR

# set defaults
DOBACKUP=0
DOBACKUPCOMPRESSED=0


#---------- FUNCTIONS --------------------------------------------------
# log handling
log(){ #---------------------------------------------------
   LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   if [ "$LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*"
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" >> $LOGDIR/$(basename $0).log
      logger -t $(basename $0) "$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*"
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" >> $LOGDIR/$(basename $0).log
      logger -t $(basename $0) "$LEVEL: $* VM=$VM"
   fi
   if [ "$LEVEL" = "ERROR" ]
   then
      if [ $DOBACKUP -eq 1 -o $DOBACKUPCOMPRESSED -eq 1 -a "x" != "x$BACKUPDEST" ] ; then
         test -d $BACKUPDEST && mv $BACKUPDEST $BACKUPDEST_FINAL.failed
      fi
      
      [ $MAIL_ERR -eq 1 ] && ( ( echo ; cat $BACKUPDEST_FINAL.failed/$(basename $0).log 2>/dev/null ) | mail -s "ERROR: $(basename $0) VM=$VM" $TO )
      kill $TOP_PID
      kill -9 $TOP_PID
   fi
}

#---------- SOURCE EXTERNAL CONFIGURATION-------------------------------
test -r $EXT_CFG
if [ $? -eq 0 ]
then
   log info found external config file, sourcing it in: $EXT_CFG
   source $EXT_CFG
fi

# prevent from starting twice
createlock(){ #--------------------------------------------
   LCK_FILE=$1
   test -d $(dirname $LCK_FILE) || mkdir -p $(dirname $LCK_FILE)
   test -f $LCK_FILE
   if [ $? -eq 0 ] # if lockfile is present, look closer
   then
      log debug $LCK_FILE does exist
      ps $(cat $LCK_FILE) >/dev/null 2>&1
      if [ $? -ne 0 ]
      then
         log debug lockfile has invalid PID PID=$(cat $LCK_FILE), so I remove it and start over
         rm -f $LCK_FILE
      else
         log error script is already running at PID=$(cat $LCK_FILE), so I quit
      fi
   fi
   echo  $TOP_PID > $LCK_FILE
   log debug created lockfile $LCK_FILE with PID=$TOP_PID
}

# give help
dohelp(){ #------------------------------------------------
   echo "
   Usage: $(basename $0)
           -b <VM>          Backup VM without compression
           -bc <VM>         Backup VM with compression
           -br <DIR>         Restore VM (only full vm restore)
           -be <DISK1,DISK2> Exclude this disks while backup
           -bg <NR>          Keep only NR of most recent backup
           -bp <DIR>         Use this backup dir, eg:$BACKUP_DIR
           -bf               Cleanup failed backups
           -sc <VM> <ID>     Create VM snapshot (int snap)
           -sl               List all VM snapshots
           -sd <VM> <ID>     Delete VM snapshots
           -sr <VM> <ID>     Rollback VM to this snapshot (offline merge)
           -d  <VM>          Delete VM and all its disks
           -l  [VM]          List VM information of one or all VMs
           -h|--help         Show this help

           eg: $(basename $0) -bg 5 -bcc nfs -be nfs_srv.qcow2
   "
exit 0
}

# send warning for dangerous tasks if wanted
dowarn(){ #------------------------------------------------
   if [ $DOWARN -eq 1 ]
   then
      echo "   -=WARNING=-"
      echo "   YOU ARE ABOUT TO DELETE SOMETHING"
      echo "   press 3x<ENTER> to continume or <CTRL>-<C> to abort"
      read x ; read x ; read x
   fi
}

# rotate backups and keep last X generations
dorotate(){ #----------------------------------------------
   ROTATE_DIR=$1
   BDATE_PATTERN=$2
   KEEPGEN=$3
   test -d $ROTATE_DIR || log error ROTATE_DIR=$ROTATE_DIR does not exist
   echo $KEEPGEN | egrep -q [0-9] || log error KEEPGEN=$KEEPGEN is not a number  
   log info deleting backups down to $KEEPGEN generations
   [ $KEEPGEN -lt 1 ] && log error KEEPGEN can not be lower than 1
   [ "x$KEEPGEN" = "x" ] && KEEPGEN can not be empty
   cd $ROTATE_DIR || could not change into dir $ROTATE_DIR
   ls -1d * | egrep -x "^$BDATE_PATTERN$" | head -n-$KEEPGEN | while read DEL_BKP
   do
      log info deleting backup $ROTATE_DIR/$DEL_BKP
      rm -rf $ROTATE_DIR/$DEL_BKP || log error could not delete $ROTATE_DIR/$DEL_BKP
   done
}

# restore VM from backup dir
dorestore(){ #---------------------------------------------
   RESTORE_DIR=$1
   LOGDIR=$RESTORE_DIR
   test -d $RESTORE_DIR || log error RESTORE_DIR=$RESTORE_DIR does not exist
   cd $RESTORE_DIR || log error could not change into dir $RESTORE_DIR
   RESTORE_DIR=$PWD
   LOGDIR=$RESTORE_DIR
   VM=$(cat *.xml | sed -e '/<name>/!d;s/<[^>]*>//g;s/[ \t]*//' | tail -n1 )
   log info starting restore of VM=$VM from RESTORE_DIR=$RESTORE_DIR
   test -r $VM.xml || log error could not find $VM.xml
   test -r $VM.disklist || log error could not find $VM.disklist
   virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" && log error VM=$VM does exist, delete VM first
   cat $VM.disklist | sed '/^qcow2\;/!d' | while read DISK
   do
      qsize=$( echo $DISK | cut -d';' -f2 )
      qname=$( echo $DISK | cut -d';' -f3 )
      qpath=$( echo $DISK | cut -d';' -f4 )
      if [ -r $qname.lzo ] ; then
         log info restoring compressed disk $PWD/$qname.lzo to $qpath/$qname
         lzop -dc $qname.lzo > $qpath/$qname || log error could not restore $PWD/$qname.lzo to $qpath/$qname
         log info disk $qpath/$qname restored
      elif [ -r $qname ] ; then
         log info restoring disk $PWD/$qname to $qpath/$qname
         cp $qname $qpath/$qname || log error could not restore $PWD/$qname to $qpath/$qname
         log info disk $qpath/$qname restored
      else
         log warning qcow2 disk backup $PWD/$qname.lzo does not exist, probaly it was excluded in backup, create empty disk instead
         qemu-img create -f qcow2 $qpath/$qname $qsize
         log info qcow2 disk $qpath/$qname with size $qsize created
      fi
   done
   log info restore VM definition
   virsh define $VM.xml >>$LOGDIR/$(basename $0).log 2>&1 || log error could not import VM definition
}

# delete vm and its disks
dodelete(){ #---------------------------------------------
   VM=$1
   virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" || log error VM=$VM does not exist
   dowarn
   log info deleting VM=$VM
   log info force shutdown of VM=$VM to be sure its down
   virsh -q list | awk '{print $2}' | grep -q "^$VM$" && virsh destroy $VM >>$LOGDIR/$(basename $0).log 2>&1
   for DISK in $( virsh domblklist $VM | sed '1,2d;/^$/d;s|.* /|/|g' )
   do
      log info deleting DISK=$DISK
      if qemu-img info -U $DISK | grep -q 'file format: qcow2' ; then
         rm -f $DISK || log error could not delete DISK=$DISK
      else
         log warning DISK=$DISK is no qcow2 Disk, I do not touch this things
      fi
   done
   log info deleting VM definition
   virsh undefine $VM  >/dev/null 2>&1 || log error could not delete VM definition
   log debug refresh all storage pools
   virsh pool-list |sed -r '1,/----/d;/^$/d;s/ .*//g' | while read POOL; do virsh pool-refresh $POOL >/dev/null 2>&1; done
}

# list vm information
listvms(){ #---------------------------------------------
   log debug listing all vm information
   virsh -q list --all | awk '{print $2}' | while read VM
   do
      listvm $VM
   done
}

listvm(){ #---------------------------------------------
   VM=$1
   log debug listing vm information
   VMSTATE="$(virsh dominfo $VM | grep '^State:' | cut -d: -f2 | sed 's/^[ ]*//g')"
   VMAUTO="$(virsh dominfo $VM | grep '^Autostart:' | cut -d: -f2 | sed 's/^[ ]*//g')"
   VMMEMKB="$(virsh dominfo $VM | grep '^Max memory:' | cut -d: -f2 | awk '{print $1}' | sed 's/^[ ]*//g')"
   VMMEMMB="$(( $VMMEMKB / 1024 ))"
   VMCPU="$(virsh dominfo $VM | grep '^CPU(s):' | cut -d: -f2 | sed 's/^[ ]*//g')"
   echo "   ===---------- VM: $VM ----------==="
   echo "           State: $VMSTATE"
   echo "       Autostart: $VMAUTO"
   echo "          Memory: $VMMEMMB MB"
   echo "             CPU: $VMCPU"
   echo "      ---------- Network Interfaces:"
   virsh domiflist $VM | sed -r '/---/d;s/\s+/,/g;/^$/d' | column -s, -t | sed 's/^/      /g'
   echo "      ---------- Block Devices:"
   ( echo "Target,Source,Size"
   virsh domblklist $VM | sed -r '1,/----/d;/^$/d;s/\s+/,/g' | while read VMDISK
   do
      VM_DISK=$(echo $VMDISK |  cut -d, -f1)
      LOCAL_DISK=$(echo $VMDISK |  cut -d, -f2)
      test -f $LOCAL_DISK 
      if [ $? -eq 0 ] ; then
         DISK_SIZE="$(du -mh $LOCAL_DISK | awk '{print $1}')"
         DISK_SIZE="$DISK_SIZE,$(qemu-img info -U $LOCAL_DISK | grep 'virtual size' | cut -d: -f2 | awk '{print $1}')"
      fi
      echo "$VM_DISK,$LOCAL_DISK,$DISK_SIZE"
      DISK_SIZE=
   done ) | column -s, -t | sed 's/^/      /g'
   echo
}

# backup VM with no compression
dobackup(){ #----------------------------------------------
   VM=$1
   BACKUPDEST_FINAL=$2
   DISK_EXCLUDES="$3"
   log debug "-------------------- doing all the exclude stuff --------------------"
   if [ "x" = "x$DISK_EXCLUDES" ] ; then
      log debug no disks excluded, setting dummy pattern: $DISK_EXCLUDES_GREP
      DISK_EXCLUDES_GREP='_backup_all_disks_and_exclude_none_'
   else
      DISK_EXCLUDES_GREP="$(echo $DISK_EXCLUDES | sed 's#,#\$|#g;s#$#\$#g')"
   fi
   log debug DISK_EXCLUDES_GREP=$DISK_EXCLUDES_GREP
   [ "x$VM" = "x" ] && log error var VM is empty
   [ "x$BACKUPDEST_FINAL" = "x" ] && log error var BACKUPDEST_FINAL is empty
   BACKUPDEST=$BACKUPDEST_FINAL.running
   LOGDIR=$BACKUPDEST
   log info starting backup of VM=$VM to BACKUPDEST=$BACKUPDEST
   log debug create backup destination dir $BACKUPDEST
   test -d $BACKUPDEST || mkdir -p $BACKUPDEST
   log debug list all disks which are excluded
   for DISK in $( virsh domblklist $VM | sed '1,2d;/^$/d;s|.* /|/|g' ) ; do
      echo $DISK | egrep -q "$DISK_EXCLUDES_GREP"
      if [ $? -eq 0 ] ; then 
         log warning "DISK=$DISK is excluded for backup by user"
         log debug storing disk name and size, will create empty one on restore
         test -f $BACKUPDEST/$VM.disklist || echo "type;size;name;path" >> $BACKUPDEST/$VM.disklist
         qsize="$(qemu-img info -U $DISK | grep 'virtual size' | cut -d: -f2 | awk '{print $1}')"
         qname="$(basename $DISK)"
         qpath="$(dirname $DISK)"
         echo "qcow2;$qsize;$qname;$qpath" >> $BACKUPDEST/$VM.disklist
      else
         qemu-img info -U $DISK | grep -q 'file format: qcow2'
         if [ $? -ne 0 ] ; then # found disk other than qcow2
            log warning DISK=$DISK is not qcow2, so I add this disk to exclude list
            DISK_EXCLUDES_GREP="$DISK_EXCLUDES_GREP|$DISK\$"
            log debug "DISK_EXCLUDES_GREP=$DISK_EXCLUDES_GREP"
         fi
      fi
   done
   log debug "-------------------- starting backup part --------------------"
   log info backup VM definition
   virsh dumpxml --inactive $VM > $BACKUPDEST/$VM.xml 2>>$LOGDIR/$(basename $0).log || log error backup VM=$VM definition failed
   log info create snapshot
   virsh snapshot-create-as --domain $VM $BACKUP_ID --disk-only --atomic >>$LOGDIR/$(basename $0).log 2>&1 || log error could not create VM=$VM snapshot
   log debug snapshot created
   for DISK in $( virsh domblklist $VM | sed '1,2d;/^$/d;s|.* /|/|g' | egrep -v "$DISK_EXCLUDES_GREP" )
   do
      VM_IDISK=$(virsh domblklist $VM | grep $DISK | awk '{print $1}') # vm internal disk name
      VM_SNAP=$DISK
      VM_DISK=$(qemu-img info -U $VM_SNAP | grep 'backing file:' | awk '{print $3}') # vm main disk file
      echo $VM_DISK | egrep -q "$DISK_EXCLUDES_GREP"
      if [ $? -eq 0 ] ; then # found excluded disk
         log info found exlcuded disk, skip it: $VM_DISK
      else
         test -f $BACKUPDEST/$VM.disklist || echo "type;size;name;path" >> $BACKUPDEST/$VM.disklist
         qsize="$(qemu-img info -U $VM_DISK | grep 'virtual size' | cut -d: -f2 | awk '{print $1}')"
         qname="$(basename $VM_DISK)"
         qpath="$(dirname $VM_DISK)"
         echo "qcow2;$qsize;$qname;$qpath" >> $BACKUPDEST/$VM.disklist
         log info backup external snapshot from qcow2 file $VM_DISK to $BACKUPDEST/$qname
         cp $VM_DISK $BACKUPDEST/$qname || log error could not backup qcow2 image $VM_DISK
      fi
      VMRUN=0 ; virsh -q list | awk '{print $2}' | egrep -q "^$VM$" && VMRUN=1
      if [ $VMRUN -ne 0 ] ; then # vm is running
         log info blockcommit snapshot $VM_SNAP into original disk $VM_DISK
         virsh blockcommit $VM $VM_IDISK --active --pivot --verbose >>$LOGDIR/$(basename $0).log 2>&1 || log error could not blockcommit snapshot $VM_SNAP
      else
         log info VM is not running, no blockcommit needed
      fi
      log info deleting snapshot file $VM_SNAP
      rm -f $VM_SNAP || log error could not delete snapshot file $VM_SNAP
   done
   log info remove snapshot $BACKUP_ID 
   virsh snapshot-delete $VM $BACKUP_ID --metadata >>$LOGDIR/$(basename $0).log 2>&1 || log error could not delete VM=$VM snapshot
   VMRUN=0 ; virsh -q list | awk '{print $2}' | egrep -q "^$VM$" && VMRUN=1
   if [ $VMRUN -eq 0 ] ; then # vm is not running
      # because blockcommit is not possible with offline VMs
      virsh undefine $VM
      virsh define $BACKUPDEST/$VM.xml
   fi
   log info backup finished successfully
   log info move finished backup to final destination: $BACKUPDEST_FINAL
   mv $BACKUPDEST $BACKUPDEST_FINAL || log error could not move backup
   BACKUPDEST=$BACKUPDEST_FINAL # from now, log into this dir
   LOGDIR=$BACKUPDEST
}

# backup VM with compression
dobackupcompressed(){ #----------------------------------------------
   VM=$1
   BACKUPDEST_FINAL=$2
   DISK_EXCLUDES="$3"
   log debug "-------------------- doing all the exclude stuff --------------------"
   if [ "x" = "x$DISK_EXCLUDES" ] ; then
      log debug no disks excluded, setting dummy pattern: $DISK_EXCLUDES_GREP
      DISK_EXCLUDES_GREP='_backup_all_disks_and_exclude_none_'
   else
      DISK_EXCLUDES_GREP="$(echo $DISK_EXCLUDES | sed 's#,#\$|#g;s#$#\$#g')"
   fi
   log debug DISK_EXCLUDES_GREP=$DISK_EXCLUDES_GREP
   [ "x$VM" = "x" ] && log error var VM is empty
   [ "x$BACKUPDEST_FINAL" = "x" ] && log error var BACKUPDEST_FINAL is empty
   BACKUPDEST=$BACKUPDEST_FINAL.running
   LOGDIR=$BACKUPDEST
   log info starting backup of VM=$VM to BACKUPDEST=$BACKUPDEST
   log debug create backup destination dir $BACKUPDEST
   test -d $BACKUPDEST || mkdir -p $BACKUPDEST
   log debug list all disks which are excluded
   for DISK in $( virsh domblklist $VM | sed '1,2d;/^$/d;s|.* /|/|g' ) ; do
      echo $DISK | egrep -q "$DISK_EXCLUDES_GREP"
      if [ $? -eq 0 ] ; then 
         log warning "DISK=$DISK is excluded for backup by user"
         log debug storing disk name and size, will create empty one on restore
         test -f $BACKUPDEST/$VM.disklist || echo "type;size;name;path" >> $BACKUPDEST/$VM.disklist
         qsize="$(qemu-img info -U $DISK | grep 'virtual size' | cut -d: -f2 | awk '{print $1}')"
         qname="$(basename $DISK)"
         qpath="$(dirname $DISK)"
         echo "qcow2;$qsize;$qname;$qpath" >> $BACKUPDEST/$VM.disklist
      else
         qemu-img info -U $DISK | grep -q 'file format: qcow2'
         if [ $? -ne 0 ] ; then # found disk other than qcow2
            log warning DISK=$DISK is not qcow2, so I add this disk to exclude list
            DISK_EXCLUDES_GREP="$DISK_EXCLUDES_GREP|$DISK\$"
            log debug "DISK_EXCLUDES_GREP=$DISK_EXCLUDES_GREP"
         fi
      fi
   done
   log debug "-------------------- starting backup part --------------------"
   log info backup VM definition
   virsh dumpxml --inactive $VM > $BACKUPDEST/$VM.xml 2>>$LOGDIR/$(basename $0).log || log error backup VM=$VM definition failed
   log info create snapshot
   virsh snapshot-create-as --domain $VM $BACKUP_ID --disk-only --atomic >>$LOGDIR/$(basename $0).log 2>&1 || log error could not create VM=$VM snapshot
   log debug snapshot created
   for DISK in $( virsh domblklist $VM | sed '1,2d;/^$/d;s|.* /|/|g' | egrep -v "$DISK_EXCLUDES_GREP" )
   do
      VM_IDISK=$(virsh domblklist $VM | grep $DISK | awk '{print $1}') # vm internal disk name
      VM_SNAP=$DISK
      VM_DISK=$(qemu-img info -U $VM_SNAP | grep 'backing file:' | awk '{print $3}') # vm main disk file
      echo $VM_DISK | egrep -q "$DISK_EXCLUDES_GREP"
      if [ $? -eq 0 ] ; then # found excluded disk
         log info found exlcuded disk, skip it: $VM_DISK
      else
         test -f $BACKUPDEST/$VM.disklist || echo "type;size;name;path" >> $BACKUPDEST/$VM.disklist
         qsize="$(qemu-img info -U $VM_DISK | grep 'virtual size' | cut -d: -f2 | awk '{print $1}')"
         qname="$(basename $VM_DISK)"
         qpath="$(dirname $VM_DISK)"
         echo "qcow2;$qsize;$qname;$qpath" >> $BACKUPDEST/$VM.disklist
         log info compressing external snapshot from qcow2 file $VM_DISK to $BACKUPDEST/$qname.lzo
         lzop $VM_DISK -o $BACKUPDEST/$qname.lzo || log error could not compress qcow2 image $VM_DISK
      fi
      VMRUN=0 ; virsh -q list | awk '{print $2}' | egrep -q "^$VM$" && VMRUN=1
      if [ $VMRUN -ne 0 ] ; then # vm is running
         log info blockcommit snapshot $VM_SNAP into original disk $VM_DISK
         virsh blockcommit $VM $VM_IDISK --active --pivot --verbose >>$LOGDIR/$(basename $0).log 2>&1 || log error could not blockcommit snapshot $VM_SNAP
      else
         log info VM is not running, no blockcommit needed
      fi
      log info deleting snapshot file $VM_SNAP
      rm -f $VM_SNAP || log error could not delete snapshot file $VM_SNAP
   done
   log info remove snapshot $BACKUP_ID 
   virsh snapshot-delete $VM $BACKUP_ID --metadata >>$LOGDIR/$(basename $0).log 2>&1 || log error could not delete VM=$VM snapshot
   VMRUN=0 ; virsh -q list | awk '{print $2}' | egrep -q "^$VM$" && VMRUN=1
   if [ $VMRUN -eq 0 ] ; then # vm is not running
      # because blockcommit is not possible with offline VMs
      virsh undefine $VM
      virsh define $BACKUPDEST/$VM.xml
   fi
   log info backup finished successfully VM=$VM
   log info move finished backup to final destination: $BACKUPDEST_FINAL
   mv $BACKUPDEST $BACKUPDEST_FINAL || log error could not move backup
   BACKUPDEST=$BACKUPDEST_FINAL # from now, log into this dir
   LOGDIR=$BACKUPDEST
}


# cleanup failed backups
docleanupbackup(){ #----------------------------------------------
   BROKEN=0
   ( virsh -q list --all | awk '{print $2}' | while read VM; do virsh -q domblklist $VM | sed "s/^/$VM,/g;s/ \{1,\}/,/g"; done )| egrep "$BACKUP_ID$" >/dev/null && BROKEN=1
   find $BACKUP_DIR -type d -name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9].failed' | egrep -q 'failed$|running$' && BROKEN=1
   if [ $BROKEN -eq 0 ]
   then
      log info "there are no broken backups"
   else
      echo "
         CLEANUP FAILED BACKUPS:
         -----------------------
      - cleanup obsolete snapshot from failed backups
      - remove failed backup dirs for broken backups

      This backups are broken:
      ------------------------"
      virsh -q list --all | awk '{print $2}' | while read VM; do virsh -q domblklist $VM | sed "s/^/$VM /g;s/ \{1,\}/ /g"; done | egrep "$BACKUP_ID$" | column -t | sed 's/^/         /g'
      find $BACKUP_DIR -type d -name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9].failed' | sed 's/^/         /g'
      find $BACKUP_DIR -type d -name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9].running' | sed 's/^/         /g'

      echo "
      Do you want to clean up?
      "
      dowarn
      virsh -q list --all | awk '{print $2}' | while read VM; do virsh -q domblklist $VM | sed "s/^/$VM,/g;s/ \{1,\}/,/g"; done | egrep "$BACKUP_ID$" | while read BDISK
      do
         VM=$(echo $BDISK | cut -d, -f1)
         VM_SNAP=$(echo $BDISK | cut -d, -f3)
         VM_IDISK=$(echo $BDISK | cut -d, -f2)
         VM_DISK=$(qemu-img info -U $VM_SNAP | grep 'backing file:' | awk '{print $3}') # vm main disk file
         VMRUN=0 ; virsh -q list | awk '{print $2}' | egrep -q "^$VM$" && VMRUN=1
         if [ $VMRUN -eq 0 ] ; then # vm is not running
            log info VM is not running, no blockcommit needed
            log info deleting snapshot file $VM_SNAP
            rm -f $VM_SNAP || log error could not delete snapshot file $VM_SNAP
            log info remove snapshot $BACKUP_ID 
            virsh snapshot-delete $VM $BACKUP_ID --metadata >>$LOGDIR/$(basename $0).log 2>&1 || log error could not delete VM=$VM snapshot
            virsh dumpxml $VM | sed "s@$VM_SNAP@$VM_DISK@g" >/tmp/$VM.xml
            virsh undefine $VM
            virsh define /tmp/$VM.xml && rm -f /tmp/$VM.xml
         else
            log info blockcommit snapshot $VM_SNAP into original disk $VM_DISK
            virsh blockcommit $VM $VM_IDISK --active --pivot --verbose >>$LOGDIR/$(basename $0).log 2>&1 || log error could not blockcommit snapshot $VM_SNAP
            log info remove snapshot $BACKUP_ID
            virsh snapshot-delete $VM $BACKUP_ID --metadata >>$LOGDIR/$(basename $0).log 2>&1 || log error could not delete VM=$VM snapshot
            log info deleting snapshot file $VM_SNAP
            rm -f $VM_SNAP || log warning could not delete snapshot file $VM_SNAP
         fi
      done
      find $BACKUP_DIR -depth -type d -name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9].failed' -exec rm -rfv {} \;
      find $BACKUP_DIR -depth -type d -name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9].running' -exec rm -rfv {} \;
   virsh -q pool-list | awk '{print $1}' | while read POOL
   do
      log info refreshing pool $POOL
      virsh pool-refresh $POOL >/dev/null
   done
   fi
}

# snapshot VM
dosnapshot(){ #----------------------------------------------
   VM=$1
   SNAPSHOT_ID=$2
   log info creating snapshot of VM=$VM SNAPSHOT_ID=$SNAPSHOT_ID
   [ "x$VM" = "x" ] && dohelp
   [ "x$SNAPSHOT_ID" = "x" ] && dohelp
   virsh snapshot-list $VM | sed '1,2d;/^$/d' | awk '{print $1}' | grep -q "^$SNAPSHOT_ID$" && log error SNAPSHOT_ID=$SNAPSHOT_ID already exists
   log info create snapshot $SNAPSHOT_ID of VM=$VM suspend VM
   virsh snapshot-create-as --domain $VM $SNAPSHOT_ID --atomic >>$LOGDIR/$(basename $0).log 2>&1 || log error failed to create snapshot
   log info snapshot $SNAPSHOT_ID successfully created: resume VM
}

# list VM snapshots
listsnapshot(){ #----------------------------------------------
   echo
   echo "   Existing Snapshots for VMs"
   (echo VM,Type,ID,Created Time
   echo "----------,----,--------,---------------"
   virsh -q list --all | awk '{print $2}' | while read VM
   do
      virsh snapshot-list $VM | sed '1,2d;/^$/d' | while read QCOW_SNAP ; do
         SNAP_ID=$(echo "$QCOW_SNAP" | awk '{ print $1}')
         SNAP_TIME=$(echo "$QCOW_SNAP" | awk '{ print $2 " " $3 " " $4 }')
         echo "$VM,qcow2,$SNAP_ID,$SNAP_TIME"
      done
   done ) | grep -v "$BACKUP_ID" | column -t -s, | sed 's/^/   /g'
   echo
}

# remove VM snapshots
removesnapshot(){ #----------------------------------------------
   VM=$1
   SNAPSHOT_ID=$2
   [ "x$VM" = "x" ] && log error var VM is empty
   [ "x$SNAPSHOT_ID" = "x" ] && log error var SNAPSHOT_ID is empty
   virsh snapshot-list $VM | sed '1,2d;/^$/d' | awk '{print $1}' | grep -q "^$SNAPSHOT_ID$" || log error SNAPSHOT_ID=$SNAPSHOT_ID does not exist
   dowarn
   log info remove qcow2 snapshot $SNAPSHOT_ID
   virsh snapshot-delete $VM $SNAPSHOT_ID
}

# merge VM snapshots
mergesnapshot(){ #----------------------------------------------
   VM=$1
   SNAPSHOT_ID=$2
   dowarn
   log info force shutdown of VM=$VM to be sure its down
   virsh -q list | awk '{print $2}' | grep -q "^$VM$" && virsh destroy $VM >>$LOGDIR/$(basename $0).log 2>&1
   virsh snapshot-list $VM | sed '1,2d;/^$/d' | awk '{print $1}' | grep -q "^$SNAPSHOT_ID$" || log error SNAPSHOT_ID=$SNAPSHOT_ID does not exist
   virsh snapshot-revert --paused $VM $SNAPSHOT_ID >>$LOGDIR/$(basename $0).log 2>&1 || log error could not merge snapshot $SNAPSHOT_ID
   log info reverting to snapshot $SNAPSHOT_ID done, VM is paused, because memory is also restored, snapshot is still remaining
   virsh resume $VM
}

# ---------- MAIN PROGRAM --------------------------------------------------
# ---------- PARSE ALL INPUT ARGUMENTS --------------------
DOBACKUP=0 
DOCLEANUPBACKUP=0
DORESTORE=0 
DOSNAPSHOT=0 
REMOVESNAPSHOT=0 
MERGESNAPSHOT=0
LISTSNAPSHOT=0
DODELETE=0 
DOLISTVMS=0
DOROTATE=0
KEEPGEN=0
while [ $# -gt 0 ] ; do
   ARG=$1
   case $ARG in
      -b) # backup vm
         DOBACKUP=1
         shift
         VM=$1
         virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" || dohelp
         shift
         ;;
      -bc) # backup vm and compress
         DOBACKUPCOMPRESSED=1
         shift
         VM=$1
         virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" || dohelp
         shift
         ;;
      -be) # only save mbr of this LVs
         shift
         DISK_EXCLUDES="$1"
         shift
         echo $DISK_EXCLUDES | tr ',' ' ' | while read DISK
         do
            log debug i will exclude this DISK=$DISK
         done
         ;;
      -bg) # keep generations
         DOROTATE=1
         shift
         KEEPGEN=$1
         echo $KEEPGEN | grep -q [123456789] || dohelp
         shift
         ;;
      -bp) # change backup path
         shift
         BACKUP_DIR=$(echo $1 | sed 's|[/]*$||')
         shift
         test -d $BACKUP_DIR || log error BACKUP_DIR=$BACKUP_DIR does not exist
         ;;
      -bf) # cleanup failed backup snapshots
         DOCLEANUPBACKUP=1
         shift
         ;;
      -br) # restore vm
         DORESTORE=1
         shift
         RESTOREDIR=$(echo $1 | sed 's|[/]*$||')
         test -d $1 || dohelp
         shift
         ;;
      -sc) # create vm snapshot
         DOSNAPSHOT=1
         shift
         VM=$1
         shift
         SNAPSHOT_ID=$1
         shift
         ;;
      -sd) # remove vm snapshot
         REMOVESNAPSHOT=1
         shift
         VM=$1
         shift
         SNAPSHOT_ID=$1
         shift
         ;;
      -sr) # rollback vm snapshots 
         MERGESNAPSHOT=1
         shift
         VM=$1
         shift
         SNAPSHOT_ID=$1
         shift
         ;;
      -sl) # list vm snapshots
         LISTSNAPSHOT=1
         shift
         VM=$1
         shift
         ;;
      -d) # delete vm
         DODELETE=1
         shift
         VM=$1
         virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" || dohelp
         shift
         ;;
      -l) # list VMs
         DOLISTVMS=1
         shift
         VM=$1
         if [ "x" != "x$VM" ] 
         then
            shift
         fi
         ;;
      *)
         dohelp 
         ;;
   esac
done

# only allow one operation at the same time
[ $(( $DOBACKUP + $DOBACKUPCOMPRESSED + $DOCLEANUPBACKUP + $DORESTORE + $DODELETE + $DOSNAPSHOT + $REMOVESNAPSHOT + $MERGESNAPSHOT + $LISTSNAPSHOT + $DOLISTVMS )) -gt 1 ] && dohelp

# ---------- DO THE WORK NOW -------------------------------------------------

# check if all progs are installed
for PROG in virsh qemu-img dd lzop awk sed cut tr logger mail
do
   which $PROG >/dev/null 2>&1 || log error $PROG does not exist, please install first
done

if [ $DOBACKUP -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   dobackup "$VM" "$BACKUP_DIR/$VM/$BDATE" "$DISK_EXCLUDES"
   if [ $KEEPGEN -gt 0 ] ; then
      dorotate "$BACKUP_DIR/$VM" "$BDATE_PATTERN" "$KEEPGEN"
   fi
elif [ $DOBACKUPCOMPRESSED -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   dobackupcompressed "$VM" "$BACKUP_DIR/$VM/$BDATE" "$DISK_EXCLUDES"
   if [ $KEEPGEN -gt 0 ] ; then
      dorotate "$BACKUP_DIR/$VM" "$BDATE_PATTERN" "$KEEPGEN"
   fi
elif [ $DOCLEANUPBACKUP -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   docleanupbackup
elif [ $DORESTORE -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   dorestore "$RESTOREDIR"
elif [ $DOSNAPSHOT -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   dosnapshot "$VM" "$SNAPSHOT_ID" 
elif [ $REMOVESNAPSHOT -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   removesnapshot "$VM" "$SNAPSHOT_ID"
elif [ $MERGESNAPSHOT -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   mergesnapshot "$VM" "$SNAPSHOT_ID"
elif [ $LISTSNAPSHOT -eq 1 ] ; then
   listsnapshot "$VM"
elif [ $DODELETE -eq 1 ] ; then
   createlock "/var/run/$(basename $0).lck"
   dodelete "$VM"
elif [ $DOLISTVMS -eq 1 ] ; then
   if [ "x" = "x$VM" ] ; then
      listvms
   else
      virsh -q list --all | awk '{print $2}' | grep -q "^$VM$" || log error VM=$VM does not exist  
      listvm $VM
   fi
else
   dohelp
fi

rm -f "$LCK_FILE"
################################################################################
