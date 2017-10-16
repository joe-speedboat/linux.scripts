#!/bin/bash
# DESC: create backup of virsh kvm host configuration
# $Author: chris $
# $Revision: 1.3 $
# $RCSfile: virsh-config-backup.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

########## GLOBAL VARIABLES ####################################################
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BDIR=/srv/vm/config/$(uname -n)


########## MAIN SCRIPT GOES HERE
#!/bin/bash

if [ "x$1" != "x" ]
then
      BDIR=$1
fi

mkdir -p $BDIR/{vm,pool,vol,net,iface}
find $BDIR -type f -name '*.xml' -exec rm -f {} \;

cd $BDIR/vm || exit 1
virsh -q list --all | awk '{print $2}' | while read VM
do
   virsh dumpxml $VM > $VM.xml
done


cd $BDIR/pool || exit 1
virsh -q pool-list | awk '{print $1}' | while read POOL
do
   virsh pool-dumpxml $POOL > $POOL.xml
done

cd $BDIR/vol || exit 1
virsh -q pool-list | awk '{print $1}' | while read POOL
do
   virsh pool-refresh $POOL >/dev/null  
   virsh -q vol-list $POOL | awk '{print $1}' | while read VOL
   do
      virsh vol-dumpxml --pool $POOL $VOL > $VOL.xml
   done
done

cd $BDIR/net || exit 1
virsh -q net-list | awk '{print $1}' | while read NET
do
   virsh net-dumpxml $NET > $NET.xml
done

cd $BDIR/iface || exit 1
virsh -q iface-list | awk '{print $1}' | while read IFACE
do
   virsh iface-dumpxml $IFACE > $IFACE.xml
done


################################################################################
# $Log: virsh-config-backup.sh,v $
# Revision 1.3  2017/04/05 14:59:37  chris
# test
#
# Revision 1.2  2017/04/05 14:59:12  chris
# virsh-config-backup
#
# Revision 1.1  2017/04/05 14:57:57  chris
# Initial revision
#
