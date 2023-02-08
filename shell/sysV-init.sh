#!/bin/bash
# DESC: script to start java process as systemV service
# $Revision: 1.3 $
# $RCSfile: sysV-init.sh,v $
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
HDIR="/opt/activemq"
HUSER="activemq"
LOG=$HDIR/log/activemq-base.log

#get status gschnabu
HSTAT=`pgrep -f '/usr/java/bin/java.*-Dorg.apache.activemq'|wc -l`

start () {
        if [ "$HSTAT" -ne 1 ]
        then
                pkill -9 -f  '/usr/java/bin/java.*-Dorg.apache.activemq'
                echo "   Starting activemq... "
                sleep 2
                su - $HUSER -c "$HDIR/apache-activemq/bin/activemq | tee -a $LOG | egrep 'ActiveMQ JMS Message Broker'" &
                sleep 15
        fi
        status
}

stop () {
        pkill -f  '/usr/java/bin/java.*-Dorg.apache.activemq'
        sleep 10
        pkill -9 -f  '/usr/java/bin/java.*-Dorg.apache.activemq'
        sleep 1
        HSTAT=`pgrep -f '/usr/java/bin/java.*-Dorg.apache.activemq'|wc -l`
        echo "   activemq stopped..."
        RET=0
}

status() {
        sleep 1
        HSTAT=`pgrep -f '/usr/java/bin/java.*-Dorg.apache.activemq'|wc -l`
        if [ "$HSTAT" -eq 1 ] ; then
                echo '   activemq is running...'
                RET=0
        else
                echo '   activemq is not running'
                echo '   or not running cleanly...'
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
# $Log: sysV-init.sh,v $
# Revision 1.3  2014/04/28 12:39:10  chris
# desc changed
#
# Revision 1.2  2012/06/10 19:18:47  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:20  chris
# Initial revision
#
