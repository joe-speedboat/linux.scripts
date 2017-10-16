#!/bin/bash
# DESC: traffic analyser to find out, what machine is doing in network
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: tmon.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


FILE=connections.txt
LO='127.0.0.1'
HOSTIP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' | sed -e s/addr://)
BKPIP=$(/sbin/ifconfig eth1 | awk '/inet/ { print $2 } ' | sed -e s/addr://)
CONS=$(netstat -tan | grep ESTABLISHED | grep -v "$BKPIP" | grep -v "$LO" | grep -v "$HOSTIP.*$HOSTIP" | awk '{print $4";"$5}')

for CON in "$CONS"
do
   grep -q "$CON" $FILE || echo "$CON" >> $FILE
done

################################################################################
# $Log: tmon.sh,v $
# Revision 1.2  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:20  chris
# Initial revision
#
