#!/bin/bash
# DESC: script to rename freeipa/idm userid and re-attach its totp tokens
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

ufrom=$1
uto=$2

id $ufrom || exit 1
id $uto >/dev/null 2>&1 && exit 1
sleep 2

echo "exec: ipa user-mod $ufrom --homedir=/home/$uto --rename=$uto"
ipa user-mod $ufrom --homedir=/home/$uto --rename=$uto
sleep 5


ipa otptoken-find | grep -e 'Owner:' -e 'Unique ID:' | grep -B1 "Owner: $ufrom" | grep 'Unique ID:' | sed 's/.*: //' | while read id
do
  echo "exec: ipa otptoken-mod $id --owner=$uto"
  ipa otptoken-mod $id --owner=$uto
done

