#!/usr/local/bin/bash
# DESC: search for packages in online repo of BSD release
# $Revision: 1.2 $
# $RCSfile: pkg_search.sh,v $
# WHO: chris

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
TMP=/var/tmp/pkg_search.tmp
REPO='ftp://ftp.freebsd.org/pub/FreeBSD/ports/i386/packages-8.0-release/Latest/'

if [ $# -lt 1 ]
then
   echo usage: pkg_search pattern
   exit 1
fi

test -r $TMP
DONEW=$?
OLD=`find $TMP -mtime +1 -print 2>/dev/null | wc -l`

if [ $OLD -gt 0 -o $DONEW -gt 0 ]
then
   echo downloading new index ... please wait ...
   wget --quiet -O - $REPO | sed 's#.*release\/Latest\/##g' | sed 's#.tbz\<\/a\>.*##g' | sed 's#\"\>.*##g' > $TMP
fi

grep -i $1 $TMP

# $Log: pkg_search.sh,v $
# Revision 1.2  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.1  2010/03/26 09:32:24  chris
# Initial revision
#
