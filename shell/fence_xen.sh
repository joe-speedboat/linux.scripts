#!/bin/bash
# DESC: provide fencing for xen test clusters (fence_manual fake)
# INSTALL: cp fence_xen.sh /sbin/ ; mv /sbin/fence_manual /sbin/fence_manual.orig
# INSTALL: ln -s /sbin/fence_manual /sbin/fence_xen.sh
# INSTALL: # and install ssh-pub-keys from cluster-nodes to Dom0
# INSTALL: # now you can use fence_manual and have "real fencing"
# $Revision: 1.2 $
# $RCSfile: fence_xen.sh,v $
# $Author: chris $
###############################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

read INPUT

# where is Dom0
HW=192.168.123.101
# ssh user on Dom0 to use for fencing (xm restart ...)
U=root

NODE=
# cluster suite sends arguments via stdin
echo "$INPUT" | egrep -q 'nodename='
if [ $? = 0 ]
then
   NODE=$(echo $INPUT | sed 's/.*nodename=//g')
   NODE=$(echo $NODE | cut -d. -f1)
else
   INPUT="$*"
   echo "$INPUT" | egrep -q '\-n '
   if [ $? -ne 0 ]
   then
      echo ''
      echo '*** This is the Xen replacement of fence_manual ***'
      echo options: $*
      echo 'Usage: fence_manual -n hostname'
      echo ''
      exit 1
   else
      NODE=$(echo $INPUT | sed 's/.*\-n //g')
      NODE=$(echo $NODE | cut -d. -f1)
   fi
fi

echo "*** Starting Xen replacement of fence_manual ***"
ssh $U@$HW "xm list" | grep -qi $NODE
if [ $? -ne 0 ]
then
   echo "error: $NODE is not running on $HW"
   exit 1
fi

echo "sending reboot signal for $NODE to $HW ..."
ssh $U@$HW "xm reboot $NODE && echo ...done..." | grep '...done...'
if [ $? -ne 0 ]
then
   echo "error: $NODE not fenced ! ! !"
   exit 1
fi

exit 0

################################################################################
# $Log: fence_xen.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:11  chris
# Initial revision
#
