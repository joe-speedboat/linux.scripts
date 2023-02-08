#!/bin/bash
# DESC: script to note daily business for later reporting
# $Revision: 1.2 $
# $RCSfile: stamp.sh,v $
# $Author: chris $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


TIMEH="$(date '+%H:%M')"
TIME="$(date '+%A %Y.%m.%d')"
FILE=$HOME/.stamp.txt
HEAD="
$TIME
---------------------"

[ $# -lt 1 ] && cat $FILE && exit 0
grep -q "$TIME" $FILE || echo "$HEAD" >>  $FILE
if [ "$1" == "-t" ]
then
   shift
   echo "$TIMEH: $*" >> $FILE
else
   echo "$*" >> $FILE
fi

################################################################################
# $Log: stamp.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:19  chris
# Initial revision
#
