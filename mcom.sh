#!/bin/bash 
#########################################################################################
# DESC: shows hosts and execute comands on all selected hosts
# $Revision: 1.5 $
# $RCSfile: mcom.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

## conf file example:
# www0004;Web Production;JMP=APP;ZONE=APP;APP=MySQL;OS=linux;Note=this_host_can_be_reached_via_jumphost
# root@ora003;DB Production;ZONE=DMZ;APP=Ora11gR2;OS=linux
# admin@jhost;JMPS=APP;Jump Server;APP=MySQL;OS=linux;Note=this_is_the_jumphost

CONF="$0.conf*"
USER=$(whoami)
TERMINAL=$(which gnome-terminal)
KONSOLE=$(which konsole)
SSH='ssh -A -t -X -c blowfish'
OS=$(uname -s)
DEBUG=0
SEARCH="$1"
OPT="$2"
CMD="$3"

debug(){
   if [ $DEBUG == 1 ]
   then
   echo DEBUG: $*
   fi
}

dohelp(){
   debug "help function called"
   echo ""
   echo "usage: $(basename $0) <opts>"
   echo '       PATTERN             search for given string in list of all hosts'
   echo '       PATTERN -l          search for given string in list of all hosts and login to each node'
   echo '       PATTERN -L          search for given string in list of all hosts and select one of them to log in'
   echo '       PATTERN -t          open a new gnome-terminal with each machine as a tab'
   echo '       PATTERN -k          open a new KDE Konsole with each machine as a tab (konsole v2.4+)'
   echo '       PATTERN -H          print all matched hostnames on a single line'
   echo '       PATTERN -e CMD      execute given comand on matched hosts'
   echo '       PATTERN -r CMD      execute given comand as root on matched hosts (by sudo)'
   echo "                           dont use \" or ' here, only \\ is allowed"
   echo '       -c                  configure first config file'
   echo '       -h|--help           this screen'
   echo ""
   exit 0
}

function sgo(){
   JUMP=0 ; JHOST='' ; HOST=$1
   # check if jump host is needed to connect the final destination
   grep -i "^$HOST;" $CONF | grep -q 'JMP='
   if [ $? -eq 0 ]
   then
      JUMP=1
      #get jump host alias
      JHOSTA=$(grep -i "^$HOST;" $CONF | grep 'JMP=' | sed 's/.*;JMP=//g' |cut -d\; -f1)
      #get jump host server name
      JHOSTS=$(grep -i "JMPS=$JHOSTA" $CONF | tail -n1 | cut -d\; -f1 | cut -d: -f2)
      if [ -z "$JHOSTS" ]
      then
         echo ERROR 002: Jump host alias JMPS=$JHOSTA not found in $CONF
         exit 1
      fi
      echo $JHOSTS | grep -q '@'
      if [ $? -ne 0 ]
      then
         JHOSTS="$USER@$JHOSTS"
      fi 
         JHOST="$SSH $JHOSTS"
   fi 
   debug JUMP: $JUMP
   #check if custom username needed
   echo $HOST | grep -q '@'
   if [ $? -ne 0 ]
   then
      HOST="$USER@$HOST"
   fi
   SGO="$JHOST $SSH $HOST"
   debug "sgo function: JUMP=$JUMP HOST=$HOST JHOSTA=$JHOSTA JHOSTS=$JHOSTS"
   debug SGO=$SGO
}

# if there are more than one arguments
# login to all hosts in order
if [ "$OPT" == '-l' ]
then
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2 | cut -d\; -f1)
   do
      sgo $HOST
      $SGO
   done
