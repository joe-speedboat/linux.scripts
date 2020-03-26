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

wget -q http://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz 1> /dev/null 2> /dev/null
tar zxf $TMP/all-zones.tar.gz

ipset destroy whitelist
firewall-cmd --permanent --delete-ipset=whitelist 2>/dev/null 
firewall-cmd --permanent --new-ipset=whitelist --type=hash:net
firewall-cmd --permanent --get-ipsets | grep -q whitelist || exit 1

for file in ch.* de.* li.* at.* it.* fr.*
do
 ls $file
 cat $file >> $TMP/all.txt
done

firewall-cmd --permanent --ipset=whitelist --add-entries-from-file=$TMP/all.txt
echo "ENTRIES: $(firewall-cmd --permanent --info-ipset=whitelist | grep entries | wc -c)"

#while read p; do
#   echo "      exec: firewall-cmd --permanent --ipset=whitelist --add-entry=$p"
#   firewall-cmd --permanent --ipset=whitelist --add-entry=$p
#done < $TMP/all.txt

firewall-cmd --reload
logger -p cron.notice "IPSet whitelist updated."
firewall-cmd --permanent --add-rich-rule='rule source not ipset=whitelist drop' 2>&1 | grep -iv warning
firewall-cmd --reload

exit 0

