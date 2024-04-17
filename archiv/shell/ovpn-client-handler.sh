#!/bin/bash
###############################################################################################################
# DESC: tool to manage openvpn connections with menu
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

VPN_CONF="/etc/openvpn"
VPN_LOG="/tmp/ovpn"
VPN_SUFF="conf"

while true
do 
   # ---------- PRINT MENU ----------
   clear
   echo
   echo "WHICH VPN DO YOU WANT TO MANAGE?"
   echo "--------------------------------"
   echo
   VPNS="$(ls -1 $VPN_CONF/*.$VPN_SUFF)"
   for NR in $( seq $(echo $VPNS | wc -w ))
   do
      VPNID=$(echo  $VPNS | cut -d' ' -f$NR | sed "s#$VPN_CONF/##g;s#.$VPN_SUFF##g")
      VPNID_STAT=$(pgrep -f  ".*openvpn .*$VPNID.*" >/dev/null 2>&1 && echo U || echo D)
      echo -n "   " ; echo -n "$NR) " ; echo  "$VPNID_STAT: $VPNID "
      NR=$(( $NR + 1 ))
   done
   echo
   echo "   k) STOP ALL"
   echo "   x) EXIT"
   echo
   read -p "Please select: " ACTION
   
   # ---------- EXECUTE INPUT ----------   
   if [ "$ACTION" = "x" ] # ---------- EXIT
   then
      exit 0
   elif [ "$ACTION" = "k" ] # ---------- STOP ALL VPNS
   then
      echo "exec: stop all vpns"
      sudo killall -TERM openvpn
      sleep 2
   else # ---------- TOOGLE VPN
      echo "$ACTION" | grep -q [0123456789] || exit 1
      VPNID=$(echo  $VPNS | cut -d' ' -f$ACTION | sed "s#$VPN_CONF/##g;s#.$VPN_SUFF##g")
      VPNID_STAT=$(pgrep -f  ".*openvpn .*$VPNID.*" >/dev/null 2>&1 && echo U || echo D)
      # echo VPNID=$VPNID VPNID_STAT=$VPNID_STAT
      if [ "$VPNID_STAT" = "U" ]
      then
         sudo pkill -TERM -f "openvpn .*$VPNID.*"
         sleep 0.1
         sudo pkill -TERM -f "openvpn .*$VPNID.*"
         sleep 1
      else
         echo "exec: start vpn $VPNID"
         sudo bash -c "date  > $VPN_LOG.$VPNID.log"
         sleep 1
         (tail -f $VPN_LOG.$VPNID.log | while read line ; do echo $line | grep -q 'Initialization Sequence Completed' && sleep 1 && sudo tmux detach -s $VPNID && break ; done) &
         clear
         sudo tmux new -s $VPNID bash -c "openvpn $VPN_CONF/$VPNID.$VPN_SUFF | tee -a $VPN_LOG.$VPNID.log"
         pkill -TERM -f "tail -f .*$VPNID.log"
         sleep 1
         clear
      fi
   fi
done

exit

################################################################################
