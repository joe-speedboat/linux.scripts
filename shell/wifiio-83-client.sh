#!/bin/bash 
#########################################################################################
# DESC: WIFIIO-83 ethernet relais and input sensor comandline interface
# $Revision: 1.2 $
# $RCSfile: wifiio-83-client.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

WURL="http://192.168.1.251/httpapi.json?&CMD=UART_WRITE&UWHEXVAL="
WUSER='admin'
WPASS='s0lar1'
WCMD="wget -T 3 -t 2 -q -O - --user=$WUSER --password=$WPASS $WURL"
SLEEP=0.2

dohelp(){ #-------------------------------------------------
   echo "
   Usage: $(basename $0)
           -i {1-3}       Query Input Channel
           -e {1-8}       Enable Output Channel
           -d {1-8}       Disable Output Channel
           -t {1-8}       Toggle Output Channel
           -q             Query all Channels
           -h|--help      Show this help

           eg: $(basename $0) -t 1
   "
exit 0
}

doexit(){ #-----------------------------------------------
RC=$1
shift
MSG="$*"
if [ $RC -ne 0 ]
then
  >&2 echo "ERROR:$RC: $MSG"
  exit 1
else
   exit 0
fi
}

doenable(){ #-----------------------------------------------
   CHANNEL=$1
   echo $CHANNEL | egrep -q '^[1-8]$' || dohelp
   DSTATE=`${WCMD}0 || doexit 1 wget error` 
   echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
   BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
   CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
   if [ $CSTATE -ne 1 ]
   then
     sleep $SLEEP
     unset CSTATE
     DSTATE=`${WCMD}$CHANNEL || doexit 1 wget error`
     echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
     BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
     CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
   fi
   if [ $CSTATE -ne 1 ]
   then
     echo "ERROR: Output Channel $CHANNEL is not enabled or query failed"
     exit 1
   else
      echo "OK:1: Output Channel $CHANNEL is enabled"
   fi
}

dodisable(){ #-----------------------------------------------
   CHANNEL=$1
   echo $CHANNEL | egrep -q '^[1-8]$' || dohelp
   DSTATE=`${WCMD}0 || doexit 1 wget error`
   echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
   BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
   CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
   if [ $CSTATE -ne 0 ]
   then
     sleep $SLEEP
     unset CSTATE
     DSTATE=`${WCMD}$CHANNEL || doexit 1 wget error`
     echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
     BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
     CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
   fi
   if [ $CSTATE -ne 0 ]
   then
     echo "ERROR:9: Output Channel $CHANNEL is not disabled or query failed"
     exit 1
   else
      echo "OK:0: Output Channel $CHANNEL is disabled"
   fi
}

dotoggle(){ #-----------------------------------------------
   CHANNEL=$1
   echo $CHANNEL | egrep -q '^[1-8]$' || dohelp
   DSTATE=`${WCMD}$CHANNEL || doexit 1 wget error`
   echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
   BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
   CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
   if [ $CSTATE -eq 0 ]
   then
     echo "OK:0: Output Channel $CHANNEL is disabled"
   elif [ $CSTATE -eq 1 ] 
   then
     echo "OK:1: Output Channel $CHANNEL is enabled"
   else
     echo "ERROR:9: Output Channel query failed"
   fi
}

readinput(){ #-----------------------------------------------
   CHANNEL=$1
   echo $CHANNEL | egrep -q '^[1-3]$' || dohelp
   DSTATE=`${WCMD}0 || doexit 1 wget error`
   echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
   BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
   CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c-3 | rev | cut -c$CHANNEL) #current channel state: 1=open 0=closed to ground
   if [ $CSTATE -eq 0 ]
   then
     echo "OK:1: Input Channel $CHANNEL is closed to GND"
   elif [ $CSTATE -eq 1 ]
   then
     echo "OK:0: Input Channel $CHANNEL is open"
   else
     echo "ERROR:9: Input Channel query failed"
   fi
}

readall(){ #-----------------------------------------------
   DSTATE=`${WCMD}0 || doexit 1 wget error`
   echo $DSTATE | egrep -q [0-9] || doexit 1 wifiio result error
   BSTATE=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}) # dec 2 dual conversion
   for CHANNEL in $(seq 1 3) # ------ loop all input channels
   do
      CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c-3 | rev | cut -c$CHANNEL) #current channel state: 1=open 0=closed to ground
      if [ $CSTATE -eq 0 ]
      then
        echo "OK:1: Input Channel $CHANNEL is closed to GND"
      elif [ $CSTATE -eq 1 ]
      then
        echo "OK:0: Input Channel $CHANNEL is open"
      else
        echo "ERROR:9: Input Channel query failed"
      fi
   done
   for CHANNEL in $(seq 1 8) # ------ loop all output channels
   do
      CSTATE=$(echo ${BSTATE[$DSTATE]} | cut -c4- | rev | cut -c$CHANNEL) #current channel state: 0=disabled 1=enabled
      if [ $CSTATE -eq 0 ]
      then
        echo "OK:0: Output Channel $CHANNEL is disabled"
      elif [ $CSTATE -eq 1 ]
      then
        echo "OK:1: Output Channel $CHANNEL is enabled"
      else
        echo "ERROR:9: Output Channel query failed"
      fi
   done

   

}


ARG=$1
case $ARG in
   -i) # query input channel
      shift
      CHANNEL=$1
      readinput $CHANNEL
      ;;
   -e) # enable output channel
      shift
      CHANNEL=$1
      doenable $CHANNEL
      ;;
   -d) # disable output channel
      shift
      CHANNEL=$1
      dodisable $CHANNEL
      ;;
   -t) # toggle output channel
      shift
      CHANNEL=$1
      dotoggle $CHANNEL
      ;;
   -q) # query all channels
      readall
      ;;
   *)
      dohelp
      ;;
esac

doexit 0
################################################################################
# $Log: wifiio-83-client.sh,v $
# Revision 1.2  2016/01/22 20:28:52  chris
# optimized error handling for wget error
#
# Revision 1.1  2016/01/22 13:42:17  chris
# Initial revision
#

