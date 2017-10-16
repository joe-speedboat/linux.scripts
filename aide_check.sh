#!/bin/bash
#########################################################################################
# DESC: Aide Check script with simple eMail reporting
# $Revision: 1.1 $
# $RCSfile: aide_check.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin

TO=admin@bitbull.ch
CUR_DB=/var/lib/aide/aide.db.gz
NEW_DB=/var/lib/aide/aide.db.new.gz
SUBJ="Aide Report on $(uname -n)"
DEBUG=1
LOGDIR=/tmp
OK_TAG='All files match AIDE database. Looks okay'
HINT="
In case of alert, keep attention to the changes!

         --= BE AWARE =--
IF YOU DO NOT KNOW WHY THE CHANGE OCCURED, 
       IT COULD BE A INTRUSION ! ! !

If you know the reason for this Alert, 
you have to update the Aide database, 
to take a new snapshot:
   aide --update
   mv $NEW_DB $CUR_DB"


rm -f  $LOGDIR/$(basename $0).log
touch $LOGDIR/$(basename $0).log || exit 1
chmod 600 $LOGDIR/$(basename $0).log || exit 1

log(){ #---------------------------------------------------
   LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   if [ "$LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" 
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" >> $LOGDIR/$(basename $0).log
      logger -t $(basename $0) "$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*"
      test -d $LOGDIR && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" >> $LOGDIR/$(basename $0).log
      logger -t $(basename $0) "$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" ]
   then
      exit 111
   fi
}

ARG=$1
if [ "$ARG" = "-u" ] ; then
   log warning starting update of aide database
   ( aide --update
   mv $NEW_DB $CUR_DB ) >> $LOGDIR/$(basename $0).log
   log warning aide database has been updated with current system state
   cat $LOGDIR/$(basename $0).log | mail -s "ALERT:$SUBJ" $TO
   exit
fi

# check if Aide is allready configured
if [ ! -f $CUR_DB ]
then
   log info aide is not configured, going to create first DB:$NEW_DB
   rm -f $NEW_DB $CUR_DB
   nice -n 19 aide --init >> $LOGDIR/$(basename $0).log 2>&1
   mv $NEW_DB $CUR_DB
   log info DB created: $CUR_DB
   logger info md5sum aide-db: $(md5sum $CUR_DB)
   cat $LOGDIR/$(basename $0).log | mail -s "WARNING: $SUBJ" $TO
else 
   log info starting aide check now
   logger info md5sum aide-db: $(md5sum $CUR_DB)
   nice -n 19 aide --check >> $LOGDIR/$(basename $0).log 2>&1
   log info aide check finished
   grep -q "$OK_TAG" $LOGDIR/$(basename $0).log
   if [ $? -ne 0 ]
   then
      log warning found changes on system
      SUBJ="ALERT: $SUBJ"
      echo >> $LOGDIR/$(basename $0).log
      echo "$HINT" >> $LOGDIR/$(basename $0).log
   else
      SUBJ="INFO: $SUBJ"
   fi
   cat $LOGDIR/$(basename $0).log | mail -s "$SUBJ" $TO
fi


