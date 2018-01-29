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

test -d /srv/geoip || mkdir -p /srv/geoip
cd /srv/geoip

rm -f GeoLite2-City.*
rm -f GeoLite2-Country.*
wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz
wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz
gunzip GeoLite2-City.mmdb.gz
gunzip GeoLite2-Country.mmdb.gz

strings /srv/geoip/GeoLite2-City.mmdb | tail -20 | grep -q GeoLite || exit 1
strings /srv/geoip/GeoLite2-Country.mmdb | tail -20 | grep -q GeoLite || exit 1
exit 0

