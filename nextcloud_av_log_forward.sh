# WHO: Zottel @ uQc
# 2021.04.08
# DESC: scan nextcloud logs for AV events and forward to specific email
#       run this as a cron job on a regular base
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
set -e

TO="chris@bitbull.ch"
FROM="$TO"
SUBJECT="Nextcloud virus found at $(hostname -f)"
LOGF=/nextcloud/snbpoc2/nextcloud.log

PATTERN='Infected file'
UNIQ_ID="reqId"

LOGT=$LOGF.logtail #here we store logfile size
test -r $LOGF || (echo ERROR: can not read $LOGF ; exit 1)
test -e $LOGT || echo 0 > $LOGT || (echo ERROR: can not write $LOGT ; exit 1)
LOFFSET=`cat $LOGT` # get last run logfile size
COFFSET=`cat $LOGF | wc -c` # get current logfile size
[ $COFFSET -eq $LOFFSET ] && exit 0 # logfile has same size as last run, do nothing
[ $COFFSET -lt $LOFFSET ] && LOFFSET=0 # file is smaller than last time, we assume it got tuncated
echo $COFFSET > $LOGT || (echo ERROR: can not write $LOGF ; exit 1) # write new file size

# log events into variable
MSG="$(cat $LOGF | dd  bs=1 skip=$LOFFSET conv=noerror 2>/dev/null | cat | strings | grep "$PATTERN" )"

# print deduped messages for each UNIQ_ID
(
echo "Subject: $SUBJECT"

echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
echo $MSG | jq ".$UNIQ_ID" | sort -u | while read ID
do
  echo $MSG | jq "select(.$UNIQ_ID=="$ID")" | jq -s '.[0]'
  echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
done

) | sendmail -f "$FROM" -t "$TO"

