#!/bin/sh
#########################################################################################
# DESC: Send SMS via ASPSMS gateway from OpenWrt, used by checkhost.sh
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# HOWTO SETUP ###########################################################################
# - download this script and make it executeable
# - fill in the userKey, Password and FROM var below
# - usage:
#     aspsms.sh <mobile-number> <text to send, spaced get replaced by _>  


PATH=/usr/bin:/usr/sbin:/bin:/sbin:/etc/config/bin
export PATH

UserKey='AAAAABBBBCCC'
Password='12345654'
FROM=SenderName
MOBILE="$1"
SMS="$2"
SMS="`echo $SMS | tr ' ' '_'`"
echo SMS: $SMS
echo MOBILE: $MOBILE

curl -k "https://soap.aspsms.com/aspsmsx.asmx/SimpleTextSMS?UserKey=$UserKey&Password=$Password&Recipient=$MOBILE&Originator=$FROM&MessageText=$SMS"

