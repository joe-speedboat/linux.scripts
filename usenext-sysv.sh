#!/bin/bash
# DESC: start/stop usenext client for linux as system service
# $Revision: 1.1 $
# $RCSfile: usenext-sysv.sh,v $
# $Author: chris $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


#
#
RET=1
# default gschnabu
SDIR="/tmp"
SUSR="usenext"
LOG=/tmp/usenext.log
umask 000

#get status gschnabu
SSTAT=`pgrep -f '.*/usr/lib/usenext/UseNeXT.exe.*'|wc -l`

start () {
        if [ "$SSTAT" -ne 3 ]
        then
                pkill -9 -f  '.*/usr/lib/usenext/UseNeXT.exe.*'
                echo "   Starting usenext... "
                sleep 2
                su - $SUSR -c "/usr/bin/mono /usr/lib/usenext/UseNeXT.exe lang:de >> $LOG 2>&1" &
                sleep 1
        fi
        status
}

stop () {
        pkill -f  '.*/usr/lib/usenext/UseNeXT.exe.*'
        sleep 5
        pkill -9 -f  '.*/usr/lib/usenext/UseNeXT.exe.*'
        sleep 1
        SSTAT=`pgrep -f '.*/usr/lib/usenext/UseNeXT.exe.*'|wc -l`
        echo "   usenext stopped..."
        RET=0
}

status() {
        sleep 1
        SSTAT=`pgrep -f '.*/usr/lib/usenext/UseNeXT.exe.*'|wc -l`
        if [ "$SSTAT" -eq 3 ] ; then
                echo '   usenext is running...'
                RET=0
        else
                echo '   usenext is not running'
                RET=1
        fi
}

restart() {
        stop
        start
}

case $1 in
        start)
                start
        ;;
        stop)
                stop
        ;;
        restart)
                restart
        ;;
        status)
                status
        ;;
        *)

        echo "Usage: $DAEMON {start|stop|restart|status}"
        RET=1
esac

exit $RET

################################################################################
# $Log: usenext-sysv.sh,v $
# Revision 1.1  2012/12/21 16:43:34  chris
# Initial revision
#
