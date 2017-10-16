#!/bin/bash
# DESC: get multiple files on multiple hosts to local machine
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: get-rsync-sudo.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

USER=$(whoami)
echo 
echo "multiple file get script for sudoers on multiple hosts"
echo
echo "note: delimiter for hosts and files is <space>"
echo -n "hostnames: "
read HOSTS
echo
echo -n "filenames: "
read FILES
echo
echo -n "password: "
read -s PW
echo
echo "ok, now i go and get it ...."
DIRS=
CPS=
for HOST in $HOSTS
do
   for FILE in $FILES
   do
      DIR=$(dirname $FILE)
      CP="cp $FILE /home/$USER/$HOST$DIR/"
      CPS="$CP ; $CPS"
      DIRS="$DIRS $HOST$DIR"
   done
   ssh $USER@$HOST "mkdir -p $DIRS ; echo $PW | sudo -S su - -c \"$CPS chown -R $USER /home/$USER/$HOST \""
   scp -r $USER@$HOST:$HOST ./
   ssh $USER@$HOST "rm -rf ./$HOST"
done

echo done ...

################################################################################
# $Log: get-rsync-sudo.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:12  chris
# Initial revision
#
