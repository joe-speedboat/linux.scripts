#! /bin/bash
# DESC: bereinigt mailboxen eines mail hosting servers
# $Revision: 1.2 $
# $RCSfile: spam-shrinker.sh,v $
# $Author: chris $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


# im passwd nach home directories suchen
for SPAM in $(cut -d : -f 6 /etc/passwd | grep '/homes/' )
do      # loeschen der alten spam/unnoetigen mails
   archivemail --delete --days=30 --include-flagged --no-compress $SPAM/mail/spam
   archivemail --delete --days=30 --include-flagged --no-compress $SPAM/mail/Papierkorb
   archivemail --delete --days=90 --include-flagged --no-compress $SPAM/mail/Gesendet
done >/dev/null

################################################################################
# $Log: spam-shrinker.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:19  chris
# Initial revision
#
