#!/bin/bash
#########################################################################################
# DESC: list all nextcloud shares
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# USEAGE: start this script as root
#         $ nc_share_audit.sh 

OCC='sudo -u nginx /srv/nextcloud/html/occ'

SED_PERM='
s/permissions: 1$/permissions: Read/
s/permissions: 3$/permissions: Update + Read/
s/permissions: 5$/permissions: Create + Read/
s/permissions: 7$/permissions: Create + Update + Read/
s/permissions: 9$/permissions: Read + Delete/
s/permissions: 11$/permissions: Update + Read + Delete/
s/permissions: 13$/permissions: Create + Read + Delete/
s/permissions: 15$/permissions: Create + Update + Read + Delete/
s/permissions: 17$/permissions: Read + Reshare/
s/permissions: 19$/permissions: Update + Read + Reshare/
s/permissions: 21$/permissions: Create + Read + Reshare/
s/permissions: 23$/permissions: Create + Update + Read + Reshare/
s/permissions: 25$/permissions: Read + Delete + Reshare/
s/permissions: 27$/permissions: Update + Read + Delete + Reshare/
s/permissions: 29$/permissions: Create + Read + Delete + Reshare/
s/permissions: 31$/permissions: Create + Update + Read + Delete + Reshare/
'

$OCC app:install sharelisting | grep -v 'sharelisting already installed'
$OCC app:enable sharelisting | grep -v 'sharelisting enabled'

$OCC sharing:list | grep : | sed 's/["|,$|\\]//g;/token:/d;s/\(owner: .*\)/\n\t\1/' | sed "$SED_PERM"

