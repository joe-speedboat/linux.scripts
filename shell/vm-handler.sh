#!/bin/bash
# DESC: archive and restore projects of virtual machines for xen
# $Revision: 1.8 $
# $RCSfile: vm-handler.sh,v $
# $Author: chris $
##########################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# where to store the data if no option -P is given
STORE=/data/backup/xen
# where are the xen config files
XCONF=/etc/xen/auto
# size of snapshot LVs
SSIZE='2G'

HELP=0
BACKUP=0
RESTORE=0
DELETE=0
START=0
STOP=0
CONFIG=

# parse the arguments
for i in $( seq 1 $# ) ; do
   if [ "$1" = "-h" ] ; then HELP=1    ; fi
   if [ "$1" = "-b" ] ; then BACKUP=1  ; fi
   if [ "$1" = "-r" ] ; then RESTORE=1 ; fi
   if [ "$1" = "-d" ] ; then DELETE=1  ; fi
   if [ "$1" = "-U" ] ; then START=1   ; fi
   if [ "$1" = "-D" ] ; then STOP=1    ; fi
   if [ "$1" = "-P" ] ; then shift ; STORE=$1 ; fi
   if [ "$1" = "-C" ] ; then shift ; CONFIG="$CONFIG $1" ; fi
   shift
done

# check input
[ $(( $HELP + $BACKUP + $RESTORE + $DELETE + $START + $STOP )) -gt 1 ] && HELP=1
[ $(( $BACKUP + $RESTORE + $DELETE + $START + $STOP )) -eq 1 ] && [ -z "$STORE" -o -z "$CONFIG" ] && HELP=1


# function for logging tasks
log(){
   [ "$1" = "err" ] && LEVEL=ERROR
   [ "$1" = "warn" ] && LEVEL=WARNING 
   [ "$1" = "info" ]&& LEVEL=INFO
   shift
   echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0)[$$]: $LEVEL: $*"
   [ "$LEVEL" = "ERROR" ] && exit 1
}

if [ $HELP -eq 1 ] ; then
   echo
   echo "   Usage:     $(basename $0) <OPTIONS>"
   echo
   echo "   Options:   -P [PATH] re/store from this path instead of $STORE"
   echo "              -C [xen conf file]    name of the conf file"
   echo "              -U    start VMs" 
   echo "              -D    stop VMs" 
   echo "              -b    backup VMs"
   echo "              -r    restore VMs"
   echo "              -d    delete VMs" 
   echo "              -h    print this help" 
   echo
   echo "   Examples:"
   echo "   $(basename $0) -b -C xen10 -C xen11 -C xen12"
   echo "   $(basename $0) -r -C xen10 -C xen12"
   echo "   $(basename $0) -d -C xen11"
   echo "   $(basename $0) -r -P ./ -C xen11"
   echo
   exit 0
elif [ $BACKUP -eq 1 ] ; then
   test -d $STORE || log err "directory $STORE does not exist"
   for CFG in $CONFIG ; do
      ID=$( grep '^name' $XCONF/$CFG | sed 's/.*=//g;s/"//g;s/ //g')
      DISK=$( grep '^disk' $XCONF/$CFG | sed 's/.*phy://;s/,.*]//' )
      LV=$(basename $DISK)
      VG=$(echo $DISK | cut -d'/' -f3)

      cp -auf $XCONF/$CFG $STORE/$CFG
      if [ $? -eq 0 ] ; then
         log info "saved config file $XCONF/$CFG to $STORE/$CFG"
      else
         log err "saving config file $XCONF/$CFG to $STORE/$CFG failed"
      fi
      
      if [ -e $DISK ] ; then
         if [ -e ${DISK}_snap ] ; then
	    log warn "snapshot ${DISK}_snap is already present"
	    lvremove -f ${DISK}_snap >/dev/null 2>&1
	    if [ $? -eq 0 ] ; then
	       log info "snapshot ${DISK}_snap successfully removed"
	    else
	       log err "removing snapshot ${DISK}_snap failed"
	    fi
         fi
	 lvcreate -s -n ${LV}_snap -L $SSIZE $DISK >/dev/null 2>&1
	 if [ $? -eq 0 ] ; then
	    log info "snapshot ${DISK}_snap successfully created"
	 else
	    log err "creating snapshot ${DISK}_snap failed"
	 fi
      fi

      log info "dumping disk $DISK to $STORE/$LV.img.gz"
      dd if=${DISK}_snap bs=8192 2>/dev/null | gzip -c | cat > $STORE/$LV.img.gz
      if [ $? -eq 0 ] ; then
         log info "disk sucessfully dumped"
      else
         log err "disk dumping failed"
      fi

      lvs $DISK > $STORE/$LV.lvm
      lvremove -f ${DISK}_snap >/dev/null 2>&1
      if [ $? -eq 0 ] ; then
         log info "snapshot ${DISK}_snap successfully removed"
      else
         log err "removing snapshot ${DISK}_snap failed"
      fi
   done
