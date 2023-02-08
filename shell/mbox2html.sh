#! /bin/bash
# DESC: generiert html listen aus mailboxen (mit hilfe von mhonarc)
# $Revision: 1.2 $
# $RCSfile: mbox2html.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

MA=/usr/bin/mhonarc
MDIR=/home/bitbull/homes/chris/mail
HDIR=/home/bitbull/html

MLIST=selinux
rm -rf $HDIR/$MLIST/*
$MA -mailtourl http://www.nsa.gov/$MLIST -addressmodifycode 's/.*@/user\@/g' -nospammode -outdir $HDIR/$MLIST/ $MDIR/$MLIST 2>&1
ln -s $HDIR/$MLIST/maillist.html $HDIR/$MLIST/index.html

MLIST=xen
rm -rf $HDIR/$MLIST/*
$MA -mailtourl http://lists.xensource.com -addressmodifycode 's/.*@/user\@/g' -nospammode -outdir $HDIR/$MLIST/ $MDIR/$MLIST 2>&1
ln -s $HDIR/$MLIST/maillist.html $HDIR/$MLIST/index.html

################################################################################
# $Log: mbox2html.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:13  chris
# Initial revision
#
