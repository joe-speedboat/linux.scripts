#!/bin/bash
# DESC: Configure OpenShift imagestream to use autoupdate, with source
#       Tested with OpenShift 3.11
#
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

oc get is | egrep ^$1\  || ( echo "Useage: $(basename $0) image-stream-name" ; kill -9 $$ )

is=$1
tag="$(oc get is $is | awk '{$3}')"
echo "=== pathching is to autoupdate: $is"
oc patch is $is -p '{"spec":{"tags":[{"name":"$tag","importPolicy":{"scheduled":true}}]}}'

echo "=== verifying autoupdate of is: $is"
oc describe is $is | grep "updates automatically"

