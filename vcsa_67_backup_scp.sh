#!/bin/bash
# DESC: VCSA 6.7 scp backup
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
# INSPIRED BY: https://pubs.vmware.com/vsphere-6-5/index.jsp?topic=%2Fcom.vmware.vsphere.vcsapg-rest.doc%2FGUID-222400F3-678E-4028-874F-1F83036D2E85.html 

# YOU CAN ADD THIS TO CRON ON DESTINATION SERVER ######################################
# chmod 0700 /home/vbackup/bin/vcsa_67_backup_scp.sh
# crontab -e $BACKUP_USER
# 1 2 * * * /home/vbackup/bin/vcsa_67_backup_scp.sh

##### EDITABLE BY USER to specify vCenter Server instance and backup destination. #####
VC_ADDRESS='vcenter1.example.com'
VC_USER='administrator@vsphere.local'
VC_PASSWORD='letmein!'
BACKUP_ADDRESS='192.168.10.55'
BACKUP_USER='vbackup'
BACKUP_PASSWORD='backmeup!'
BACKUP_FOLDER="/home/$BACKUP_USER/$VC_ADDRESS"
TIME=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_INVENTORY="$BACKUP_FOLDER/$TIME/*/*/*/backup-metadata.json"
BACKUP_KEEP=2 # keep this amount of backups in place
############################

# Create Backup Folder
test -d "$BACKUP_FOLDER/$TIME" || mkdir -p "$BACKUP_FOLDER/$TIME"

# Authenticate with basic credentials.
curl -s -u "$VC_USER:$VC_PASSWORD" \
   -X POST \
   -k --cookie-jar cookies.txt \
   "https://$VC_ADDRESS/rest/com/vmware/cis/session"

# Create a message body for the backup request.
cat << EOF >task.json
{ "piece":
     {
         "location_type":"SCP",
         "comment":"Automatic backup",
         "parts":["seat"],
         "location":"scp://$BACKUP_ADDRESS$BACKUP_FOLDER/$TIME",
         "location_user":"$BACKUP_USER",
         "location_password":"$BACKUP_PASSWORD"
     }
}
EOF

# Issue a request to start the backup operation.
logger -t $(basename $0) "Starting backup $TIME"
curl -s -k --cookie cookies.txt \
   -H 'Accept:application/json' \
   -H 'Content-Type:application/json' \
   -X POST \
   --data @task.json 2>>response.err >response.txt \
   "https://$VC_ADDRESS/rest/appliance/recovery/backup/job"
cat response.err | logger -t $(basename $0)
cat response.txt | logger -t $(basename $0)

# Parse the response to locate the unique identifier of the backup operation.
ID=$(awk '{if (match($0,/"id":"\w+-\w+-\w+"/)) \
          print substr($0, RSTART+6, RLENGTH-7);}' \
         response.txt)
logger -t $(basename $0) "Backup job id: $ID"

# Monitor progress of the operation until it is complete.
PROGRESS=INPROGRESS
until [ "$PROGRESS" != "INPROGRESS" ]
do
     sleep 10s
     curl -s -k --cookie cookies.txt \
       -H 'Accept:application/json' \
       --globoff \
       "https://$VC_ADDRESS/rest/appliance/recovery/backup/job/$ID" \
       >response.txt
     cat response.txt | logger -t $(basename $0)
     PROGRESS=$(awk '{if (match($0,/"state":"\w+"/)) \
                     print substr($0, RSTART+9, RLENGTH-10);}' \
                    response.txt)
     echo "Backup job state: $PROGRESS"
     logger -t $(basename $0) "Backup job state: $PROGRESS"
done

# Report job completion and clean up temporary files.
logger -t $(basename $0) "Backup job completion status: $PROGRESS"
rm -f task.json
rm -f response.txt
rm -f response.err
rm -f cookies.txt

if [ "$PROGRESS" == "SUCCEEDED" ]
then
  egrep 'BackupSize|StartTime|Duration|EndTime' $BACKUP_INVENTORY | sed 's/["|,]//g' | logger -t $(basename $0)
  logger -t $(basename $0) "INFO: removing old backups if needed. We keep $BACKUP_KEEP of them"
  test -d $BACKUP_FOLDER || exit 1
  ls -1d $BACKUP_FOLDER/*-*-*-*-* | sort -n | head -n-$BACKUP_KEEP | xargs rm -frv | logger -t $(basename $0)
  echo "--------- RESTORE INFORMATION ---------"
  echo "   LOCATION: scp://$BACKUP_ADDRESS$BACKUP_FOLDER/$TIME"
  echo "   USER: $BACKUP_USER"
  logger -t $(basename $0) "RESTORE_INFORMATION: LOCATION: scp://$BACKUP_ADDRESS$BACKUP_FOLDER/$TIME -- USER: $BACKUP_USER"
  logger -t $(basename $0) "INFO: backup finished"
  echo "INFO: backup finished"
else
  echo "ERROR: backup failed, please check syslog"
  logger -t $(basename $0) "ERROR: backup failed"
fi

