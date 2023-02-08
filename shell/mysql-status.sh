#!/bin/bash
# DESC: MySQL Server and Replication Deamon Status Monitor
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: mysql-status.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

RC=1

#get mysql server status
/etc/init.d/mysqld status >/dev/null
if [ $? -ne 0 ]
then
   MYSQL=nok
else
   MYSQL=ok
fi

#if cluster then check mysql replication status also
test -f /var/lib/mysql/master.info
if [ $? -eq 0 ]
then
   REPL=$(mysqladmin processlist --verbose | egrep 'Has read all relay log; waiting for the slave|Reading event from the relay log|Waiting for master to send event' | wc -l)
   if [ $REPL -ne 2 ]
   then
      REP=nok
   else
      REP=ok
   fi

   #get cluster exit code 
   if [ "$MYSQL$REP" == 'okok' ]
   then
      RC=0
      echo ok
   else
      RC=1
      echo "REPLICATION=$REP MYSQL=$MYSQL"
   fi
else
   #if no cluster, get single node exit code
   if [ "$MYSQL" == "ok" ]
   then
      RC=0
      echo ok
   else
      RC=ok
      echo nok
   fi
fi

exit $RC

################################################################################
# $Log: mysql-status.sh,v $
# Revision 1.2  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:14  chris
# Initial revision
#
