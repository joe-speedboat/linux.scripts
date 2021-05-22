#!/bin/bash
#########################################################################################
# DESC: nextcloud webdav benchmark testet with v21
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# HOW IT WORKS:
# 1) upload one big file
# 2) download one big file
# 3) upload many small files
# 4) download many small files
# 5) download previous result file from nextcloud if it exists
# 6) add the results to the result file
# 7) upload the results to nextcloud
# 8) cleanup the files
#
# INSTALL:
#   1) curl https://raw.githubusercontent.com/joe-speedboat/shell.scripts/master/nc_benchmark.sh > /usr/local/sbin/nc_benchmark.sh
#   2) chmod 700 /usr/local/sbin/nc_benchmark.sh
#   3) vim /usr/local/sbin/nc_benchmark.sh # Fill at least this vars
#         CLOUD
#         PW
#         USR
#   4) /usr/local/sbin/nc_benchmark.sh
#   5) optionally create cronjob to update results on a sheduled base
#   6) optionally create config file to source the settings $SCRIPT_NAME.conf

# USEAGE:
#         nc_benchmark.sh


# custom vars ---------------
CLOUD=cloud.domain.com
USR="chris"
PW="8M8BG-xxx-4jWHR"
TEST_BLOCK_SIZE_MB=150
TEST_FILES_COUNT=100
BENCH_DIR="bench"
SPEED_LIMIT_UP=4G
SPEED_LIMIT_DOWN=4G
LOCAL_DIR="$HOME/.nc/$CLOUD"
# ---------------------------

cd $(dirname $0)

if [ -r "$1" ]
then
   echo "INFO: reading external config file: $(basename $0).conf"
   source "$1"
elif [ -r "$(basename $0).conf" ]
then
   echo "INFO: reading external config file: $(basename $0).conf"
   source "$(basename $0).conf"
fi

# static vars
BURL="https://$CLOUD"
DAV_BASE_DIR="remote.php/dav"
DAV_FILE_DIR="files/$USR"
DAV_TRASH_DIR="trashbin/$USR/trash"
DAV_FILE_URL="$BURL/$DAV_BASE_DIR/$DAV_FILE_DIR"
DAV_TRASH_URL="$BURL/$DAV_BASE_DIR/$DAV_TRASH_DIR"
DAV_REMOTE_BENCH_DIR="$DAV_FILE_URL/$BENCH_DIR"
LOCAL_LOG_FILE="$LOCAL_DIR/$BENCH_DIR.txt"
CURL="curl -k -s -u$USR:$PW"
UL_BLOCK_ASSEMBLING_MAX_WAIT=60

echo INFO: LOCAL_LOG_FILE=$LOCAL_LOG_FILE
cat $LOCAL_LOG_FILE || true

# prepare local benchmark dirs
mkdir -p "$LOCAL_DIR/small_files"

touch "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb"
if [ $(( $(stat --printf="%s" "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb" ) / 1024 / 1024 )) -ne $TEST_BLOCK_SIZE_MB ]
then
   echo INFO: create $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb with random data
   dd if=/dev/urandom of="$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb" bs=1M count=$TEST_BLOCK_SIZE_MB >/dev/null 2>&1
   echo INFO: generating md5sum of $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb
   md5sum "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb" > "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum"
   ls -l $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb > "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.ls"
fi

for i in $(seq 1 $TEST_FILES_COUNT)
do
   # echo INFO: $LOCAL_DIR/small_files/$i.txt
   date > $LOCAL_DIR/small_files/$i.txt
done

# prepare remote benchmark dirs
cat "$LOCAL_LOG_FILE" 2>/dev/null | grep -q DATE || echo '#DATE;BURL;USER;<UPLOAD|DOWNLOAD>;TEST;ERRORS;RESULTS;SPEED_LIMIT' >  $LOCAL_LOG_FILE
$CURL "$DAV_REMOTE_BENCH_DIR/small_files/0.txt"  >/dev/null 2>&1 && $CURL -X DELETE "$DAV_REMOTE_BENCH_DIR/small_files/" >/dev/null 2>&1
$CURL -X MKCOL "$DAV_REMOTE_BENCH_DIR" >/dev/null 2>&1
$CURL -X MKCOL "$DAV_REMOTE_BENCH_DIR/small_files" >/dev/null 2>&1
$CURL -X DELETE "$DAV_REMOTE_BENCH_DIR/$TEST_BLOCK_SIZE_MB.mb" >/dev/null 2>&1

