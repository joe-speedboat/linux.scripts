#!/bin/bash
#########################################################################################
# DESC: update geoip database for sheduled usage with cron
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
URL=https://mailfud.org/geoip-legacy/GeoIP.dat.gz
DST=/srv/geoip/GeoIP.dat

test -d $(dirname $DST)/tmp || mkdir -p $(dirname $DST)/tmp
cd $(dirname $DST)/tmp || exit 1
rm -f *.dat*
wget -q "$URL"
file $(echo "$URL" | rev | cut -d/ -f1 | rev)  | grep -q 'gzip compressed data'
gunzip $(echo "$URL" | rev | cut -d/ -f1 | rev)
strings $(echo "$URL" | rev | cut -d/ -f1 | rev | cut -d. -f-2) | tail -20 | grep -qi geolite
if [ $? -ne 0 ]
then
   echo "Error, could not download $URL"
   exit 1
else
   true
   # echo "INFO: verified geoip file file :-)"
fi
mv -f $(echo "$URL" | rev | cut -d/ -f1 | rev | cut -d. -f-2) $DST
systemctl restart nginx

