#!/bin/bash
# DESC: oracle 12c full export backup with datapump
# $Author: chris $
# $Revision: 1.1 $
# $RCSfile: ora_12c_dp_backup.sh,v $
#
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# sysdba
#    create or replace directory expdp_dir as '/srv/u01/dp';
#    SELECT COUNT(*) FROM obj$ WHERE status IN (4, 5, 6);
#    @/srv/u00/app/oracle/product/12.1.0/db1/rdbms/admin/catproc.sql
#    @/srv/u00/app/oracle/product/12.1.0/db1/rdbms/admin/utlrp.sql

[ "$USER" = "oracle" ] || (echo "START AS ORACLE USER" ; exit 1)

. ~/.bashrc
TO="root"
BDST=/srv/u01/dp

expdp \'/ as sysdba\' FULL=Y REUSE_DUMPFILES=YES DIRECTORY=expdp_dir DUMPFILE=fullbackup.dmp LOGFILE=fullbackup.log >/tmp/fullbackup.tmp 2>&1

ls -l $BDST/fullbackup.* > /tmp/fullbackup.log
echo >> /tmp/fullbackup.log
echo >> /tmp/fullbackup.log
cat /tmp/fullbackup.tmp >> /tmp/fullbackup.log

grep -q 'successfully completed at' $BDST/fullbackup.log
if [ $? -eq 0 ]
then
   cat /tmp/fullbackup.log | mailx -s "INFO: Backup on $(uname -n) finished" $TO
else
   cat /tmp/fullbackup.log | mailx -s "ERROR: Backup on $(uname -n) failed" $TO
fi

rm -f /tmp/fullbackup.tmp /tmp/fullbackup.log

################################################################################
# $Log: ora_12c_dp_backup.sh,v $
# Revision 1.1  2015/11/19 12:28:17  chris
# Initial revision
#
