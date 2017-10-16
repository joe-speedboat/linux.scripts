#!/bin/bash
# DESC: send email repport for dirvish backup vault
# $Author: chris $
# $Revision: 1.6 $
# $RCSfile: dirvish-report.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

VAULT=/srv/backup
MAILTO="support@bitbull.ch"
CONFIG=/etc/dirvish/master.conf

YESTERDAY=`date -d "yesterday" +%Y%m%d`

cd $VAULT || (echo "$0: ERROR: Please set the VAULT variable"; exit 1)

tmpfile=/tmp/dirvish.status.$$
exec > $tmpfile 2>&1

WARNINGS=""
ERRORS=""

for machine in `sed '1,/Runall:/d;/expire-default:/,$d;/^$/,$d' $CONFIG | awk '{print $1}'`
do
  echo "================== $machine =================="

  cd $machine

  # Check for a summary or log file (at least one should be
  # present if a backup occurred
  if [ ! -f $YESTERDAY[0-9][0-9][0-9][0-9][0-9][0-9]/log* -o ! -f $YESTERDAY[0-9][0-9][0-9][0-9][0-9][0-9]/summary ]
  then
    # If no backup last night, then warn.
    # Also, try to guess the last night a backup occurred.
    # (yes, it's crude.)
    echo "** WARNUNG: Diese Machine wurde NICHT gesichert!"
    last=`(ls -dt [0-9]* 2>/dev/null)|head -1`
    if [ "z$last" = "z" ]
    then
      last="NEVER"
    fi
    echo "             (last backup: $last)"
    ERRORS="$ERRORS $machine"
  else

    # search for status warning
    if [ `grep -c "Status: success" $YESTERDAY[0-9][0-9][0-9][0-9][0-9][0-9]/summary` -ne "1" ]
    then
      echo "** WARNUNG: Das Backup meldet Fehler!"
      echo
      # Keep a list of machines with warnings.
      WARNINGS="$WARNINGS $machine"
    fi

    # Copy the backup's summary file to the email, ignoring
    # any exclude: lines (to keep the email short, but useful.)
    (egrep -v "^$" $YESTERDAY[0-9][0-9][0-9][0-9][0-9][0-9]/summary  | sed '/^exclude:/,/^UNSET /d')
  fi
  echo

  cd $VAULT

done 

# Include a [**] notation on the subject line if there were warnings. 
if [ "$WARNINGS" != "" ]
then
  WARNSUB="WARNUNG: "
elif [ "$ERRORS" != "" ]
then
  WARNSUB="FEHLER: "
else
  WARNSUB="INFO: "
fi



if [ "$WARNINGS" != "" ]
then
  echo "Folgende Backups haben Warnungen: $WARNINGS" >> $tmpfile.head
fi
if [ "$ERRORS" != "" ]
then
  echo "Folgende Backups haben Fehler: $ERRORS" >> $tmpfile.head
fi
echo >> $tmpfile.head
echo "Disk Auslastung:" >> $tmpfile.head
echo "====================================" >> $tmpfile.head
/bin/df -hP $VAULT | column -t >> $tmpfile.head
echo >> $tmpfile.head
/bin/df -iP $VAULT | column -t >> $tmpfile.head
echo >> $tmpfile.head
( cat $tmpfile.head ; cat $tmpfile )| mail -s "${WARNSUB}Backup status (${YESTERDAY}@`hostname`)" $MAILTO

rm -f $tmpfile*

################################################################################
# $Log: dirvish-report.sh,v $
# Revision 1.6  2014/09/14 05:27:09  chris
# remove exclude list form report, cleanup
#
# Revision 1.5  2014/06/19 09:33:10  chris
# if state is not success, declare it as error
#
# Revision 1.4  2014/04/11 06:30:25  chris
# moved disk report to beginning, bugfix
#
# Revision 1.3  2014/04/03 06:48:21  chris
# log changed to log.gz
#
# Revision 1.2  2014/03/31 15:50:23  chris
# bugfixing "last backup"
#
# Revision 1.1  2013/05/30 13:33:34  chris
# Initial revision
#
