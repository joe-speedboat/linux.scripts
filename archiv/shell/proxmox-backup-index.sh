#! /bin/bash
# DESC: pull the VM names out of the Proxmox image backup files
# $Revision: 1.1 $
# $RCSfile: proxmox-backup-index.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#!/bin/bash
#DESC: zieht die namen der maschinen aus dem proxmox backup und schreibt diese in ein INDEX file
#WHO: christian.ruettimann@stiftung-buehl.ch
#DATE: 20140409


DIRS='/srv/img-backup/prd /srv/img-backup/tst'




for DIR in $DIRS
do
   cd $DIR || exit 1
   rm -f INDEX
   ls -1 vzdump-qemu-*.lzo >/dev/null 2>&1 && for f in vzdump-qemu-*.lzo 
   do 
      (echo -n "$f : "; lzop -d -c $f | strings | head | grep ^name: ) >> INDEX
   done
   ls -1 vzdump-qemu-*.tgz >/dev/null 2>&1 && for f in vzdump-qemu-*.tgz
   do 
      (echo -n "$f : "; gunzip -c $f | head | strings | grep ^name: ) >> INDEX
   done
done


################################################################################
# $Log: proxmox-backup-index.sh,v $
# Revision 1.1  2014/04/09 06:48:42  chris
# Initial revision
#
