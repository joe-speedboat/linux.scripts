#! /bin/bash
##############################################################################################################
# DESC: zabbix cert checker, found on internet and modified to work with the official docker images
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
sni=$4
proto=$5

if [ -z "$sni" ]
then
    servername=$host
else
    servername=$sni
fi

if [ -n "$proto" ]
then
    starttls="-starttls $proto"
fi

if [ "x$port" == "x" ]
then
    port=443
fi



case $f in
-d)
#end_date=`openssl s_client -servername $servername -host $host -port $port -showcerts $starttls -prexit </dev/null 2>/dev/null |
end_date=`openssl s_client -servername $servername -host $servername -port $port -showcerts $starttls -prexit </dev/null 2>/dev/null |
          sed -n '/BEGIN CERTIFICATE/,/END CERT/p' 2>/dev/null|
          openssl x509 -text 2>/dev/null |
          sed -n 's/ *Not After : *//p' 2>/dev/null| 
          sed 's/ [A-Z][A-Z][A-Z]$//' 2>/dev/null`

if [ -n "$end_date" ]
then
    end_date_seconds=`date '+%s' --date "$end_date"`
    now_seconds=`date '+%s'`
    echo "($end_date_seconds-$now_seconds)/24/3600" | bc
fi
;;

-i)
issue_dn=`openssl s_client -servername $servername -host $host -port $port -showcerts $starttls -prexit </dev/null 2>/dev/null |
          sed -n '/BEGIN CERTIFICATE/,/END CERT/p' 2>/dev/null|
          openssl x509 -text 2>/dev/null |
          sed -n 's/ *Issuer: *//p' 2>/dev/null`

if [ -n "$issue_dn" ]
then
    issuer=`echo $issue_dn | sed -n 's/.*CN=*//p' 2>/dev/null`
    echo $issuer
fi
;;
*)
echo "usage: $0 [-i|-d] hostname port sni"
echo "    -i Show Issuer"
echo "    -d Show valid days remaining"
;;
esac
