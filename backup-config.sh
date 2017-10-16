#! /bin/bash
# DESC: get a backup of config files and rotate generations
# $Revision: 1.2 $
# $RCSfile: backup-config.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

BDIR="/backup/config"
SUFF="config"
DIRS="/etc /usr/local /root/bin /README /var/spool/cron"
GEN=60
SUBJ="Config Backup Fehler auf $(hostname -f)"
TO=root

tar cfj $BDIR/$(date +%Y%m%d%H%M)-$SUFF.tar.bz2 $DIRS >&/dev/null || echo $0 | mail -s "$SUBJ" $TO
cd $BDIR
mkdir save
mv $(ls -1 $BDIR/*tar* | tail -n $GEN) save
rm -f *tar*
mv save/* ./
rmdir save

################################################################################
# $Log: backup-config.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:09  chris
# Initial revision
#
