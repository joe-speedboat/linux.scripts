#!/bin/bash
# DESC: rotate defined ganerations of logs without moving inode
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: log-rotate-size.sh,v $
# USAGE: logslave.sh /path/to/logfile.log <size im MB>

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

ID=$(date '+%Y%m%d')
FILE=$1
SIZE=$2
GEN=5
ZIP=1


#check input to be a real file
test -f "$1"
if [ $? -ne 0 ]
then
   logger -t $(basename $0) "ERROR: file does not exist: $FILE"
   echo "USAGE: logslave.sh /path/to/logfile.log <size im MB>"
   exit 1
fi

#check input to be digits
echo "$2" | egrep -q '^[0-9]+$'
if [ $? -ne 0 ]
then
   logger -t $(basename $0) "ERROR: rotation size not ok: $SZIE"
   echo "USAGE: logslave.sh /path/to/logfile.log <size im MB>"
   exit 1
fi

#get current size of log file
CSIZE=$(du -BM $FILE | cut -dM -f1)

if [ $CSIZE -ge $SIZE ]
then
   #cat file to new inode and empty current log file
   nice -n19 cat $FILE > $(dirname $FILE)/$ID-$(basename $FILE)
   if [ $? -ne 0 ]
   then
      logger -t $(basename $0) "ERROR: rotation canceld: $FILE"
      echo "could not create logfile: $(dirname $FILE)/$ID-$(basename $FILE)"
      rm -f $(dirname $FILE)/$ID-$(basename $FILE)
      exit 1
   else
      echo '' > $FILE
   fi

   #zip file if wanted
   if [ $ZIP -eq 1 ]
   then
      echo
      nice -n19 gzip $(dirname $FILE)/$ID-$(basename $FILE)
   fi
   #do log rotation now
   cd $(dirname $FILE)
   rm -rf tmpxxx
   mkdir tmpxxx
   for SAVE in $(ls -1 | grep "\-$(basename $FILE)*" | sort -un | tail -n$GEN)
   do
      mv $SAVE tmpxxx
   done
   rm -f *-$(basename $FILE)*
   mv ./tmpxxx/* ./
   rm -r tmpxxx
   logger -t $(basename $0) "INFO: rotated, FILE=$FILE, SIZE=$CSZIE"
fi
exit 0

################################################################################
# $Log: log-rotate-size.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:13  chris
# Initial revision
#
