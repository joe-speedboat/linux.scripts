#! /bin/bash
# DESC: get a backup of all mysql databases
# $Revision: 1.2 $
# $RCSfile: backup-mysql.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

### NOTE ###
# vi /root/.my.cnf
# ---
# [client]
# host=localhost
# user=your_login
# password=your_password

BDIR="/srv/backup/mysql"

test -d $BDIR || mkdir -p $BDIR

for DB in $( mysql -N -B -e "show databases" | egrep -v 'information_schema|performance_schema' )
do
  mysqldump $DB --single-transaction | gzip > $BDIR/$DB.mysql.gz
done


################################################################################

