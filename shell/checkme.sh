#!/bin/bash
# DESC: check me is a quick and dirty way to check machines health
# $Revision: 1.2 $
# $RCSfile: checkme.sh,v $
# $Author: chris $
##########################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

# just archive all the gschnabu
LOGFILE=/var/log/`basename $0`.log
# hold the actual alarms from this scan
TMPFILE=/tmp/`basename $0`-`echo $$`.tmp
# hold the alarmtime and alarms, i have already sent
CACHEFILE=/var/run/`basename $0`.tmp

# just have a clean start
ALARM=0
RESEND=0
ALARMED=0
OLDALARM=0

# syntax: cat alarms.txt | $SMSSEND $MOBILE
SMSSEND=/usr/local/bin/sms.rb
MOBILE='+41791112233'
#dont resend alarms to fast (minutes)
TIMEOUT=1440

##########################################################################################################
DISKFULL='85;/'

#HOST-PORT;DEST-HOST;DEST-PORT
TCP=''

PROCMAX=200
LSOF=5000
LISTENPORT=12
OPENTCP=100
OPENUDP=50
SWAPMAX=80
MAXMAIL=300

# chkconfig --list | grep :on | awk '{print $1";service "$1" status;0" }'
#ALARM_NAME;CHECK_CMD;DESIRED_RET_CODE
RETCODE='crond;pgrep -uroot cron;0
firewall;iptables-save|grep "A INPUT";0
knockd;pgrep -uroot knockd;0
network;ifconfig -a eth0|grep errors:0|wc -l|grep 2;0
ntpd;pgrep -untp ntpd;0
sshd;lsof -i :44444 | grep sshd | grep LISTEN;0
syslog;pgrep -uroot syslogd;0
postfix;lsof -i :25 | grep master | grep LISTEN;0
gld;lsof -i :2525 >/dev/null;0
saslauthd;pgrep -uroot saslauthd;0
dovecot;lsof -i :110 | grep dovecot | grep LISTEN;0
vsftpd;lsof -i :21 | grep vsftpd | grep LISTEN;0
httpd;lsof -i :80 | grep -q LISTEN;0
httpsd;lsof -i :443 | grep -q LISTEN;0
mysqld;/etc/init.d/mysql status;0'

#spamassassin;pgrep -u root spamd;0
##########################################################################################################
# initialize and create tmp files
touch $CACHEFILE >/dev/null 2>&1
touch $TMPFILE >/dev/null 2>&1
touch $LOGFILE >/dev/null 2>&1
##########################################################################################################
# do i have to resend pending alarms?
SECONDS=`date '+%s'`
let "MINUTES = $SECONDS / 60"
OLDALARM=`grep 'ALARM;' $CACHEFILE | cut -d\; -f2`
if [ "$OLDALARM" == "" ]
then
   OLDALARM=1
fi
let "ALARMDIFF = $MINUTES - $OLDALARM"
if [ "$ALARMDIFF" -gt "$TIMEOUT" ]
then
   RESEND=1
fi
let "ALARMGRACE = $TIMEOUT - $ALARMDIFF"
##########################################################################################################
echo "$*" | grep -q '\-v'
if [ "$?" == "0" ]
then
   DEBUG=1
else
   DEBUG=0
fi

db () {
       if [ "$DEBUG" == "1" ]
       then
          echo "$*"
       fi
       }
##########################################################################################################
alarm () {
          if [ "$ALARMED" == "0" ]
	  then
	     ALARM=1
	  fi
	  if [ "$ALARMED" == "1" -a "$RESEND" == "1" ]
	  then
	     ALARM=1
	  fi
          }
##########################################################################################################
#DISKFULL
db "Checking DISKFULL"
for DF in `echo "$DISKFULL"`
do
   DF1=`echo $DF | cut -d\; -f1`
   DF2=`echo $DF | cut -d\; -f2`
   TDF=`df -P $DF2 |tail -1 | awk '{print $5}' | cut -d% -f1`
   if [ "$TDF" -gt "$DF1" ]
   then
      echo "   $DF2 is $TDF % full, alarm mark is $DF1 % "
      echo "DF;$DF2;$TDF" >> $TMPFILE
      ALARMED=0
      grep -q "DF;$DF2;" $CACHEFILE && ALARMED=1
      alarm
   else
      db "   $DF2 is $TDF % full, alarm mark is $DF1 % "
   fi
