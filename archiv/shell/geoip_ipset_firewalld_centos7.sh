#!/bin/bash
#########################################################################################
# DESC: geoip fence for firewalld with ipsets
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

COUNTRIES='ch de li at it fr'
LOCAL_SN='10.0.0.0/8 172.16.0.0/12 192.168.0.0/16'

IP_LIST='whitelist'
URL='https://www.ipdeny.com/ipblocks/data/aggregated'

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
TMP=/var/tmp/ipblocks
rm -rf $TMP
mkdir -p $TMP
cd $TMP


echo "INFO: prepare $IP_LIST ipset"
ipset destroy $IP_LIST 2>/dev/null
firewall-cmd --permanent --delete-ipset=$IP_LIST 2>/dev/null 
firewall-cmd --permanent --new-ipset=$IP_LIST --type=hash:net
firewall-cmd --permanent --get-ipsets | grep -q $IP_LIST || exit 1

for cc in $COUNTRIES
do
  echo "   INFO: Download $URL/$cc-aggregated.zone and add to ipset $IP_LIST"
  wget -q "$URL/$cc-aggregated.zone" -O - >> $TMP/all.txt
  if [ $? -eq 0 ]
  then
    echo "   INFO: Downloaded $URL/$cc-aggregated.zone and add to ipset $IP_LIST"
  else
    echo "   ERROR: Download $URL/$cc-aggregated.zone failed"
    exit 1
  fi
done

echo "INFO: read collection file into $IP_LIST ipset"
firewall-cmd --permanent --ipset=$IP_LIST --add-entries-from-file=$TMP/all.txt

for sn in $LOCAL_SN
do
   echo "INFO: add subnet $sn to $IP_LIST ipset"
   firewall-cmd --permanent --ipset=$IP_LIST --add-entry=$sn
done

LCOUNT="$(firewall-cmd --permanent --info-ipset=$IP_LIST | grep entries | wc -c)"
if [ $LCOUNT -gt 3 ]
then
   echo "INFO: IPSet $IP_LIST updated with $LCOUNT entries"
   logger -p cron.notice "INFO: IPSet $IP_LIST updated with $LCOUNT entries"
else
    echo "   ERROR: IPSet $IP_LIST has only $LCOUNT entries"
    exit 1
fi


# echo "INFO: configure firewalld on you needs firewalld"
# firewall-cmd --permanent --add-rich-rule='rule source ipset=$IP_LIST port port=22 protocol=tcp accept'
firewall-cmd --reload

exit 0

