#!/bin/sh
#########################################################################################
# DESC: INSTALL AND UPDATE GEOIP WITH XTABLES IN ALPINE LINUX
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
URL=https://mailfud.org/geoip-legacy/GeoIP-legacy.csv.gz
DBDIR=/usr/share/GeoIP

echo "INFO: ensure packages are installed"
apk add perl-net-cidr-lite xtables-addons perl perl-doc perl-text-csv_xs unzip

test -d $DBDIR || mkdir -p $DBDIR
cd $DBDIR || exit 1
rm -f GeoIP-legacy.*

wget -q $URL
if [ "$?" -ne 0 ]
then
   >&2 echo "ERROR: could not download $URL"
   exit 1
else
   echo "INFO: downloaded $URL"
fi

gunzip GeoIP-legacy.csv.gz
cat $DBDIR/GeoIP-legacy.csv | cut -d, -f1,2,5 > $DBDIR/dbip-country-lite.csv
rm -f $DBDIR/GeoIP-legacy.*

/usr/libexec/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip $DBDIR/GeoIP-legacy.csv | grep -q 'ranges for ZW'
if [ "$?" -ne 0 ]
then
   >&2 echo "ERROR: failed to build GeoIP database files in /usr/share/xt_geoip"
   exit 1
else
   echo "INFO: Finished building xt_geoip database files"
   cd $DBDIR
   rm -f *.csv *.txt *.gz
fi

