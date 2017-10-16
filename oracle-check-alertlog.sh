#!/bin/bash
# DESC: oracle alertlog monitor, syslog wrapper and error mailer
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: oracle-check-alertlog.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

. ~oracle/.bashrc
# export ORACLE_SID=

TO="dba@domain.com"
SUBJ="$ORACLE_SID ORACLE ALERT ERRORS on $(uname -n)"

cd $ORACLE_BASE/admin/$ORACLE_SID/bdump
if [ -f alert_$ORACLE_SID.log ]
then
   grep ORA- alert_$ORACLE_SID.log > alert.err
   cat alert_$ORACLE_SID.log >> alert_$ORACLE_SID.hist
   cat alert_$ORACLE_SID.log | while read line
   do
      /bin/logger -t ORACLE-$ORACLE_SID "$line"
   done
   echo '' > alert_$ORACLE_SID.log
fi
if [ `cat alert.err|wc -l` -gt 0 ]
then
   mail -s "$SUBJ" $TO < alert.err
fi
rm -f alert.err

################################################################################
# $Log: oracle-check-alertlog.sh,v $
# Revision 1.2  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:15  chris
# Initial revision
#
