#!/bin/bash
# DESC: script to check and keep bugy xen hosts alive
# $Revision: 1.2 $
# $RCSfile: xen-check.sh,v $
# $Author: chris $
# SRC: /etc/cron.hourly/xen-check.sh
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

cd /etc/xen/auto/

for XEN in $( ls -1)
do
   ping -c1 -w3 $XEN >/dev/null 2>&1
   if [ $? = 0 ]
   then
      DUMMY=1
   else
      xm destroy $XEN
      sleep 5
      xm create $XEN
      logger -t $(basename $0) "$XEN has been restarted"
   fi
done

################################################################################
# $Log: xen-check.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:21  chris
# Initial revision
#
