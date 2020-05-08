#!/bin/bash
#########################################################################################
# DESC: microphone input fix, BUG: GUACAMOLE-1003
# https://issues.apache.org/jira/browse/GUACAMOLE-1003
# CAUTION: ONLY WORKS WITH GUACAMOLE 1.1
#########################################################################################
# Copyright (c) Chris Ruettimann <chris.ruettimann@uniqconsulting.ch>
#
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# make sure system has bootet properly
sleep 15

# only apply if we have a bug
rpm -q libguac-client-rdp-1.1.0 >/dev/null
if [ $? -ne 0 ]
then
   echo "ERROR: This is not a Guacamole with verstion libguac-client-rdp-1.1.0"
   echo "We do not patch this version"
   exit 1
fi

# test if patch is downloaded already
test -f /etc/guacamole/guacamole.min.js.mic-fix-v1.1 ||\
wget https://raw.githubusercontent.com/joe-speedboat/shell.scripts/master/guacamole.min.js.mic-fix-v1.1 \
-O - > /etc/guacamole/guacamole.min.js.mic-fix-v1.1

cat /etc/guacamole/guacamole.min.js.mic-fix-v1.1 > /var/lib/tomcat/webapps/guacamole/guacamole.min.js
systemctl restart nginx
echo done

