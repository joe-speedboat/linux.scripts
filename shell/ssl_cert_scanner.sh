#! /bin/bash
##############################################################################################################
# DESC: scan certs for issuer and EOL, write results to csv
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# write results to
CSV=$HOME/"$(date '+%Y%m%d%H%M' )_ssl_cert_scanner.csv"

# ports to try
PORTS="443 50443 8443"

WAIT_SEC=1

IP_RANGES='
10.0.91.5
www.domain.local
share.domain.local
10.0.{91,2,12}.{1..254}
'

echo "IP,PORT,DNS,ISSUER,SUBJECT,START,EXPIRE,DAYS" | tee -a $CSV
for range in $IP_RANGES
do 
   bash -c "echo $range" | tr ' ' '\n' | while read host
   do
      for port in $PORTS
      do
         line=$(curl -kvv --max-time $WAIT_SEC https://$host:$port 2>&1 | cat -v | egrep 'issuer:|expire date:|start date:|subject:' | sed 's/.*: //' | tr -d ',' | tr '\n' ',')
         issuer=$(echo $line | cut -d, -f4 | sed 's/.*O=/O=/' | cut -d';' -f1 | tr -d ';')
         subject=$(echo $line | cut -d, -f1 | tr -d ';' | sed 's/.*CN=/CN=/' | cut -d' ' -f1)
         start=$(echo $line | cut -d, -f2)
         expire=$(echo $line | cut -d, -f3)
         end_date_seconds=`date '+%s' --date "$expire"`
         now_seconds=`date '+%s'`
         end_days=$(echo "($end_date_seconds-$now_seconds)/24/3600" | bc)
         echo $host | egrep -q '[a-zA-Z]'
         if [ $? -eq 0 ] ; then
            dns=$host
            ip=$(host $dns | grep 'has address' | head -1 | sed 's/.* //' | grep '\.')
         else
           dns=$(host $host | head -1 | sed 's/.* //' | grep '\.')
           ip=$host
         fi
         if [ "x$expire" != "x" ] ; then
            echo $ip,$port,$dns,$issuer,$subject,$start,$expire,$end_days | tee -a $CSV
         fi
      done
   done
done 

