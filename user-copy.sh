#!/bin/bash
# DESC: copy user from other system to local system
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: user-copy.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


# system to copy user from
SHOST=$1
# username to copy
USR=$2

[ $# -ne 2 ] && exit 1

mkdir -p /root/.pwcopy 2>/dev/null
rm -f /root/.pwcopy/*
scp $SHOST:/etc/{passwd,shadow,group,group} /root/.pwcopy/

cd /root/.pwcopy/
grep ^$USR: passwd > passwd.copy
grep ^$USR: shadow > shadow.copy
grep :$(cut -d: -f4 passwd.copy): group > group.copy
grep :$(cut -d: -f4 gshadow.copy): group > gshadow.copy

grep -q ^$USR: /etc/passwd
if [ $? -ne 0 ]
then
   cat passwd.copy >> /etc/passwd
   cat shadow.copy >> /etc/shadow
   cat group.copy >> /etc/group
   cat gshadow.copy >> /etc/gshadow
   pwconv
   grpconv
   mkdir -p $( dirname $(grep ^$USR: passwd.copy | cut -d: -f6 ))
   cp -a /etc/skel $(grep ^$USR: passwd.copy | cut -d: -f6)
   chown -R $USR:$(cut -d: -f4 gshadow.copy) $(grep ^$USR: passwd.copy | cut -d: -f6)
   chmod -R 700 $(grep ^$USR: passwd.copy | cut -d: -f6)
   pwck
   grpck
fi
rm -fr /root/.pwcopy

################################################################################
# $Log: user-copy.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:21  chris
# Initial revision
#
