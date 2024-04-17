#!/bin/bash
# DESC: script to name and rotate multiple backup files in a dir
# $Revision: 1.2 $
# $RCSfile: back-rotate.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

DATE=$(date '+%Y%m%d%H%M')
ID=aeos-bkp
BDIR=/home/backup/aeos
SUFF=.tar.gz
GEN=10

cd $BDIR
for BKP in $(ls -1 | grep $SUFF | grep -v $ID)
do
   mv $BKP $DATE-$ID-$BKP
done
mkdir tmp
for SAVE in $(ls -1 | grep $SUFF | grep $ID | cut -d- -f1 | sort -un | tail -n$GEN)
do
   mv $SAVE-$ID* tmp
done
rm -f *$ID*$SUFF
mv tmp/* ./
rm -r tmp

################################################################################
# $Log: back-rotate.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:08  chris
# Initial revision
#
