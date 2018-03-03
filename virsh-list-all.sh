#!/bin/bash
# DESC: show all vms across multiple kvm servers
# Author: chris@bitbull.ch

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

bold=$(tput bold)
reset=$(tput sgr0)

echo
for c in kvm1 kvm2 kvm3
do
   if [ "$c" = "$(uname -n)" ]
   then
      echo "$bold $(uname -n | tr 'a-z' 'A-Z') -> Free Mem: $(( $(free -t | grep ^Mem: | awk '{print $7}') / 1024 )) MB $reset"
      virsh list --all --title | sed 's/^/     /g'
   echo $reset
   else
      echo "$bold $(echo $c | tr 'a-z' 'A-Z') -> Free Mem: $(( $(free -t | grep ^Mem: | awk '{print $7}') / 1024 )) MB $reset"
      ssh $c "virsh list --all --title" | sed 's/^/     /g'
      echo $reset
   fi
done

