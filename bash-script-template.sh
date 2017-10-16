#!/bin/bash
# DESC: bash script template with prevention of dubble execution, logging function and error handling
# $Author$
# $Revisionc$
# $RCSfile$

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

########## GLOBAL VARIABLES ####################################################
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TOP_PID=$$
LANG="en_US.UTF-8"
SCRIPTNAME=$(basename $0)
PIDFILE="/tmp/${scriptname}.pid"
LOGDIR=/tmp
LOG_FILE=$LOGDIR/$SCRIPTNAME.log
> $LOG_FILE
ERR_FILE=$LOGDIR/$SCRIPTNAME.err
> $ERR_FILE
set -o pipefail

########## MY VARIABLES ########################################################
MAIL_ON_ERR=1
TO=root
SUBJ="$SCRIPTNAME on $(uname -n)"
DEBUG=1




########## CHECK MY DEPS #######################################################
which mailx || log error please install mailx first


########## FUCTIONS ############################################################
log(){ #---------------------------------------------------
   LOG_LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   if [ "$LOG_LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $SCRIPTNAME:$LOG_LEVEL: $*"
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $SCRIPTNAME:$LOG_LEVEL: $*" >> $LOG_FILE
      logger -t $SCRIPTNAME "$LOG_LEVEL: $*"
   fi
   if [ "$LOG_LEVEL" = "ERROR" -o "$LOG_LEVEL" = "WARNING" -o "$LOG_LEVEL" = "INFO" ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $SCRIPTNAME:$LOG_LEVEL: $*"
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $SCRIPTNAME:$LOG_LEVEL: $*" >> $LOG_FILE
      logger -t $SCRIPTNAME "$LOG_LEVEL: $*"
   fi
   if [ "$LOG_LEVEL" = "ERROR" ]
   then
      if [ $MAIL_ON_ERR -eq 1 ] 
      then
         # do some diagnosis here and write it to mail
         mail -s "ERROR: $SUBJ" -a $LOG_FILE -a $ERR_FILE $TO
      fi
      kill $TOP_PID
      sleep 1
      kill -9 $TOP_PID
   fi
}


########## PREVENT FROM GETTING EXECUTED TWICE AT SAME TIME ####################
exec 200>$pidfile
flock -n 200 || exit 1
PID=$$
echo $pid 1>&200

########## MAIN SCRIPT GOES HERE

# do this || log error could not do this
# do that && log info finished that
# log debug VAR1=$VAR1 VAR2=$VAR2


# do your stuff here




################################################################################
# $Log$
