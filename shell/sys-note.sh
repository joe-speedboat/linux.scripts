#!/bin/bash
#########################################################################################
# DESC: bash script to rapport work in /README file
# INFO: /usr/local/sbin/sys-note.sh in ~/.bash_logout
# $Revision: 1.3 $
# $RCSfile: sys-note.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


RFILE=/README

# ASK FOR CHANGES
askme () {
   clear
   echo "
        HAVE YOU UPDATET THE /README ???
        --------------------------------
   
        What do you want to do?

        a -> Add a new entry
        e -> Edit /README
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
              vi /README
              askme
              ;;
        x)
              exit 0
              ;;
        *)
              echo "depp"
              sleep 1
              askme
              ;;
   esac                        

}


nentry () {
   clear
   DAY=`date +%Y.%m.%d`
   TIME=`date +%H:%M`
   RUID=`who am i | awk '{print $1}'`
   ERR="none"
   DT="0"
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
   Error via [$ERR]: " NERR
   read -p  "   
   Down Time [$DT]: " NDT
   read -p  "   
   Solution Time [$ST]: " NST
   read -p  "   
   Error Desc : " ED
   read -p  "   
   Solution: " SOL
   
   if [ $NDAY ] ; then DAY="$NDAY" ; fi   
   if [ $NTIME ] ; then TIME="$NTIME" ; fi   
   if [ $NRUID ] ; then RUID="$NRUID" ; fi   
   if [ $NERR ] ; then ERR="$NERR" ; fi   
   if [ $NDT ] ; then DT="$NDT" ; fi   
   if [ $NST ] ; then ST="$NST" ; fi   

   echo "$DAY $TIME $RUID $ERR dt:$DT st:$ST $ED, sol:$SOL " >> $RFILE 
}


#START PROGRAM
askme

################################################################################
# $Log: sys-note.sh,v $
# Revision 1.3  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.2  2010/02/25 07:55:43  chris
# user field bugfixed, new is who am i
#
# Revision 1.1  2010/01/17 20:40:20  chris
# Initial revision
#
