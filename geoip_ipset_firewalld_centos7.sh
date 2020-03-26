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

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
TMP=/var/tmp/ipblocks
rm -rf $TMP
mkdir -p $TMP
cd $TMP

echo "INFO: download country ipset lists"
wget -q http://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz 1> /dev/null 2> /dev/null
tar zxf $TMP/all-zones.tar.gz

echo "INFO: prepare whitelist ipset"
ipset destroy whitelist 2>/dev/null
firewall-cmd --permanent --delete-ipset=whitelist 2>/dev/null 
firewall-cmd --permanent --new-ipset=whitelist --type=hash:net
firewall-cmd --permanent --get-ipsets | grep -q whitelist || exit 1

echo "INFO: add countries to whitelist ipset collection file"
for file in ch.* de.* li.* at.* it.* fr.*
do
 ls $file
 cat $file >> $TMP/all.txt
done

echo "INFO: read collection file into whitelist ipset"
firewall-cmd --permanent --ipset=whitelist --add-entries-from-file=$TMP/all.txt

for sn in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
do
   echo "INFO: add subnet $sn to whitelist ipset"
   firewall-cmd --permanent --ipset=whitelist --add-entry=$sn
done

echo "WHITELIST IPSET ENTRIES: $(firewall-cmd --permanent --info-ipset=whitelist | grep entries | wc -c)"


echo "INFO: drop everything that is not whitelisted with firewalld"
firewall-cmd --reload
logger -p cron.notice "IPSet whitelist updated."
firewall-cmd --permanent --add-rich-rule='rule source not ipset=whitelist drop' 2>&1 | grep -iv warning
firewall-cmd --reload

exit 0

