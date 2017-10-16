#!/bin/bash
###########################################################################################
# DESC: records and plays console sessions with script in realtime
# $Author: chris $
# $Revision: 1.4 $
# $RCSfile: console-recorder.sh,v $
###########################################################################################

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

help(){
   echo
   echo "   Usage:   $(basename $0) [Option]"
   echo
   echo "   Options:"
   echo "            -r [name]   Records this session in files [name].session and [name].timing"
   echo "            -p <name>   Plays the recorded session named <name>.session and <name>.timing"
   echo "            -h|--help   show this help"
   echo
   echo "   Note: - if no option is given, it starts recording with session name: hostname-YYYY-MM-DD-hh-mm"
   echo "           exit recording by typing: exit or <CTRL>+<D>"
   echo "         - if you want to replay recording without timing, do: cat <name>.session"
   echo
   }

record(){
   [ -z "$NAME" ] && NAME="$(uname -n)-$(date '+%Y-%m-%d-%H-%M')"
   if [ -r "$NAME.session" -o -r "$NAME.timing" ] ; then
      echo "ERROR: cant start recording, files $NAME.session and $NAME.timing already present"
      exit 1
   fi
   script -t 2> $NAME.timing -a $NAME.session
   }

play(){
   if [ -r "$NAME.session" -o -r "$NAME.timing" ] ; then
      echo "INFO: starting replay of session files: $NAME.session $NAME.timing"
      scriptreplay $NAME.timing $NAME.session
      echo "INFO: end of recorded session reached"
   else
      echo "ERROR: cant start playing, files $NAME.session and $NAME.timing not present"
      exit 1
   fi
   }

case "$1" in
     -r)
           NAME="$2"
           record
           ;;
     -p)
           NAME="$2"
           play
           ;;
     *)
           help
           exit 0
           ;;
esac

################################################################################
# $Log: console-recorder.sh,v $
# Revision 1.4  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.3  2010/05/10 12:26:14  chris
# help updated
#
# Revision 1.2  2010/05/10 12:12:58  chris
# error handling optimized
#
# Revision 1.1  2010/05/10 10:11:43  chris
# Initial revision
#
