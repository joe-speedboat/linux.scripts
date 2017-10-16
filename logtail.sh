#!/bin/sh
# DESC: logtail rewrite in sh, prints log lines that have been added since last logtail
# $Author: chris $
# $Revision: 1.4 $
# $RCSfile: logtail.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
###########################################################
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
set -e
LOGF=$1 # logfile itself
LOGT=$1.logtail #here we store logfile size
test -r $LOGF || (echo ERROR: can not read $LOGF ; exit 1)
test -e $LOGT || echo 0 > $LOGT || (echo ERROR: can not write $LOGT ; exit 1)
LOFFSET=`cat $LOGT` # get last run logfile size
COFFSET=`cat $LOGF | wc -c` # get current logfile size
[ $COFFSET -eq $LOFFSET ] && exit 0 # logfile has same size as last run, do nothing
[ $COFFSET -lt $LOFFSET ] && LOFFSET=0 # file is smaller than last time, we assume it got tuncated
cat $LOGF | dd  bs=1 skip=$LOFFSET conv=noerror 2>/dev/null | cat | strings
echo $COFFSET > $LOGT || (echo ERROR: can not write $LOGF ; exit 1) # write new file size

###########################################################
# $Log: logtail.sh,v $
# Revision 1.4  2017/06/16 13:36:30  chris
# lean up code :-)
#
# Revision 1.3  2017/06/16 11:03:22  chris
# error handling
#
# Revision 1.2  2017/06/16 11:00:32  chris
# add some comments
#
# Revision 1.1  2017/06/16 10:50:25  chris
# Initial revision
#
