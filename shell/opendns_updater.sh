#!/bin/sh
# DESC: script to change dyn IP at openvpn.com
# $Revision: 1.2 $
# $RCSfile: opendns_updater.sh,v $
# $Author: chris $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# OpenWRT: opkg update ; opkt install wget ca-certificates
#           vi /etc/config/opendns_updater.sh #put script here
#           chmod 700 /etc/config/opendns_updater.sh
#           crontab -e  #put: */10 * * * * /etc/config/opendns_updater.sh
#           /etc/init.d/cron enable ; /etc/init.d/cron restart

PATH=/sbin:/bin:/usr/sbin:/usr/bin
#------------------ MyVariables -------------------------------------
USR=user@domain.com
PW=secret123
NETW=MyNetworkName
#------------------------------------------------------------------
URL="https://updates.opendns.com/nic/update?hostname=$NETW"
IPF=/tmp/odns.ip

test -f $IPF || touch $IPF
LASTIP=`cat $IPF`
CURRENTIP=`wget -q -O - ip.changeip.com | grep ^[0-9]`

# compare
if [ "$CURRENTIP" != "$LASTIP" ]
then
   logger -t `basename $0` "LASTIP=$LASTIP CURRENTIP=$CURRENTIP, update it now"
   wget -nv --http-user="$USR" --http-password="$PW" -O - "$URL" 2>&1 | grep -q good
   if [ $? -eq 0 ]
   then                                                                    
      logger -t `basename $0` "update successful"                          
      echo "$CURRENTIP" > $IPF                                     
   else                                                                                                                     
      logger -t `basename $0` "update failed, try exec: wget -nv --http-user=\"$USR\" --http-password=\"$PW\" -O - \"$URL\""
   fi                                                                           
else                                                                            
   logger -t `basename $0` "LASTIP=$LASTIP CURRENTIP=$CURRENTIP, do noting"     
fi                                                                              
                                                                                
                                                                                
################################################################################
# $Log: opendns_updater.sh,v $
# Revision 1.2  2015/08/29 08:16:50  chris
# cleanup vars
#
# Revision 1.1  2015/08/29 06:00:30  chris
# Initial revision
#

