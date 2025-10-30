#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# INSTALL:
# copy to /usr/local/bin/mem_hunter.sh
# chmod 700 /usr/local/bin/mem_hunter.sh
# crontab -e -u root #run every 5min
# */5 * * * * /usr/local/bin/mem_hunter.sh

# partial process names
PATTERN='zabbix_agentd|compression=no,allow_other'

# rotate file if it is bigger than x MB
LOG_ROTATE_SIZE=100
LOG_FILE=/var/log/mem_hunter.log

(echo "$(ps -eo ruser,pid,rss,vsz,pcpu,tty,args | grep -v grep | grep -e COMMAND ) - $(date +%Y.%m.%d_%H:%M%S)"
ps -eo ruser,pid,rss,vsz,pcpu,tty,args | grep -v grep | grep -E "$PATTERN" ) >> $LOG_FILE

# Check if file exists and is older than LOG_ROTATE_DAY
if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE")" -gt $(($LOG_ROTATE_SIZE*1024*1024)) ]; then
    test -f "${LOG_FILE}.old" && rm -fv "${LOG_FILE}.old"
    mv -v "$LOG_FILE" "${LOG_FILE}.old"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

