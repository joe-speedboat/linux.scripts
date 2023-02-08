#!/bin/bash
# DESC: Get Bind DNS zone by AXFR and sync CNAME and A records into AD
# $Author: chris $
# $Revision: 1.1 $
# $RCSfile: sync-dns-bind-to-ad.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

WUSER=Administrator
WPASS='LetMeIn'
DOMAIN="windom.local"
TMPF=/tmp/$(basename $0)
DEBUG=0
> $TMPF.ad ; chmod 600 $TMPF.ad
> $TMPF.lin ; chmod 600 $TMPF.lin


########## FUNKTIONEN ##########################################################################

get_ad_dns(){
   ((samba-tool dns query localhost $DOMAIN @ ALL -U $WUSER --password="$WPASS" ; echo Name= )| while read LINE
   do
      echo $LINE | grep -q Name=
      if [ $? -eq 0 ]
      then
         echo $LINES | egrep '\sChildren=0\sA:\s' | awk '{print $1":A:"$5}' | sed "s/,//g;s/Name=//g;s/.$DOMAIN.//g"
         echo $LINES | egrep '\sChildren=0\sCNAME:\s' | awk '{print $1":CNAME:"$5}' | sed "s/,//g;s/Name=//g"
         LINES="$LINE"
      else
         LINES="$LINES $LINE"
      fi
   done ) | while read REC
   do
      NAME=$(echo $REC | cut -d: -f1)
      TYPE=$(echo $REC | cut -d: -f2)
      WERT=$(echo $REC | cut -d: -f3)
      echo $NAME:$TYPE:$WERT
   done
}

get_lin_dns(){
   dig $DOMAIN -t AXFR | egrep -v '^$|^;' | egrep '\sIN\sA\s|\sIN\sCNAME\s' | awk '{print $1 ":" $4 ":"$5 }' |sed "s/.$DOMAIN.//g"| while read REC
   do
      NAME=$(echo $REC | cut -d: -f1)
      TYPE=$(echo $REC | cut -d: -f2)
      WERT=$(echo $REC | cut -d: -f3)
      [ "$TYPE" == "CNAME" ] && WERT="$WERT.$DOMAIN."
      echo "$NAME:$TYPE:$WERT" >> $TMPF.lin
   done
}

add_wdns(){
   NAME=$1
   TYPE=$2
   WERT=$3
   log debug samba-tool dns add localhost $DOMAIN $NAME $TYPE $WERT
   samba-tool dns add localhost $DOMAIN -U $WUSER --password="$WPASS" $NAME $TYPE $WERT || exit 1
}

del_wdns(){
   NAME=$1
   grep "^$NAME:" $TMPF.ad | while read LINE
   do
      TYPE=$(echo $LINE | cut -d: -f2)
      WERT=$(echo $LINE | cut -d: -f3)
      log debug samba-tool dns delete localhost $DOMAIN $NAME $TYPE $WERT
      samba-tool dns delete localhost $DOMAIN -U $WUSER --password="$WPASS" $NAME $TYPE $WERT || exit 1
   done
}

log(){
   [ "$1" = "err" ] && LEVEL=ERROR
   [ "$1" = "warn" ] && LEVEL=WARNING
   [ "$1" = "info" ]&& LEVEL=INFO
   [ "$1" = "debug" ]&& LEVEL=DEBUG
   shift
   [ "$LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] && echo "$LEVEL: $*"
   [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] && echo "$LEVEL: $*"
   logger -t $(basename $0) "$LEVEL: $*"
   if [ "$LEVEL" = "ERROR" ]
   then
      kill -s TERM $$
      kill -s KILL $$
   fi
}


########## HAUPT PROGRAM #######################################################################

log debug get_ad_dns
get_ad_dns > $TMPF.ad
[ $(cat $TMPF.ad | wc -l) -lt 300 ] && log err $TMPF.ad hat weniger als 300 einträge

log debug get_lin_dns
get_lin_dns > $TMPF.lin
[ $(cat $TMPF.lin | wc -l) -lt 300 ] && log err $TMPF.lin hat weniger als 300 einträge

cat $TMPF.lin | while read REC
do
   NAME=$(echo $REC | cut -d: -f1)
   TYPE=$(echo $REC | cut -d: -f2)
   WERT=$(echo $REC | cut -d: -f3)
   grep -q "^$NAME:$TYPE:$WERT$" $TMPF.ad 
   if [ $? -ne 0 ] # wenn eintrag im ad fehlt, tue etwas
   then
      grep -q "^$NAME:" $TMPF.ad
      if [ $? -eq 0 ] # wenn eintrag nicht vorhanden, aber name, dann löschen
      then
         log info del_wdns $NAME
         del_wdns $NAME
      fi
      log info add_wdns $NAME $TYPE $WERT
      add_wdns $NAME $TYPE $WERT
   else
      log debug Linux DNS $NAME $TYPE $WERT ist synchron
   fi
done

log debug get_ad_dns again, it is probaly not recent anymore
get_ad_dns > $TMPF.ad
[ $(cat $TMPF.ad | wc -l) -lt 300 ] && log err $TMPF.ad hat weniger als 300 einträge

cat $TMPF.ad | while read REC
do
   NAME=$(echo $REC | cut -d: -f1)
   TYPE=$(echo $REC | cut -d: -f2)
   WERT=$(echo $REC | cut -d: -f3)
   grep -q "^$NAME:$TYPE:$WERT$" $TMPF.lin
   if [ $? -ne 0 ] # wenn eintrag im linux fehlt, lösche im ad
   then
      log info del_wdns $NAME
      del_wdns $NAME
   else
      log debug Windows DNS $NAME $TYPE $WERT ist synchron
   fi
done


################################################################################
# $Log: sync-dns-bind-to-ad.sh,v $
# Revision 1.1  2016/04/27 06:12:28  chris
# Initial revision
#

