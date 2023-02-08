#!/bin/bash
# DESC: control gnome screensaver by distance to bluetooth device (phone)
# $Revision: 1.4 $
# $RCSfile: btsaver.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# set suid bit for needed tools first
# chmod +s /usr/bin/hcitool
# chmod +s /usr/bin/l2ping

DEBUG=0

# mac of your phone
DEVICE="00:23:12:E5:3E:17"

# how often check to check the distance
CHECK_INTERVAL=2

# the rssi threshold at which a phone is considered far or near
THRESHOLD=-15
rssi=-99

# the command to run when your phone gets too far away
FAR_CMD='/usr/bin/gnome-screensaver-command --activate'

# the command to run when your phone is close again
NEAR_CMD='/usr/bin/gnome-screensaver-command --poke'

HCITOOL="/usr/bin/hcitool"

function db {
   [ $DEBUG -eq 1 ] && echo $*
}

function get_distance {
   rssi=$( $HCITOOL rssi $DEVICE | sed -e 's/RSSI return value: //g' )
   if [ $rssi -le $THRESHOLD ] ; then
      sleep $(($CHECK_INTERVAL/2)).5 && db -n .
      rssi=$( $HCITOOL rssi $DEVICE | sed -e 's/RSSI return value: //g' )
      if [ $rssi -le $THRESHOLD ] ; then
         sleep $(($CHECK_INTERVAL/2)).5 && db -n .
         rssi=$( $HCITOOL rssi $DEVICE | sed -e 's/RSSI return value: //g' )
         if [ $rssi -le $THRESHOLD ] ; then
            sleep $(($CHECK_INTERVAL/2)).5 && db -n .
            rssi=$( $HCITOOL rssi $DEVICE | sed -e 's/RSSI return value: //g' )
         fi
      fi
   fi
}

while true ; do
   get_distance
   if [ $rssi -le $THRESHOLD ] ; then
      $FAR_CMD
      db device is too far away, rssi=$rssi : FAR_CMD executed
   else
      $NEAR_CMD
      db device is close, rssi=$rssi : NEAR_CMD executed
   fi
   sleep $CHECK_INTERVAL
done
   
################################################################################
# $Log: btsaver.sh,v $
# Revision 1.4  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.3  2010/06/07 21:42:00  chris
# deleting ping crap
#
# Revision 1.2  2010/06/07 18:47:43  chris
# minor bugfixing
#
# Revision 1.1  2010/06/07 18:33:41  chris
# Initial revision
#

