#!/bin/bash
# DESC: automated email reply script, like a ping :)
# DESC2: aliases or virtual: user | mailecho.sh
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: mailecho.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

TMPF=/tmp/$$-$(basename $0).tmp

while read line
do
   echo $line >> $TMPF
done

TO=$(grep '^Return-Path: ' $TMPF | cut -d\< -f2 | cut -d\> -f1)
SUBJ=$(grep '^Subject: ' $TMPF | cut -d: -f2-)
FROM=echo@bitbull.ch

echo " Ihre eMail mit dem untenstehenden Inhalt ist erfolgreich versendet worden.
 Wenn Sie diese Mail lesen koennen, koennen Sie eMail versenden und auch empfangen.

 Ihre original eMail:
 ----------------------------------------------------------------------------
$(cat $TMPF )" | mail -s "Antwort auf: $SUBJ" $TO
#rm -f $TMPF
exit 0

################################################################################
# $Log: mailecho.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:13  chris
# Initial revision
#
