#!/bin/bash
# DESC: make RCS backups of importent config files
# $Revision: 1.2 $
# $RCSfile: rcs-backup.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/sbin:/usr/bin:/sbin:/bin


RCS_NOTICE="auto backup"

# can be a file or dir
RCS_SAVE='
/usr/local/sbin
/usr/local/bin
'

which ci >/dev/null 2>&1 
if [ $? -ne 0 ]
then
   echo "ERROR, comand ci not found, please install rcs package"
   exit 1
fi

echo "$RCS_SAVE" | egrep '^/' | while read FILES
do 
   find $FILES -type f -print | egrep -v "/RCS/.*,v$" | while read FILE
   do
      test -d $(dirname $FILE)/RCS || mkdir $(dirname $FILE)/RCS
      echo "$RCS_NOTICE" | ci -u -l $FILE >/dev/null 2>&1
   done
done

################################################################################
# $Log: rcs-backup.sh,v $
# Revision 1.2  2016/12/26 08:11:47  chris
# cleanup
#
