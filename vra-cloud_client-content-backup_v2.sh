#!/bin/bash
#########################################################################################
# DESC: export vRA content with cloudclient
# tested with vRA 7.3 / CloudClient 4.4
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
#
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
### CONTENT IN BACKUP DIR #####################################################
# logs/          -> cloudclient backup logs
# cc.history     -> cloudclient comand history (executed cmd during backup)
# content.list   -> export backup item list (vra content list)
# *.log          -> export backup logs
# *.zip          -> export backup content
# *.detail.list  -> list of other content to export into text files
# *.detail       -> content exported into text files
### EXAMPLE FOR DIFFING BACKUPS ###############################################
# diff -y --suppress-common-lines -x *.log -x *.zip -x *.history -r 20180318-2027 20180318-2038 
###############################################################################

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
BDIR=/home/chris/vra-backup
KEEPGEN=30
DATE=$(date '+%Y%m%d-%H%M')
CC=/usr/local/bin/cloudclient

### PREP NAMED PIPE ###########################################################
test -d $BDIR/$DATE || mkdir -p $BDIR/$DATE

cd $BDIR
rm -fr $BDIR/IN $BDIR/OUT $BDIR/logs >/dev/null 2>&1
touch $BDIR/OUT ; chmod 0700 OUT
mkfifo $BDIR/IN || exit 1
chmod 0700 OUT
( while true ; do exec 5>$BDIR/IN ; done ) &
IN_PID=$!
screen -d -m -S CC-SCREEN-TMP bash -c "cd $BDIR/$DATE && $CC < $BDIR/IN | tee -a $BDIR/OUT" &
sleep 3

cc(){
  >$BDIR/OUT
  echo "$*
  #DONE-DONE">$BDIR/IN
  tail -f $BDIR/OUT | while read line ; do echo $line | grep -q 'DONE-DONE' && break ; done
  sleep 0.1
  cat $BDIR/OUT | strings | egrep -v 'CloudClient>|DONE-DONE|Output written to'
}

### PROGRAM STARTS HERE #######################################################
# make sure cloudclient is ready for exporting content
cc vra version

cd $BDIR/$DATE
logger -t $(basename $0) "cloud client backup started"

echo "vra content list --format csv --pageSize 1000" >> cc.history
cc vra content list --format csv --pageSize 1000 2>&1 | sed -n '/^id,/,$p' | grep ',.*,.*,'  > content.list
[ $? -eq 0 ] && RC_STATUS='SUCCESS' || RC_STATUS='FAIL'
logger -t $(basename $0) "exported content.list with status $RC_STATUS"

# id,contentId,name,contentTypeId
cat content.list | sed '1d' | while read content
do
   content_id="$(echo $content | cut -d, -f1)"
   content_type="$(echo $content | cut -d, -f4)"
   content_name="$(echo $content | cut -d, -f2)"
   echo "cc vra content export --path ./ --type $content_type --secure no --id $content_id" >> cc.history
   cc vra content export --path ./ --type $content_type --secure no --id $content_id 2>&1 > $content_type-$content_name-export.log
   [ $? -eq 0 ] && RC_STATUS='SUCCESS' || RC_STATUS='FAIL'
   logger -t $(basename $0) "exported: $content_type / $content_name with status $RC_STATUS"
done

echo '
# type, id_colum, name_colum, detail_cmd
entitlement,1,2,vra entitlement detail --id __ID__
approvalpolicy,2,1,vra approvalpolicy detail --id __ID__
fabricgroup,2,1,vra fabricgroup detail --id __ID__
blueprint,1,2,vra blueprint detail --id __ID__
businessgroup,2,1,vra businessgroup detail --id __ID__
catalog,1,4,vra catalog detail --id __ID__
reservation,2,1,vra reservation detail --id __ID__
endpoint,1,2,vra endpoint export --filename endpoint.detail
entitlement,1,2,vra entitlement detail --id __ID__
machineprefix,1,2,vra machineprefix list
machines,4,1,vra machines detail --id __NAME__
' | egrep -v '^$|^#' | while read item
do
   item_type="$(echo $item | cut -d, -f1)"
   id_col="$(echo $item | cut -d, -f2)"
   name_col="$(echo $item | cut -d, -f3)"
   list_cmd="vra $item_type list --format csv --pageSize 1000"
   echo "cc $list_cmd" >> cc.history
   cc $list_cmd 2>/dev/null | egrep '..*,..*'  | egrep -v '^vRA |^IaaS |^VCO | ERROR '> $item_type.detail.list
   item_count="$(cat $item_type.detail.list | grep ',' | wc -l)"
   if [ $item_count -gt 1 ]
   then
     cat $item_type.detail.list | sed '1d' | while read element
     do
       element_id="$(echo $element | cut -d, -f$id_col)"
       element_name="$(echo $element | cut -d, -f$name_col)"
       element_cmd=$(echo $item | cut -d, -f4 | sed "s/__ID__/\"$element_id\"/g;s/__NAME__/\"$element_name\"/g")
       echo "cc $element_cmd" >> cc.history
       echo "# TYPE=$item_type / NAME=$element_name / ID=$element_id" > $item_type-$element_name.detail
       cc $element_cmd 2>/dev/null >> $item_type-$element_name.detail
       [ $? -eq 0 ] && RC_STATUS='SUCCESS' || RC_STATUS='FAIL'
       logger -t $(basename $0) "detail log export of: $content_type / $element_name with status $RC_STATUS"
     done
   fi
done

### EXPORTING SPECIAL CONTENT #################################################
cc vra logs recentevents --pageSize 1000000 --format csv > vra-logs-recentevents.log

# create full backup package for easy restore
content_ids="$(cat content.list | sed '1d' | cut -d, -f1 | tr '\n' ',' | sed 's/,$//')"
cc vra package list --format csv --pageSize 1000 > vra-package.list
if [ $(cat vra-package.list | grep cc-vra-content-package | wc -l) -gt 0 ] #found old backup package, we need to remove first
then
   logger -t $(basename $0) "WARN: found old content package, we delete before next export"
   cc vra package delete --pkgId $(cat vra-package.list | grep cc-vra-content-package | cut -d, -f1) >> vra-package.list.log
fi
cc vra package create --name cc-vra-content-package --ids $content_ids >> vra-package.list.log
cc vra package list --format csv --pageSize 1000 > vra-package.list
cc vra package export --path ./ --pkgId $(cat vra-package.list | grep cc-vra-content-package | cut -d, -f1) >> vra-package.list.log
cc vra package delete --pkgId $(cat vra-package.list | grep cc-vra-content-package | cut -d, -f1) >> vra-package.list.log


logger -t $(basename $0) "cloud client backup fineshed"

logger -t $(basename $0) "deleting backups down to $KEEPGEN generations"
cd $BDIR || exit 1
ls -1d * | egrep -x "^2.......-....$" | head -n-$KEEPGEN | while read DEL_BKP
do
   logger -t $(basename $0) "deleting backup $BDIR/$DEL_BKP"
   rm -rf $BDIR/$DEL_BKP 
done

cd $BDIR
kill $IN_PID 
screen -wipe CC-SCREEN-TMP >/dev/null 2>&1
rm -fr $BDIR/IN $BDIR/OUT $BDIR/logs >/dev/null 2>&1

### SOME NOTES
# required --ids: Comma separated list of content ids (the id field); no default value
# vra package create --name full-export --ids
