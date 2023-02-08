#!/bin/sh
#########################################################################################
# DESC: check some hosts by ping and send sms notification if they change status
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# HOWTO SETUP ###########################################################################
# - download this script and make it executeable
# - fill in the HOSTS var with hosts to check by ping
# - make sure aspsms.sh is in PATH, configured and executeable
# - register cron job in OpenWrt:
#     /etc/init.d/cron enable
#     /etc/init.d/cron restart
#     crontab -e
#        */5 * * * * /etc/config/bin/checkhost.sh

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/etc/config/bin
export PATH

HOSTS='pesx-01:10.0.0.31 pesx-02:10.0.0.32 fw-01:10.0.100.1 uplink_to_google:8.8.8.8'

MOBILES='+41782223344 +41791112233'

for HOST in $HOSTS
do
  IP=`echo $HOST | cut -d: -f2`
  NAME=`echo $HOST | cut -d: -f1`
  ping -c1 -w5 $IP >/dev/null 2>&1 || ( sleep 120 && ping -c1 -w5 $IP >/dev/null 2>&1 )
  if [ $? -ne 0 ]
  then
    test -f /tmp/$NAME.fail
    if [ $? -ne 0 ]
    then  
      touch /tmp/$NAME.fail
      for MOBILE in $MOBILES
      do    
         aspsms.sh $MOBILE "$NAME is down"
      done
    fi
  else
    test -f /tmp/$NAME.fail
    if [ $? -eq 0 ]
    then
      rm -f /tmp/$NAME.fail
      for MOBILE in $MOBILES
      do
         aspsms.sh $MOBILE "$NAME is online"
      done
    fi
  fi
done

