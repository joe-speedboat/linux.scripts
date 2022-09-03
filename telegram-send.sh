#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

### DESCRIPTION ############################################################
# Send Telegram messages via cli, from stdin or by ARG1
# - Setup bot and get auth token
#   - https://www.toptal.com/python/telegram-bot-tutorial-python
# - Setup Chat Group
#   - add @getidsbot to your group
#   - get chat-id and kick @getidsbot from group
# - Configure this script vars
############################################################################

AUTH='9999999999:AAAAAAAbbbbbcccccccdddd-ddddddddddd'
CHAT='-9999999999999'

if [ "$1" == '-h' ]
then
   echo
   echo "usage: $(basename $0) -f <filename>           #Send file to destination"
   echo "       $(basename $0) <message text>          #Send message to destination"
   echo "       echo \"message text\" | $(basename $0)   #Send message to destination"

   exit 0
fi

if [ "$1" == '-f' ]
then
   curl -s -F "chat_id=$CHAT" -F document=@$2 https://api.telegram.org/bot$AUTH/sendDocument >/dev/null ; RC=$?
   echo
   echo INFO: Sent file: $2 : RC=$RC
   exit 0
fi

if [ $# -eq 0 ]
then
   MSG=$(</dev/stdin)
elif [ $# -gt 0 ]
then
   MSG="$*"
else
  echo ERROR, please handover message by stdin or ARG
  exit 1
fi

MSG_ENC="$(echo """$MSG""" |  curl -Gso /dev/null -w %{url_effective} --data-urlencode @- '' | cut -c 3- )"

curl -s -X POST "https://api.telegram.org/bot$AUTH/sendMessage?chat_id=$CHAT&text=$MSG_ENC" >/dev/null ; RC=$?
echo
echo INFO: Sent message: RC=$RC