# run block upload test
echo upload $TEST_BLOCK_SIZE_MB MB starting: $(date '+%Y.%m.%d %H:%M:%S')
UL_BLOCK_SPEED=$($CURL --limit-rate $SPEED_LIMIT_UP -w '%{speed_upload}' -T "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb" "$DAV_REMOTE_BENCH_DIR/" | cut -d. -f1)
UL_BLOCK_SPEED=$(( $UL_BLOCK_SPEED / 1024 )) # kbyte per sec
echo upload $TEST_BLOCK_SIZE_MB MB finished: $(date '+%Y.%m.%d %H:%M:%S')
D="$(date '+%Y.%m.%d %H:%M:%S')"
echo "$D;$BURL;$USR;UPLOAD;Block $TEST_BLOCK_SIZE_MB MB;;$UL_BLOCK_SPEED KByte/s;$SPEED_LIMIT_UP" >>  $LOCAL_LOG_FILE

# wait for block test to get assempled on nextcloud
UL_BLOCK_ASSEMBLING_START=$(date +%s)
echo wait for $TEST_BLOCK_SIZE_MB.mb to get assembled on nextcloud
for i in $(seq 1 $UL_BLOCK_ASSEMBLING_MAX_WAIT)
do
  $CURL -X PROPFIND "$DAV_REMOTE_BENCH_DIR" | sed "s|$(echo $DAV_REMOTE_BENCH_DIR | rev | cut -d/ -f-3 | rev)/|\n|g" | sed 's|<.*||;/^$/!p' | sort -u | grep '[a-zA-Z0-9]' | grep "^$TEST_BLOCK_SIZE_MB.mb$" && break
  sleep 1
  echo -n .
done
UL_BLOCK_ASSEMBLING_SEC=$(( $(date '+%s') - $UL_BLOCK_ASSEMBLING_START))
if [ $UL_BLOCK_ASSEMBLING_SEC -ge $UL_BLOCK_ASSEMBLING_MAX_WAIT ]
then
   UL_BLOCK_ASSEMBLING_SEC="timeout_error"
fi
D="$(date '+%Y.%m.%d %H:%M:%S')"
echo "$D;$BURL;$USR;UPLOAD;Assembling time $TEST_BLOCK_SIZE_MB.mb;;$UL_BLOCK_ASSEMBLING_SEC sec" >>  $LOCAL_LOG_FILE

# run block download test
test -f "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.download" && rm -f "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.download"
echo download $TEST_BLOCK_SIZE_MB MB starting: $(date '+%Y.%m.%d %H:%M:%S')
DL_BLOCK_SPEED=$($CURL --limit-rate $SPEED_LIMIT_DOWN -w '%{speed_download}' "$DAV_REMOTE_BENCH_DIR/$TEST_BLOCK_SIZE_MB.mb" -o "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.download" | cut -d. -f1)
DL_BLOCK_SPEED=$(( $DL_BLOCK_SPEED / 1024 )) # kbyte per sec
D="$(date '+%Y.%m.%d %H:%M:%S')"
echo "$D;$BURL;$USR;DOWNLOAD;Block $TEST_BLOCK_SIZE_MB MB;;$DL_BLOCK_SPEED KByte/s;$SPEED_LIMIT_DOWN" >>  $LOCAL_LOG_FILE
echo download $TEST_BLOCK_SIZE_MB MB finished: $(date '+%Y.%m.%d %H:%M:%S')
md5sum "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.download" > "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum.download"
ls -l $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.download > "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.ls.download"
echo "------ DETAILS BEFORE UPLOAD BIG FILE ------"
cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum
cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.ls
echo "------ DETAILS AFTER DOWNLOAD BIG FILE ------"
cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum.download
cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.ls.download

