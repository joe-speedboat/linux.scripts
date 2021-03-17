#! /bin/bash
##############################################################################################################
# DESC: zabbix cert checker, rewritten due my needs
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export LANG=


DEBUG=0
if [ $DEBUG -gt 0 ]
then
    exec 2>>/tmp/my.log
    set -x
fi

f=$1
host=$2
port=$3

if [ "x$port" == "x" ]
then
    port=443
fi

line=$(curl -kvv --max-time 5 https://$host:$port 2>&1 | egrep 'issuer:|expire date:|start date:|subject:' | sed 's/.*: //' | tr -d ',' | tr '\n' ',')
issuer=$(echo $line | cut -d, -f4 | tr -d ';')
subject=$(echo $line | cut -d, -f1 | tr -d ';' | sed 's/.*CN=/CN=/')
start=$(echo $line | cut -d, -f2)
expire=$(echo $line | cut -d, -f3)
end_date_seconds=`date '+%s' --date "$expire"`
now_seconds=`date '+%s'`
end_days=$(echo "($end_date_seconds-$now_seconds)/24/3600" | bc)

case $f in
-d)
  echo $end_days
;;

-i)
  echo $issuer
;;

-s)
  echo $subject
;;



*)
echo "usage: $0 [-i|-d|-s] hostname [port|default(443)]"
echo "    -s Show Subject"
echo "    -i Show Issuer"
echo "    -d Show valid days remaining"
;;
esac
