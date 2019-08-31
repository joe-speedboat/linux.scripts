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


echo "$bold"
echo "$(uname -n | tr 'a-z' 'A-Z') ->"
echo "      commited mem (running VMs): $(virsh list --name | while read vm; do virsh domstats $vm | grep balloon.maximum ; done | cut -d= -f2 | awk '{s+=$0} END {print s/1024/1024" GB"}')"
echo "      used mem (running VMs): $(virsh list --name | while read vm; do virsh domstats $vm | grep balloon.current ; done | cut -d= -f2 | awk '{s+=$0} END {print s/1024/1024" GB"}')"
echo "      virtHost free mem: $(( $(free -t | grep ^Mem: | awk '{print $7}') / 1024 /1024 )) GB"
virsh list --all --title | sed 's/^/     /g'
echo $reset


