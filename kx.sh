#!/bin/bash
# DESC: kill processes matching pattern
# $Author: chris $
# $Revision: 1.1 $
# $RCSfile: kx.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PAT="$1"
ps -eo pid,args | egrep -i "$PAT" |  egrep -v "egrep -i $PAT|.*$(basename $0) $PAT|ps -eo pid.*args" | while read MYPID
do
   echo "SIGTERM: $MYPID"
   kill $(echo $MYPID | awk '{print $1}')
done
sleep 1
ps -eo pid,args | egrep -i "$PAT" |  egrep -v "egrep -i $PAT|.*$(basename $0) $PAT|ps -eo pid.*args" | while read MYPID
do
   echo "SIGKILL: $MYPID"
   kill -9 $(echo $MYPID | awk '{print $1}')
done

################################################################################
# $Log: kx.sh,v $
# Revision 1.1  2016/12/26 08:19:02  chris
# Initial revision
#

