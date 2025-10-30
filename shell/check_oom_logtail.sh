#!/usr/bin/env bash
set -euo pipefail

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# INSTALL:
# copy to /usr/local/sbin/check_oom_logtail.sh
# chmod 700 /usr/local/sbin/check_oom_logtail.sh
# vi /usr/local/sbin/check_oom_logtail.sh # change the vars below (mail, logfile)
# crontab -e -u root #run every 10min
# */10 * * * * /usr/local/sbin/check_oom_logtail.sh

# MANUAL TEST
# echo ""Out of memory: test event, ignore me" >> $LOGFILE

# CONFIG
LOGFILE="/var/log/messages"               # change to file where OOM event is logged into
STATEFILE="${LOGFILE}.logtail"
MAIL_TO="support@domain.tld"
MAIL_FROM="system@domain.tld"
SUBJ="OOM detected on $(hostname -f)"

# BINARIES (fail early if missing)
for bin in s-nail dd stat grep hostname date; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is missing, install first"
    exit 0
  fi
done

# logfile present/readable?
if [[ ! -r "$LOGFILE" ]]; then
  echo "ERROR: logfile not readable: $LOGFILE"
  exit 0
fi

mkdir -p "$(dirname "$STATEFILE")"

# current size of logfile
CURLEN=$(stat -c %s "$LOGFILE")

# last position we read
if [[ -f "$STATEFILE" ]]; then
  LASTPOS=$(cat "$STATEFILE" 2>/dev/null || echo 0)
else
  LASTPOS=0
fi

# if log rotated (smaller now) -> start from 0
if (( CURLEN < LASTPOS )); then
  LASTPOS=0
fi

# read new part
NEWLOG=$(dd if="$LOGFILE" bs=1 skip="$LASTPOS" 2>/dev/null | cat)

# update position for next run
echo "$CURLEN" > "$STATEFILE"

# no new data → done
if [[ -z "$NEWLOG" ]]; then
  exit 0
fi

# search for OOM signatures
OOM_LINES=$(grep -E "Out of memory:|Killed process [0-9]+ .* due to OOM" <<<"$NEWLOG" || true)

if [[ -n "$OOM_LINES" ]]; then
  {
    echo "Out Of Memory event occured, please reboot this host soon or fix oom problem"
    echo 
    echo "Host: $(hostname -f)"
    echo "Time: $(date -Is)"
    echo
    echo "$OOM_LINES"
  } | s-nail -r "$MAIL_FROM" -s "$SUBJ" "$MAIL_TO"
fi

