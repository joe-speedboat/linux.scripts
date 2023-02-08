#!/bin/bash
#########################################################################################
# DESC: do some sysbench tests to get a performance fingerprint
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#---------- GLOBAL VARS --------------------------------------------------
export LANG="en_US.UTF-8"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TOP_PID=$$
RESULT_FILE=$HOME/benchmark.log

#---------- FUNCTIONS --------------------------------------------------
# log handling
log(){
   LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   [ $# -lt 1 ] && STDIN="$((echo ; cat /dev/stdin) | sed '2,$ s/^/          /')"
   if [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] ; then
      echo "$LEVEL: $* $STDIN"
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(hostname -s):$LEVEL: $* $STDIN" >> $RESULT_FILE
      logger -t $(basename $0) "$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" ]
   then
      kill $TOP_PID
      kill -9 $TOP_PID
   fi
}
# check for missing tools
# ---------------------------------------------------------
for p in sysbench
do
  which $p >/dev/null 2>&1 || (log error $p is missing )
done

# ---------- MAIN PROGRAM ---------------------------------
log info BENCHMARK STARTED ------------------------------------------
log info CPU BENCHMARK - higher is better ---------------------------
sysbench cpu --cpu-max-prime=100000 --num-threads=1 run | grep 'events per second:' | log info

log info THREAD SCHEDULING BENCHMARK - higher is better ---
sysbench threads --threads=64 --thread-yields=100 --thread-locks=2 run | grep 'total number of events:' | log info

log info MUTEX BENCHMARK - lower is better --------------------------
sysbench mutex --mutex-num=100000 --mutex-locks=100000 --mutex-loops=100000 run | grep 'total time:' | log info

log info MEMORY BENCHMARK - higher is better ------------------------
sysbench memory --memory-block-size=1K --memory-total-size=100G --num-threads=1 run | sed '/ transferred /!d;s/.* transferred /Bandwith: /;s/[\(\)]//g' | log info

log info FILE-IO BENCHMARK - higher is better -----------------------
FIO='sysbench fileio --file-fsync-all --num-threads=16 --file-total-size=3G --file-test-mode=rndrw'
cd /
$FIO prepare >/dev/null
$FIO run | awk '/File operations:/,/General statistics:/' | head -n -2 | log info
$FIO cleanup >/dev/null
log info BENCHMARK FINISHED -----------------------------------------

