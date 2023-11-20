#!/bin/bash
# DESC: FreeIPA Health Check, used by Zabbix Agent
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

EXCLUDE_SOURCES='ipahealthcheck.ipa.idns|xxxxxxxxx'

logger -t ipa-healthcheck-zabbix  'health check started'

STDOUT="$(ipa-healthcheck --failures-only --severity ERROR --output-type human 2>&1 | grep -v SUCCESS: | egrep -v "$EXCLUDE_SOURCES" | egrep '[a-zA-Z]')"
RC=$(echo "$STDOUT" | egrep '[a-zA-Z]' | wc -l)

echo "$STDOUT"
echo RC=$RC

exit $RC

