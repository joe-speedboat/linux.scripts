#!/bin/bash
# DESC: monitor users and transactions
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: oracle-check-deadlocks.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

. ~oracle/.bashrc
# export ORACLE_SID=

SUBJ="DEADLOCK ALERT for $ORACLE_SID on $(uname -n)"
TO=joe@bitbull.ch

sqlplus -S -L "/ as sysdba" << EOF
set feed off
set heading off
spool deadlock.alert
SELECT   SID, DECODE(BLOCK, 0, 'NO', 'YES' ) BLOCKER,
              DECODE(REQUEST, 0, 'NO','YES' ) WAITER
FROM     V\$LOCK 
WHERE    REQUEST > 0 OR BLOCK > 0 
ORDER BY block DESC; 
spool off
exit
EOF

if [ `cat deadlock.alert|wc -l` -gt 0 ]
then
    mail -s "$SUBJ" $TO < deadlock.alert
fi
rm -f deadlock.alert

################################################################################
# $Log: oracle-check-deadlocks.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:15  chris
# Initial revision
#
