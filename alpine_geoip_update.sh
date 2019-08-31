#!/bin/sh
# DESC: INSTALL AND UPDATE GEOIP WITH XTABLES IN ALPINE LINUX

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

apk add perl-net-cidr-lite xtables-addons perl perl-doc perl-text-csv_xs unzip

cd /tmp
rm -rf /tmp/GeoLite*
/usr/libexec/xtables-addons/xt_geoip_dl
cd /tmp/GeoLite*
/usr/libexec/xtables-addons/xt_geoip_build
rm -f *.csv *.txt
mkdir /usr/share/xt_geoip/
mv *.iv* /usr/share/xt_geoip/
cd /tmp
rm -rf /tmp/GeoLite*

