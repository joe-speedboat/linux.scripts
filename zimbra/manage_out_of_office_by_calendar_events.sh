#!/bin/bash
# DESC: control out_of_office answers with calendar entries.
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#/bin/bash

unset LC_ALL
export LC_ALL=en_US.UTF-8
export LANG=en_US

OOO_MSG="Dear Sir or Madam,

Thank you for your message!

The recipient of this mailbox is absent.
In urgent cases please contact our helpdesk:
eMail: elvira@acme.com"


# GET ALL MAILBOXES FOR DOMAIN                        FILTER ALIASES ONLY     EXTRACT MAIL     FILTER ACCOUNTS WITH REGEX
zmprov sa -v zimbraMailDeliveryAddress="*@acme.com" | grep zimbraMailAlias  | sed 's/.*: //' | egrep '^team....@'          | while read mb
do
  echo "---------- $mb"  # SEARCH FOR TOMORROW ALL DAY EVENTS                            SELECT EVENTS WITH NAME "OOO"
  read OOO < <(zmmailbox -v -z -m $mb getAppointmentSummaries +1day +1day | jq -r '.[] | select(.name=="OOO") .name + ":" + .fragment')
  if [ $(echo "$OOO" | cut -d: -f1 | wc -c) -gt 5 ]
  then
    echo "INFO: Found OOO event"
    if [ $(echo "$OOO" | cut -d: -f2 | wc -c) -gt 5 ]
    then
      echo "INFO: Found custom OOO message"
      OOO_MSG="$(echo $OOO | cut -d: -f2 | sed 's#\. #.\n#g' )"
    else
      echo "INFO: Found no OOO message, use default one"
    fi
    echo "WARNING: Configure OOO for USER $mb"
    zmprov ma $mb zimbraPrefOutOfOfficeReply "$OOO_MSG"
    zmprov ma $mb zimbraPrefOutOfOfficeReplyEnabled TRUE
    zmprov ma $mb zimbraPrefOutOfOfficeFromDate $(date "+%Y%m%d000000Z")
    zmprov ma $mb zimbraPrefOutOfOfficeUntilDate $(date -d "+1 day" "+%Y%m%d215959Z")
  else
    echo "INFO: Found no OOO event"
  fi
done
