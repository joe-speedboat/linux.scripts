#!/bin/bash
#########################################################################################
# DESC: export vRA content with cloudclient
# tested with vRA 7.3 / CloudClient 4.4
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# HOWTO INSTALL CLOUD CLIENT VRA BACKUP #######################################
##### create password file
# login keyfile --file /home/chris/.cloudclient/cloudclient.pass
##### generate autologin file
# login autologinfile
##### this file is located in your cloudclient software dir
# vi /opt/cloud-client/CloudClient.properties
#------
# vra_server=vra1.lab.local
# vra_tenant=lab
# vra_username=chris@lab.local
# vra_keyfile=/home/chris/.cloudclient/cloudclient.pass
# vra_iaas_username=chris@lab.local
# vra_iaas_keyfile=/home/chris/.cloudclient/cloudclient.pass
# vco_server=vra1.lab.local
# vco_username=chris@lab.local
# vco_keyfile=/home/chris/.cloudclient/cloudclient.pass
# ---
###############################################################################
export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
BDIR=/home/chris/vra-backup
KEEPGEN=30
DATE=$(date '+%Y%m%d-%H%M')

test -d $BDIR/$DATE || mkdir -p $BDIR/$DATE
cd $BDIR/$DATE

logger -t $(basename $0) "cloud client backup started"
cloudclient 2>&1 << EOF | sed -n '/^id,/,$p' | grep ',.*,.*,'  > content.list
vra content list --format csv --pageSize 1000
EOF
[ $? -eq 0 ] && RC_STATUS='SUCCESS' || RC_STATUS='FAIL'
logger -t $(basename $0) "exported content.list with status $RC_STATUS"

# id,contentId,name,contentTypeId
cat content.list | sed '1d' | while read content
do
   content_id="$(echo $content | cut -d, -f1)"
   content_type="$(echo $content | cut -d, -f4)"
   content_name="$(echo $content | cut -d, -f2)"
   cloudclient 2>&1 << EOF > $content_type-$content_name-export.log
vra content export --path ./ --type $content_type --secure no --id $content_id
EOF
   [ $? -eq 0 ] && RC_STATUS='SUCCESS' || RC_STATUS='FAIL'
   logger -t $(basename $0) "exported $content_type / $content_name with status $RC_STATUS"
done

logger -t $(basename $0) "cloud client backup fineshed"


logger -t $(basename $0) "deleting backups down to $KEEPGEN generations"
cd $BDIR || exit 1
ls -1d * | egrep -x "^2.......-....$" | head -n-$KEEPGEN | while read DEL_BKP
do
   logger -t $(basename $0) "deleting backup $BDIR/$DEL_BKP"
   rm -rf $BDIR/$DEL_BKP 
done