done
##########################################################################################################
#TCP PORT CHECK
db "Checking TCP PORTs"
for HOSTPORT in `echo "$TCP" | cut -d\; -f1`
do
   HOST=$(echo "$TCP" | grep "^$HOSTPORT;" | cut -d\; -f2)
   PORT=$(echo "$TCP" | grep "^$HOSTPORT;" | cut -d\; -f3)
   nc -w 10 -z "$HOST" "$PORT" >/dev/null 2>&1
   CHECK="$?"
   if [ "$CHECK" -eq "0" ]
   then
      STATE="OK"
   else
      STATE="ERR"
   fi
   if [ "$CHECK" -ne "0" ]
   then
      echo "   tcp port $PORT of host $HOST is $STATE"
      echo "TCP;$HOSTPORT;$STATE" >> $TMPFILE
      ALARMED=0
      grep -q "TCP;$HOSTPORT;" $CACHEFILE && ALARMED=1
      alarm
   else
      db "   tcp port $PORT of host $HOST is $STATE"
   fi
done
##########################################################################################################
#PROCMAX
db "Checking PROCMAX"
TPROCMAX=`ps -e | wc -l`
if [ "$TPROCMAX" -gt "$PROCMAX" ]
then
   echo "   there are $TPROCMAX processes running, alarm mark is $PROCMAX"
   echo "PROCMAX;$TPROCMAX" >> $TMPFILE
   ALARMED=0
   grep -q PROCMAX $CACHEFILE && ALARMED=1
   alarm
else
   db "   there are $TPROCMAX processes running, alarm mark is $PROCMAX"
fi
##########################################################################################################
#LSOF
db "Checking LSOF"
TLSOF=`lsof | wc -l`
if [ "$TLSOF" -gt "$LSOF" ]
then
   echo "   i have $TLSOF open files, alarm mark is $LSOF"
   echo "LSOF;$TLSOF" >> $TMPFILE
   ALARMED=0
   grep -q LSOF $CACHEFILE && ALARMED=1
   alarm
else
   db "   i have $TLSOF open files, alarm mark is $LSOF"
fi
##########################################################################################################
#LISTENPORT
db "Checking LISTENPORTs"
TLISTENPORT=`lsof -iTCP -n | grep LISTEN | awk '{print $8}' | sort -u | wc -l`
if [ "$TLISTENPORT" -gt "$LISTENPORT" ]
then
   echo "   i have $TLISTENPORT open tcp ports, alarm mark is $LISTENPORT"
   echo "LISTENPORT;$TLISTENPORT" >> $TMPFILE
   ALARMED=0
   grep -q LISTENPORT $CACHEFILE && ALARMED=1
   alarm
else
   db "   i have $TLISTENPORT open tcp ports, alarm mark is $LISTENPORT"
fi
##########################################################################################################
#OPENTCP
db "Checking OPENTCP"
TOPENTCP=`lsof -iTCP -n | grep -v 'LISTEN' | wc -l`
if [ "$TOPENTCP" -gt "$OPENTCP" ]
then
   echo "   there are $TOPENTCP open tcp connections, alarm mark is $OPENTCP"
   echo "OPENTCP;$TOPENTCP" >> $TMPFILE
   ALARMED=0
   grep -q OPENTCP $CACHEFILE && ALARMED=1
   alarm
else
   db "   there are $TOPENTCP open tcp connections, alarm mark is $OPENTCP"
fi
##########################################################################################################
#OPENUDP
db "Checking OPENUDP"
TOPENUDP=`lsof -iUDP -n | wc -l`
if [ "$TOPENUDP" -gt "$OPENUDP" ]
then
   echo "   there are $TOPENUDP udp ports, alarm mark is $OPENUDP"
   echo "OPENUDP;$TOPENUDP" >> $TMPFILE
   ALARMED=0
   grep -q OPENUDP $CACHEFILE && ALARMED=1
   alarm
else
   db "   there are $TOPENUDP udp ports, alarm mark is $OPENUDP"
fi
##########################################################################################################
db "Checking SWAP"
CSWAP="$(free | grep Swap: | awk '{print $3}')"
ASWAP="$(free | grep Swap: | awk '{print $2}')"
if [ $CSWAP -gt 0 ]
then
   TSWAP=$(echo "$CSWAP / $ASWAP * 100" | bc -l | cut -d. -f1 )
   if [ "$TSWAP" == "" ]
   then
      TSWAP=0
   fi