if [ $(cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum.download | cut -d\  -f1) != $(cat $LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.md5sum | cut -d\  -f1) ]
then 
   DL_BLOCK_SPEED="md5sum error"
fi

# run small file upload test
UL_ERROR_CNT=0
TIME_BEFORE=$(date '+%s')
for i in $(seq 1 $TEST_FILES_COUNT)
do
   echo upload file $i.txt | egrep '[0-9]0.txt'
   $CURL  -T "$LOCAL_DIR/small_files/$i.txt" "$DAV_REMOTE_BENCH_DIR/small_files/"
   if [ $? -ne 0 ] ; then
      echo "error: could not upload $i.txt"
      UL_ERROR_CNT=$(($UL_ERROR_CNT+1))
   fi
done
UL_FILES_TIME=$(( $(date '+%s') - $TIME_BEFORE))
D="$(date '+%Y.%m.%d %H:%M:%S')"
echo "$D;$BURL;$USR;UPLOAD;$TEST_FILES_COUNT small Files;$UL_ERROR_CNT;$UL_FILES_TIME sec" >>  $LOCAL_LOG_FILE

# run small file download test
DL_ERROR_CNT=0
TIME_BEFORE=$(date '+%s')
for i in $(seq 1 $TEST_FILES_COUNT)
do
   echo download file $i.txt | egrep '[0-9]0.txt'
   $CURL  -o "$LOCAL_DIR/small_files/$i.txt" "$DAV_REMOTE_BENCH_DIR/small_files/$i.txt"
   if [ $? -ne 0 ] ; then
      echo "error: could not download $i.txt"
      DL_ERROR_CNT=$(($DL_ERROR_CNT+1))
   fi
done
DL_FILES_TIME=$(( $(date '+%s') - $TIME_BEFORE))
D="$(date '+%Y.%m.%d %H:%M:%S')"
echo "$D;$BURL;$USR;DOWNLOAD;$TEST_FILES_COUNT small Files;$DL_ERROR_CNT;$DL_FILES_TIME sec" >>  $LOCAL_LOG_FILE


echo BURL=$BURL
echo TEST_BLOCK_SIZE_MB=$TEST_BLOCK_SIZE_MB
echo UL_BLOCK_SPEED=$UL_BLOCK_SPEED KByte/s
echo UL_BLOCK_ASSEMBLING_SEC=$UL_BLOCK_ASSEMBLING_SEC sec
echo DL_BLOCK_SPEED=$DL_BLOCK_SPEED KByte/s
echo TEST_FILES_COUNT=$TEST_FILES_COUNT
echo DL_ERROR_CNT=$DL_ERROR_CNT
echo UL_ERROR_CNT=$UL_ERROR_CNT
echo UL_FILES_TIME=$UL_FILES_TIME sec
echo DL_FILES_TIME=$DL_FILES_TIME sec
echo SPEED_LIMIT_DOWN=$SPEED_LIMIT_DOWN
echo SPEED_LIMIT_UP=$SPEED_LIMIT_UP


echo uploading results: $LOCAL_LOG_FILE to $DAV_FILE_URL/
$CURL  -T "$LOCAL_LOG_FILE" "$DAV_FILE_URL/"
echo "cleaning up test files"
echo "   delete directory: $BENCH_DIR"
$CURL -X DELETE "$DAV_REMOTE_BENCH_DIR/" >/dev/null 2>&1
sleep 5
$CURL -X PROPFIND "$DAV_TRASH_URL" | sed "s|$DAV_TRASH_DIR/|\n|g" | sed 's|<.*||;/^$/!p' | sort -u | grep '[a-zA-Z0-9]' | egrep "^$BENCH_DIR" | while read TRASH_FILE_TO_DELETE
do
  $CURL -X DELETE "$DAV_TRASH_URL/$TRASH_FILE_TO_DELETE"
  echo "   delete trash object: ${TRASH_FILE_TO_DELETE}"
done
rm -f "$LOCAL_DIR/$TEST_BLOCK_SIZE_MB.mb.*.download"
rm -fr "$LOCAL_DIR/small_files"
echo done

