#!/bin/bash
# DESC: execute comands with sudo as root on multiple hosts
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: ssh-sudo-exec.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


USER=$(whoami)
echo 
echo "multiple comand for sudoers on multiple hosts"
echo
echo "note: delimiter for hosts and files is <space>"
echo -n "hostnames: "
read HOSTS
echo
echo -n "comand: "
read COMAND
echo
echo -n "password: "
read -s PW
echo
echo "ok, now i go and get it ...."
for HOST in $HOSTS
do
   echo "$HOST - $COMAND"
   echo "------------------------------------------------------"
   ssh -t $USER@$HOST "echo $PW | sudo -S su - -c \"$COMAND \"" 2>&1 | grep -v '^##' | grep -v '^$'
   echo ""
done

echo done ...

################################################################################
# $Log: ssh-sudo-exec.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:19  chris
# Initial revision
#
