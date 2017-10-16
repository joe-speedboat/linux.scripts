########################################################################################
# DESC: .procmail file for email2sms gateway
# $Revision: 1.2 $
# $RCSfile: email2sms-procmail.sh,v $
# $Author: chris $
#########################################################################################

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

SHELL=/bin/sh
PATH=/bin:/usr/bin:/usr/local/bin
LOGABSTRACT=all
LOGFILE=$HOME/proclog   # recommended for debugging
VERBOSE=off

PHONENUMBER=`formail -z -x"To:" | cut -d'@' -f1 | sed -e 's/[^0-9\+]//g'`
REPLYFROM=noreply@sms.bitbull.ch
SENDER=`formail -z -x"Return-Path:" | cut -d\< -f2 | cut -d\> -f1`

:0c
* ^Subject: SMS-KEY
{
:0c
| echo "To: $SENDER" > $HOME/smslog; \
  echo "Subject: SMS send log" >> $HOME/smslog; \
  echo "sent to: $PHONENUMBER" >> $HOME/smslog; \
  echo "send date: $(date '+%Y.%m.%d %H:%M')" >> $HOME/smslog; \
  echo "--------------------------------" >> $HOME/smslog; \
  formail -k -x"Dummy:" | \
  tee -a $HOME/smslog | iconv -c -f ISO-8859-1 -t UTF-8 - | sms.rb -f $SENDER $PHONENUMBER 2>&1; \
  /usr/sbin/sendmail -i -f $REPLYFROM $SENDER < $HOME/smslog;

:0
.SentMsgs/
}

################################################################################
# $Log: email2sms-procmail.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:11  chris
# Initial revision
#
