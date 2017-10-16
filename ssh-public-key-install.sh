#! /bin/bash
# DESC: script to install public key authentication on ssh-server
# $Revision: 1.4 $
# $RCSfile: ssh-public-key-install.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Hilfe Text
if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
   echo "
   Funktion: $0 ist ein Script um SSH public keys auf Ziehlhosts zu
installieren

   Aufruf: $0 user@host1 user@host2 ...

   "
   exit 0
fi

if test -e ~/.ssh/id_dsa && test -e ~/.ssh/id_dsa.pub
then
   DUMMY=1
else
   ssh-keygen -t dsa
fi

DEFIF=$( ip route  | grep default | sed 's/.*dev //g' | awk '{print $1}' )
FROMIP=$(/sbin/ifconfig $DEFIF | grep 'inet ' | awk '{print $2}' | head -1)
PUBK=$(cat ~/.ssh/id_dsa.pub)

for i in $*
do
   echo "$i - Key installieren"
   echo "----------------------------------------"
   ssh $i "/usr/bin/test -d ~/.ssh || mkdir -m700 ~/.ssh && touch ~/.ssh/authorized_keys ; \
           if grep $USER@$(hostname -s) ~/.ssh/authorized_keys &> /dev/null ; \
           then echo PUB KEY war auf $i bereits installiert ;\
           else echo "from='\"'$FROMIP'\"' $PUBK" >> ~/.ssh/authorized_keys ; chmod 644 ~/.ssh/authorized_keys ; fi"
done
exit 0

################################################################################
# $Log: ssh-public-key-install.sh,v $
# Revision 1.4  2014/09/03 06:48:08  chris
# added from=ip to key
#
# Revision 1.3  2011/02/10 20:22:32  chris
# create .ssh dir if not exist
#
# Revision 1.2  2011/02/10 20:18:01  chris
# name change from public-key-install.sh to ssh-public-key-install.sh
#
# Revision 1.1  2010/01/17 20:40:17  chris
# Initial revision
#
