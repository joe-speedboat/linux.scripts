#!/bin/bash
# DESC: Simple Postgres SQL backup script
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: pg_backup.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PATH=/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# NOTE:
# vi /usr/local/sbin/pg_backup.sh
# chmod 755 /usr/local/sbin/pg_backup.sh
# su - postgres
#   vi .pgpass
#   ---
#   localhost:*:*:postgres:pg-password
#   ---
#   chmod 600 .pgpass
#   crontab -e -u postgres
#   1 3 * * * /usr/local/sbin/pg_backup.sh >/dev/null

# Location to place backups.
backup_dir="/backup/pgsql"

#String to append to the name of the backup files
backup_date=`date +%d-%m-%Y`

#Numbers of days you want to keep copie of your databases
number_of_days=3

test -d $backup_dir || mkdir -p $backup_dir || exit 1

databases=$(psql -lt | perl -ane '!/(template[01]|^\s{2,}|^$)/ && print "$F[0]\n"')
for i in $databases; do
  if [ "$i" != "template0" ] && [ "$i" != "template1" ]; then
    echo Dumping $i to $backup_dir/$i\_$backup_date
    test -e $backup_dir/$i\_$backup_date.* && rm -f $backup_dir/$i\_$backup_date.*
    pg_dump -Fplain -E utf-8 $i > $backup_dir/$i\_$backup_date
    gzip $backup_dir/$i\_$backup_date
  fi
done
find $backup_dir -type f -prune -mtime +$number_of_days -exec rm -f {} \;


################################################################################
# $Log: pg_backup.sh,v $
# Revision 1.2  2015/06/12 07:35:13  chris
# changed export format to utf-8 for better compatibility
#
# Revision 1.1  2013/08/28 17:46:37  chris
# Initial revision
#