# chose one host
elif [ "$OPT" == '-L' ]
then
   HOST=( $( grep -i "$SEARCH" $CONF | grep -v '^#' | grep -v '^$' | cut -d\; -f1 ) )
   debug HOST ARRAY: $HOST
   if [ ${#HOST[*]} -lt 1 ]
   then
        echo "oooh, Im soooo sorry, no matches..."
        exit 0
   fi
   echo
   echo "Search: $SEARCH"
   echo
   for NR in $(seq 0 $(( ${#HOST[*]} - 1 )) )
   do
      INDEX=$(($NR + 1)) # index should not start with 0
      echo "   $INDEX) $([ $NR -le 9 ] && echo -n ' ')$( grep "^${HOST[$NR]};" $CONF | grep -v '^#' | grep -v '^$'  | sed 's/;/     ---> /') "
      NR=$(( $NR + 1 ))
   done
   echo
   echo -n "Please select: "
   read SELECT
   echo "$SELECT" | grep -q [0123456789]
   if [ $? -eq 0 ]
   then
      SELECT=$(($SELECT - 1))
      debug sgo function called: sgo ${HOST[$SELECT]}
      sgo ${HOST[$SELECT]}
      $SGO
   fi
   exit 0
#open a gnome terminal with tabs per host
elif [ "$OPT" == '-t' ]
then
   echo $OS | grep -qi darwin && dohelp
   TAB=
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2- | cut -d\; -f1)
   do
      sgo $HOST
      TAB="$TAB --tab -e \"$SGO\" "
   done
   debug "TERMINAL CMD = $TERMINAL $TAB"
   echo $TERMINAL $TAB | bash
   exit 0
#open a KDE terminal with tabs per host
elif [ "$OPT" == '-k' ]
then
   echo $OS | grep -qi darwin && dohelp
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2- | cut -d\; -f1)
   do
      sgo $HOST
      debug "TERMINAL CMD = $KONSOLE --new-tab -e $SGO"
      $KONSOLE --new-tab -e $SGO
   done
   exit 0
# give hostnames to create own comands
elif [ "$OPT" == '-H' ]
then
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2- | cut -d\; -f1 )
   do
      echo -n "$HOST "
   done
   echo 
   exit 0
# execute the comand as root on given hosts
elif [ "$OPT" == '-r' ]
then
   # no way, help here
   echo $CMD | egrep -q '^-' && dohelp
   [ -z "$CMD" ] && dohelp
   echo -e '\033[1;31m press ENTER to run as root \033[0m' ; read
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2- | cut -d\; -f1)
   do
      sgo $HOST
      echo ""
      debug RUN: $SGO sudo sh -c \"\' $CMD \'\" 
      echo "root@$(echo $HOST|cut -d@ -f2): \"$CMD\""
      echo "-------------------------------------------------------"
      if [ $JUMP == 1 ]
      then
         $SGO sudo sh -c \"\' $CMD \'\" 2>&1 
      else
         $SGO sudo sh -c \" $CMD \" 2>&1 
      fi
   done
   exit 0
# execute the comand on given hosts
elif [ "$OPT" == '-e' ]
then
   # no way, help here
   echo $CMD | egrep -q '^-' && dohelp
   [ -z "$CMD" ] && dohelp
   for HOST in $(grep -i "$SEARCH" $CONF | cut -d: -f2- | cut -d\; -f1)
   do
      sgo $HOST
      echo 
      debug RUN: $SGO \" $CMD \" 
      echo "$HOST: \"$CMD\""
      echo "-------------------------------------------------------"
      if [ $JUMP == 1 ]
      then
         $SGO \" $CMD \" 2>&1 
      else
         $SGO " $CMD " 2>&1 
      fi
   done
   exit 0
elif [ "$SEARCH" == '-c' ]
then
   vim $(ls -1 $CONF | head -n1)
else
   # no way, please help here
   [ -z "$SEARCH" ] && dohelp
   echo $SEARCH | egrep -q '^-' && dohelp
   echo $OPT | egrep -q '^-' && dohelp
   # search for pattern in host list
   echo 
   echo " results for search: $*"
   echo " --------------------------------"
   grep -i "$SEARCH" $CONF | cut -d: -f2-
   echo
   exit 0
fi

################################################################################
# $Log: mcom.sh,v $
# Revision 1.5  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.4  2010/05/10 08:41:10  chris
# konsole as terminal option added
#
# Revision 1.3  2010/04/29 05:06:20  chris
# minor bug fixing
#
# Revision 1.1  2010/01/17 20:40:14  chris
# Initial revision
#

