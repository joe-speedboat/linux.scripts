#! /bin/bash
# DESC: fetchmail script for cron with error handling
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: fetchmail.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

TF=/tmp/$$-$(basename $0).tmp
FF=/etc/fetchmailrc
TO=admin@bitbull.ch
SUBJ="Fetchmail Fehler auf $(hostname -f)"

fetchmail -n -f $FF > $TF 2>&1 
[ $? -gt 1 ] && cat $TF | mail -s "$SUBJ" $TO
rm -f $TF

################################################################################
# $Log: fetchmail.sh,v $
# Revision 1.2  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:12  chris
# Initial revision
#
