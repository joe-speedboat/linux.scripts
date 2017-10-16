#!/bin/bash
# $Revision: 1.8 $
# $RCSfile: bacula-backup-report.sh,v $
# DESC: backup control job which sends a overview by mail
# WHO: crn

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

TO="appops@ticketcorner.com"
FROM="appops@ticketcorner.com"

EXCLUDE="You have messages.|Automatically selected Catalog:|Connecting to Director|1000 OK:|Enter a period|Using Catalog"
TODAY="$(date '+%Y-%m-%d')"
TMPR=/tmp/$(basename $0).tmp
ERR=0
OK=0
echo "---------- DAILY BACKUP REPORT ----------" > $TMPR
mysql bacula -t -e "select JobId AS ID, Name, Level, JobStatus AS Status, DATE_FORMAT(StartTime,'%a %H:%i') AS Start, DATE_FORMAT(RealEndTime,'%H:%i') AS End, JobFiles AS Files, ROUND((JobBytes / 1024 / 1024 ),1) AS MByte FROM Job WHERE SchedTime >= SUBDATE(NOW(),INTERVAL 1 DAY) AND Type = 'B' order by Name;" >> $TMPR
ERR=$(cat $TMPR | grep '| E      |' | wc -l)
OK=$(cat $TMPR | grep '| T      |' | wc -l)

mysql bacula -t -e  "select JobStatus, JobStatusLong AS Beschreibung from Status;" >> $TMPR

echo "" >> $TMPR
echo "" >> $TMPR
echo "---------- POOL STATUS ----------" >> $TMPR
mysql bacula -t -e "select Name,NumVols,MaxVols,ROUND((VolRetention / 3600 / 24),0) AS 'Retention(d)',ROUND((MaxVolBytes / 1000000000),0) AS 'VolSize(GB)' from Pool;" >> $TMPR
echo "" >> $TMPR
echo "" >> $TMPR
echo "---------- MEDIA STATUS ----------" >> $TMPR
mysql bacula -t -e "select Media.MediaId,Media.VolumeName,Media.VolStatus,DATE_FORMAT(Media.FirstWritten,'%Y-%m-%d') AS FirstWritten,DATE_FORMAT(Media.LastWritten,'%Y-%m-%d') AS LastWritten,Pool.Name AS PoolName from Media,Pool WHERE (Media.PoolID = Pool.PoolID) ORDER BY VolumeName;" >> $TMPR

# search for media errors
MERR="$(mysql bacula -e "select MediaId,VolumeName,VolStatus FROM Media WHERE VolStatus = 'Error';" | wc -l)"
ERR=$(($ERR + $MERR))

SUBJ="Bacula Backup Report: ERR=$ERR / OK=$OK from $TODAY on $(uname -n)"


echo -e "Mime-Version: 1.0
Content-type: text/html; charset=\"utf-8\"
From: $FROM
To: $(echo $TO | sed -e 's/ /; /g')
Subject: $SUBJ
<html><body><pre>
$(cat $TMPR)
</pre></body></html>
"| sendmail -f $FROM $TO
rm -f $TMPR

################################################################################
# $Log: bacula-backup-report.sh,v $
# Revision 1.8  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.7  2010/04/20 06:16:57  chris
# email fromat changed to html
#
# Revision 1.6  2010/03/25 06:59:33  chris
# typo corrected
#
# Revision 1.5  2010/03/25 06:55:30  chris
# date format in pool statistic optimized
# subject optimized for filtering
#
# Revision 1.4  2010/03/24 12:14:35  chris
# also watch for media errors
#
# Revision 1.3  2010/03/24 11:05:09  chris
# comlete rewritten with mysql query for daily report
#
# Revision 1.2  2010/03/19 20:54:25  chris
# update from working release
#
# Revision 1.1  2010/01/17 20:40:10  chris
# Initial revision
#