else
   TSWAP=0
fi
if [ $TSWAP -gt $SWAPMAX ]
then
   echo "    $TSWAP % Swap Space is used, alarm mark is $SWAPMAX"
   echo "SWAPMAX;$TSWAP" >> $TMPFILE
   ALARMED=0
   grep -q SWAPMAX $CACHEFILE && ALARMED=1
   alarm
else
   db "    $TSWAP % Swap Space is used, alarm mark is $SWAPMAX"
fi
if [ $ASWAP -eq 0 ]
then
   echo "    Total Swap Sace is $ASWAP thats ugly"
   echo "SWAPTOT;$ASWAP" >> $TMPFILE
   ALARMED=0
   grep -q SWAPTOT $CACHEFILE && ALARMED=1
   alarm
else
   db "    Total Swap Sace is $ASWAP, it must not be 0"
fi

##########################################################################################################
db "Checking MAXMAIL"
for MUSER in /var/spool/mail/*
do
   MUSER=$(basename $MUSER)
   MAIL_CNT=$(egrep -i '^Message-ID:.*>' /var/spool/mail/$MUSER | wc -l)
   if [ "$MAIL_CNT" -gt "$MAXMAIL" ]
   then
      echo "   User $(basename $MUSER) has $MAIL_CNT Mails, desired maximum is $MAXMAIL"
      echo "MAXMAIL;$MUSER;$MAIL_CNT" >> $TMPFILE
      ALARMED=0
      grep -q "MAXMAIL;$MUSER;" $CACHEFILE && ALARMED=1
      alarm
   else
      db "   User $(basename $MUSER) has $MAIL_CNT Mails, desired maximum is $MAXMAIL"      
   fi
done
##########################################################################################################
#RETCODE
db "Checking RETCODE"
for RC in `echo "$RETCODE" | cut -d\; -f1`
do
   DRC=$(echo "$RETCODE" | grep "^$RC;" | cut -d\; -f3)
   #if_no_pipe_in_cmd: $(echo "$RETCODE" | grep "^$RC;" | cut -d\; -f2) >/dev/null 2>&1
   (echo "$RETCODE" | grep "^$RC;" | cut -d\; -f2 | bash) >/dev/null 2>&1
   TRC="$?"
   if [ "$TRC" -ne "$DRC" ]
   then
      echo "   return code of $RC is $TRC, desired is $DRC"
      echo "RC;$RC;$TRC" >> $TMPFILE
      ALARMED=0
      grep -q "RC;$RC;" $CACHEFILE && ALARMED=1
      alarm
   else
      db "   return code of $RC is $TRC, desired is $DRC"
   fi
done
##########################################################################################################
#check if there are pending alarms at the moment
db "Searching for Alarms"
PALARM=$(cat $TMPFILE | wc -l)
if [ "$PALARM" -eq 0 ]
then 
   echo "---fuck, I've no alarms ;-("
else
   echo "--- yupeee, I have alarms ! ;-)"
   echo "--- ALARMS ---"
   cat $TMPFILE
   echo "--------------"
fi
if [ "$ALARMED" == "1" ]
then
   echo "--- i have old alams"
fi
##########################################################################################################
db "Alarming"
if [ "$ALARM" == "1" ]
then
   cat $TMPFILE | tail -n20 | $SMSSEND $MOBILE >/dev/null
   echo "--- alarm sent to $MOBILE"
   echo "ALARM;$MINUTES" >> $TMPFILE
   echo "ALARMTIME;`date '+%Y%m%d%H%M%S'`" >> $TMPFILE
   cat $TMPFILE | grep -v 'ALARMTIME;' > $CACHEFILE
   cat $TMPFILE | grep -v 'ALARM;' >> $LOGFILE
   echo ""
else
   grep ALARM $CACHEFILE >> $TMPFILE
   cat $TMPFILE > $CACHEFILE
   if [ "$PALARM" -ne 0 ]
   then 
      echo "--- i did not send an alarm"
      echo "    grace time is $ALARMGRACE minutes"
   fi
fi
##########################################################################################################
# this RC is totally ugly and totally cool ;)
rm -f $TMPFILE
exit $PALARM

##########################################################################################################
# $Log: checkme.sh,v $
# Revision 1.2  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:11  chris
# Initial revision
#
