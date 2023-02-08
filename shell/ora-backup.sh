#!/bin/bash
#
# DESC: Script to generate a fullbackup of instance and write logs to syslog
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: ora-backup.sh,v $
#
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# USEFULL RMAN SETTINGS
# RMAN> connect target;
# RMAN> show all;
# CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
# CONFIGURE BACKUP OPTIMIZATION ON;
# CONFIGURE DEFAULT DEVICE TYPE TO DISK;
# CONFIGURE CONTROLFILE AUTOBACKUP ON;
# CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT   '/opt/u4/oradata/backup/%d_%T_%I_%U.bkp';
# CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/opt/u4/backup/snapcf_tcDTA02.f';

PROGRAM=`basename $0`
export STATUSFILE_PATH=~oracle
export STATUSFILE=statusOracleDB$(hostname -s).txt

. ~oracle/.bashrc

DATE=$(date +\%Y\%m\%d)
TIME=$(date +\%H\%M\%S)
TAG=TAG${DATE}T${TIME}


rman <<EOF | while read line ; do /bin/logger -t RMAN-$ORACLE_SID "$line "; done

connect target;
backup as compressed backupset device type disk tag '$TAG' database include current controlfile;
backup as compressed backupset device type disk tag '$TAG' archivelog all not backed up;
allocate channel for maintenance type disk;
delete noprompt obsolete;
release channel;
exit
EOF

################################################################################
# $Log: ora-backup.sh,v $
# Revision 1.2  2011/08/30 13:08:37  chris
# fixed logger
#
# Revision 1.1  2010/01/17 20:40:15  chris
# Initial revision
#
