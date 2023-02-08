#!/bin/bash
# DESC: script to monitor cpu consumation
# $Revision: 1.2 $
# $RCSfile: pmon.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# comment: victims='rmi_auth rmi_poet ora_'
# hint:  while true; do sh pmon.sh; sleep 1; done

col_max=20
logf=./`basename $0`.log
victims='pdflash skype'
cur_date=`date '+%Y.%m.%d %H:%M'`
sys_load=$(cat /proc/loadavg | cut -d\  -f3)
cols="cur_date sys_load $victims"
# header output
if [ ! -f $logf ]; then 
  for col in $cols; do
    i=$[$col_max-$(echo "$col" | wc -c)]
    space=""
    while [ $i -gt 0 ]; do
      space="$space "
      i=$[$i-1]
    done
    echo -n "$col $space" >> $logf
  done
  echo "" >> $logf
fi

# get data
for victim in $victims; do
  eval $victim=0
  for ccpu in `ps -eo pcpu,cmd | grep -v grep | grep -i "$victim" | awk '{print $1}'`; do
    eval $victim=`echo "${!victim} + $ccpu" | bc`
  done
#  echo $victim, $ccpu
done
#echo sys_load $sys_load 

# data output
for col in $cols; do
  i=$[$col_max-$(echo "${!col}" | wc -c)]
  space=""
  while [ $i -gt 0 ]; do
    space="$space "
    i=$[$i-1]
  done
  echo -n "${!col} $space" >> $logf
done
echo "" >> $logf

