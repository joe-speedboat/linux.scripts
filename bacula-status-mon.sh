#!/bin/bash
# DESC: give the actual status of currently running jobs
# $Revision: 1.5 $
# $RCSfile: bacula-status-mon.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

HEADER="+-------+---------------------+---------------------+------+-------+-----------+----------------+-----------+
| JobId | Name                | StartTime           | Type | Level | JobFiles  | JobBytes       | JobStatus |
+-------+---------------------+---------------------+------+-------+-----------+----------------+-----------+"
SLEEP=10
TMPF=/tmp/$(basename $0).tmp.$$
BREAK=

if [ "$1" != "-i" ]
then
   BREAK=break
fi


while true
do
   clear
   echo list jobs | bconsole > $TMPF
   for h in $(cat $TMPF | grep '| R         |' | awk '{print $4}' | sort -u | sed 's/-.*/-fd/g' | grep -v '^$')
   do
   echo "--------------------------------- $h ------------------------------------"
   echo status client=$h |bconsole| egrep -A6 'Running Jobs'
   done
   echo
   echo ".------------------------ LAST 10 RUNNING JOBS -------------------------------------------------------------."
   echo "$HEADER"
   cat $TMPF | grep '| R         |' | tail
   echo
   echo '.------------------- LAST 20 TERMINATED JOBS ---------------------------------------------------------------.'
   echo "$HEADER"
   cat $TMPF | grep '| T         |' | tail -n20
   echo
   echo '.---------------------- LAST 10 ERROR JOBS -----------------------------------------------------------------.'
   echo "$HEADER"
   cat $TMPF | grep '| E         |' | tail
   echo
   echo '.---------------------- LAST 10 RESTORE JOBS ---------------------------------------------------------------.'
   echo "$HEADER"
   cat $TMPF | grep '| R    |' | tail
   echo
   rm -f $TMPF
   $BREAK
   sleep $SLEEP
done

###############################################################################
# $Log: bacula-status-mon.sh,v $
# Revision 1.5  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.4  2010/03/20 13:36:11  chris
# bug fixing
#
# Revision 1.3  2010/03/20 12:13:08  chris
# minor bugfixing
#
# Revision 1.2  2010/03/20 11:17:35  chris
# update from production release
#
# Revision 1.1  2010/03/19 20:52:12  chris
# Initial revision
#
