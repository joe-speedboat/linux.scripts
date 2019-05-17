#!/bin/bash
# DESC: VCSA 6.7 scp backup
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

##### EDITABLE BY USER to specify vCenter Server instance and backup destination. #####
VC_ADDRESS='vcenter1.lab.local'
VC_USER='root'
VC_PASSWORD='root.secret'
BACKUP_ADDRESS='192.168.10.55'
BACKUP_USER='vbackup'
BACKUP_PASSWORD='backup.secret'
BACKUP_FOLDER="/home/vbackup/vcenter1.lab.local/2018-03-08-13-40-22"
TIME=$(date +%Y-%m-%d-%H-%M-%S)
############################

# Create a message body for the restore request.
cat << EOF > task.json
{ "piece":
    {
        "location_type":"SCP",
        "ignore_warnings": true,
        "location":"scp://$BACKUP_ADDRESS/$BACKUP_FOLDER",
        "location_user":"$BACKUP_USER",
        "location_password":"$BACKUP_PASSWORD"
    }
}
EOF

# Issue a request to start the restore operation.
echo Starting restore $TIME $VC_B64_PASS >> restore.log
curl -s -k -u "$VC_USER:$VC_PASSWORD" \
  -H 'Accept:application/json' \
  -H 'Content-Type:application/json' \
  -X POST \
  "https://$VC_ADDRESS:5480/rest/appliance/recovery/restore/job" \
  --data @task.json 2>restore.log >response.txt
cat response.txt >> restore.log
echo '' >> restore.log

# Monitor progress of the operation until it is complete.
STATE=STARTING
PROGRESS=0
MISSING_ANSWER=0 # sometimes API does not respond while restore is running
until [ "$STATE" != "INPROGRESS" -a "$STATE" != "STARTING" ]
do
    echo "Restore job state: $STATE ($PROGRESS%)"
    sleep 5s
    curl -s -k -u "$VC_USER:$VC_PASSWORD" \
      -H 'Accept:application/json' \
      -H 'Content-Type:application/json' \
      -X GET \
      "https://$VC_ADDRESS:5480/rest/appliance/recovery/restore/job" \
      >response.txt
    cat response.txt >> restore.log
    echo '' >> restore.log
    PROGRESS=$(awk \
               '{if (match($0,/"progress":\w+/)) print substr($0, RSTART+11,RLENGTH-11);}' \
               response.txt)
    STATE=$(awk \
            '{if (match($0,/"state":"\w+"/)) print substr($0, RSTART+9, RLENGTH-10);}' \
            response.txt)
    if [ $MISSING_ANSWER -lt 4 -a "x$STATE" == "x" ] ; then
       MISSING_ANSWER=$((MISSING_ANSWER+1))
       STATE="INPROGRESS"
       PROGRESS=".."
    fi
done
# Report job completion and clean up temporary files.
echo ''
echo Restore job has finished
rm -f task.json
rm -f response.txt
echo '' >> restore.log
echo
echo "For more details about restore, check the vCSA restore log:
      $VC_USER@$VC_ADDRESS:/storage/log/vmware/applmgmt/backupRestoreAPI.log"
echo "============= restore.log ============="
cat restore.log