elif [ $RESTORE -eq 1 ] ; then
   test -d $STORE || log err "directory $STORE does not exist"
   for CFG in $CONFIG ; do
      ID=$( grep '^name' $STORE/$CFG | sed 's/.*=//g;s/"//g;s/ //g' )
      DISK=$( grep '^disk' $STORE/$CFG | sed 's/.*phy://;s/,.*]//' )
      LV=$(basename $DISK)
      VG=$(echo $DISK | cut -d'/' -f3)
      SIZE="$(grep " $LV " $STORE/$LV.lvm | awk '{print $4}')"

      test -r $STORE/$LV.img.gz
      if [ $? -ne 0 ] ; then
         log err "restore file $STORE/$LV.img.gz does not exist"
      fi

      test -r $STORE/$LV.lvm
      if [ $? -ne 0 ] ; then
         log err "config file $STORE/$LV.lvm does not exist"
      fi

      test -r $STORE/$CFG
      if [ $? -ne 0 ] ; then
         log err "config file $STORE/$CFG does not exist"
      fi

      xm list | grep -q "^$ID " 
      if [ $? -eq 0 ] ; then
         log warn "vm $ID is still running"
	 xm destroy $ID >/dev/null 2>&1
	 if [ $? -eq 0 ] ; then
	    log info "vm $ID stopped"
	 else
	    log err "stopping vm $ID failed"
	 fi
      else
         log info "vm $ID is already stoped" 
      fi

      if [ -e $DISK ] ; then
         log info "disk $DISK is already present, removing now"
	 lvremove -f $DISK >/dev/null 2>&1
         sleep 1
	 if [ $? -eq 0 ] ; then
	    log info "disk $DISK successfully removed"
	 else
	    log err "removing disk $DISK failed"
	 fi
      fi

      lvcreate -n $LV -L $SIZE $VG >/dev/null 2>&1
       if [ $? -eq 0 ] ; then
          log info "disk $DISK created with size $SIZE"
       else
          log err "creating disk $DISK failed"
       fi

      log info "restoring disk $STORE/$LV.img.gz to $DISK"
      zcat $STORE/$LV.img.gz | dd of=$DISK bs=8192 2>/dev/null
      if [ $? -eq 0 ] ; then
         log info "disk restored successfully" 
      else
         log err "restoring disk failed"
      fi

      cp -auf $STORE/$CFG $XCONF/$CFG >/dev/null 2>&1
      if [ $? -eq 0 ] ; then
         log info "config file $STORE/$CFG restored to $XCONF/$CFG" 
      else
         log err "restoring config file $STORE/$CFG to $XCONF/$CFG failed"
      fi
   done
elif [ $DELETE -eq 1 ] ; then
   for CFG in $CONFIG ; do
      ID=$( grep '^name' $XCONF/$CFG | sed 's/.*=//g;s/"//g;s/ //g' )
      DISK=$( grep '^disk' $XCONF/$CFG | sed 's/.*phy://;s/,.*]//' )

      xm list | grep -q "^$ID " 
      if [ $? -eq 0 ] ; then
         log warn "vm $ID is still running"
	 xm destroy $ID >/dev/null 2>&1
	 if [ $? -eq 0 ] ; then
	    log info "vm $ID stopped"
	 else
	    log err "stopping vm $ID failed"
	 fi
      else
         log info "vm $ID is already stoped" 
      fi

      if [ -e $DISK ] ; then
	 lvremove -f $DISK >/dev/null 2>&1
         sleep 1
	 if [ $? -eq 0 ] ; then
	    log info "disk $DISK successfully removed"
	 else
	    log err "removing disk $DISK failed"
	 fi
      fi

      if [ -e $XCONF/$CFG ] ; then
         rm -f $XCONF/$CFG
         if [ $? -eq 0 ] ; then
            log info "config file $XCONF/$CFG removed"
         else  
            log err "removing config file $XCONF/$CFG failed"
         fi
      fi 
   done
elif [ $START -eq 1 ] ; then
   for CFG in $CONFIG ; do
      ID=$( grep '^name' $XCONF/$CFG | sed 's/.*=//g;s/"//g;s/ //g' )

      xm list | grep -q "^$ID " 
      if [ $? -eq 0 ] ; then
         log warn "vm $ID is already running"
      else
         xm create $XCONF/$CFG >/dev/null 2>&1
         if [ $? -eq 0 ] ; then
            log info "vm $ID started" 
         else
            log err "starting vm $ID failed"
         fi
      fi
   done
elif [ $STOP -eq 1 ] ; then
   for CFG in $CONFIG ; do
      ID=$( grep '^name' $XCONF/$CFG | sed 's/.*=//g;s/"//g;s/ //g' )

      xm list | grep -q "^$ID " 
      if [ $? -eq 0 ] ; then
         xm shutdown $ID >/dev/null 2>&1
         if [ $? -eq 0 ] ; then
            log info "successfully sent shutdown to vm $ID " 
         else
            log err "stopping vm $ID failed"
         fi
      else
         log warn "vm $ID was already stopped"
      fi
   done
fi

##########################################################################################################
# $Log: vm-handler.sh,v $
# Revision 1.8  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.7  2010/05/01 20:06:28  chris
# check more things before start restore
#
# Revision 1.4  2010/04/30 16:26:40  chris
# moved internal vars to external args of script
# doing some cleanup
#
# Revision 1.2  2010/04/30 08:21:44  chris
# help added
# checking for restore files before start restore task
#

