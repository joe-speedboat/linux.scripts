#!/bin/bash
#########################################################################################
# DESC: bash script to rapport work in /README file
# $Revision: 1.2 $
# $RCSfile: sys-note-german.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

RFILE=/README
GRP=betrieb
GID=3000

# DO SOME INSTALLATION TASKS 
if [ ! -e $RFILE ]
then
   touch $RFILE
   grep -q :x:$GID: /etc/group || /usr/sbin/groupadd -g $GID $GRP
   GRP=$(grep :x:$GID: /etc/group  | cut -d: -f1)
   chmod 660 $RFILE
   chown root:$GRP $RFILE
fi

# ASK FOR CHANGES
askme () {
   clear
   echo "
        HAVE YOU UPDATET THE $RFILE ???
        ---------------------------------
   
        What do you want to do?

        a -> Add a new entry
        e -> Edit /README
        h -> View help page
        x -> Exit
        "
   read -p "        What: " ACTION

   ACTION=`echo "$ACTION" | tr 'a-zA-Z' 'a-z'`

   case "$ACTION" in
        a)
              nentry
              askme
              ;;
        e)
              vi $RFILE
              askme
              ;;
        x)
              exit 0
              ;;
        h)
              help
              echo '
                    zurueck zum menu mit <enter>'
              read R
	      askme
              ;;
        *)
              echo "depp"
              sleep 1
              askme
              ;;
   esac                        

}

# WRITE NEW ENTRY
nentry () {
   clear
   HOST=$(uname -n)
   DAY=`date +%Y.%m.%d`
   TIME=`date +%H:%M`
   RUID=`who am i | awk '{print $1}'`
   ERR="betrieb"
   DT="0m"
   ST="15m"
   NST=
   ED=
   SOL=
   read -p  "   
   Datum [$DAY]: " NDAY
   read -p  "   
   Zeit [$TIME]: " NTIME
   read -p  "   
   User [$RUID]: " NRUID
   read -p  "   
   Auftrag [$ERR]: " NERR
   read -p  "   
   DownTime [$DT]: " NDT
   read -p  "   
   WorkTime [$ST]: " NST
   read -p  "   
   ErrorDesc : " ED
   read -p  "   
   Solution: " SOL
   
   if [ $NDAY ] ; then DAY="$NDAY" ; fi   
   if [ $NTIME ] ; then TIME="$NTIME" ; fi   
   if [ $NRUID ] ; then RUID="$NRUID" ; fi   
   if [ $NERR ] ; then ERR="$NERR" ; fi   
   if [ $NDT ] ; then DT="$NDT" ; fi   
   if [ $NST ] ; then ST="$NST" ; fi   

   echo "$HOST;$DAY;$TIME;user=$RUID;grund=$ERR;dt=$DT;st=$ST;desc=$ED;done=$SOL" >> $RFILE 
}

help() {
   clear
   echo "
   anleitung zum $(basename $0):
   ---------------------------------------------
   ziel dieses scripts ist die arbeiten an den systemen festzuhalten.
   dies um die nachvollziehbarkeit zu gewaehrleisten und die arbeit im team zu erleichtern.
   folgende felder werden erfasst:

   Datum     -> datum der aenderung
   Zeit      -> zeitpunkt der aenderung
   User      -> wer hat die arbeit durchgefuehrt
   Auftrag   -> was ist der beweggrund fuer diese arbeit
                z.B.: betrieb, wartungsfenster, pikett
   DownTime  -> wie lange war der betrieb des systems unterbrochen
   WorkTime  -> wie viel zeit wurde fuer die ausfuehrung der arbeit benoetigt
   ErrorDesc -> titel der die arbeit kurz umschreibt
                 z.B.: TE #SFR006961
	 	       PR K6603
		       RH Bug 509789
		       tacMon URL w.domain.com
		       tacMon /chroot 92%
   Solution: -> beschreibung der ausgeführen arbeit
                z.B.: jkworker.properties waehrend hype zur fehlersuche angepasst
		      kunde xy im apache reverse proxy erfasst
		      ssl cert fuer domain xy ersetzt
   "

}

cmdhelp(){
echo "
 aufruf: 
                 $(basename $0) [ optionen ]

 optionen:
   -a            springe direkt ins menu "neuer eintrag"

   -x            ruft $(basename $0) auf, aber nur wenn es auf der letzten offenen 
                 console auf dem host ausgefuehrt wird, ideal für .bash_logout
                 installation: echo \"$(which $(basename $0)) -x\" >> $HOME/.bash_logout
                 
                 wird keine option angegeben startet $(basename $0) 
                 mit den standard menu

   -h|--help     ruft diese hilfe auf
"

}

# CHECK SOME INPUT
if [ "$1" = "-h" -o "$1" = "--help" ]
then
   cmdhelp
   exit 0
elif [ "$1" = "-a" ]
then
   nentry
   exit 0
elif [ "$1" = "-x" ]
then
   RUID=`who am i | awk '{print $1}'`
   IN=`w | grep ^$RUID | wc -l`
   if [ $IN -le 1 ]
   then
      askme
   fi
   exit 0
fi

#START PROGRAM
askme

################################################################################
# $Log: sys-note-german.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/04/20 06:43:00  chris
# Initial revision
#

