#!/bin/bash
# DESC: Script to start console prog as system service
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: sysV-screen-init.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


# name of the service
NAME=$( basename $0)
# prog you want to start as service
PROG="/usr/sbin/pcscd -f -a -d"
# prog you want to kill when stop service
BIN=$(echo $PROG | cut -d ' ' -f1 | rev | cut -d '/' -f1 | rev)

case "$1" in
  start)
    ps -ef | egrep -v "grep|$NAME" | grep "$BIN" && echo "$BIN was running, noting to do" && exit 0
    /usr/bin/screen -d -m -S $NAME bash -c "while true ; do $PROG ; sleep 2 ; done"
    ;;
  stop)
    pkill -9 -f "SCREEN -d -m -S $NAME"
    /usr/bin/screen -wipe
    pkill -9 $BIN
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  status)
    ps -ef | egrep -v "grep|$NAME" | grep "$BIN" || ( echo "$BIN is not running" && exit 1 )
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}" >&2
    exit 1
    ;;
esac

exit 0

################################################################################
# $Log: sysV-screen-init.sh,v $
# Revision 1.2  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:20  chris
# Initial revision
#
