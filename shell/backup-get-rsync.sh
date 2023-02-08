#!/bin/bash
# DESC: simple backup collector via rsync and public keys
# $Author: chris $
# $Revision: 1.3 $
# $RCSfile: backup-get-rsync.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

CONF=/etc/backup-get-rsync.conf
DATE=$(date '+%Y%m%d%H%M%S')

# check if config file is present
test -f $CONF
if [ $? -ne 0 ] ; then
echo '################################################################################
# DESC: conf file for backup-get-rsync.sh
################################################################################
# destination to save data in
DEST=/data
# user to connect rsync clients
USER=root
# ssh wrapper cmd for rsync
SSH="/usr/bin/ssh -c blowfish -p22 -i /root/.ssh/id_dsa"
# backup jobs to get data from
# host:/dir/to/save:generations:sub_generations 
BKP="localhost:/usr/local:2:0
localhost:/etc:8:2"' >> $CONF
echo "Error: there was no config file, I created a template, please go and configure it..."
exit 1
fi

# read the config file
. $CONF

for JOB in $(echo "$BKP" | grep -v '^$' | grep -v '^#')
do
   H=$(echo $JOB | cut -d: -f1) #hostname
   D=$(echo $JOB | cut -d: -f2) #dir to catch
   G=$(echo $JOB | cut -d: -f3) #generations to keep
   S=$(echo $JOB | cut -d: -f4) #sub generations to keep
   echo "$G" | grep -q [1-9] ; [ $? -ne 0 ] && G=1 #check generations to be valid
   echo "$S" | grep -q [1-9] ; [ $? -ne 0 ] && S=1 #check sub generations to be valid
   DS=$(dirname $D)
   ping -c1 -w1 $H >/dev/null #check if host is online
   if [ $? -ne 0 ]
   then
      logger -t BACKUP "ERROR: $H is not pingable, I skip backup this host"
   else
      mkdir -p $DEST/$H$D >/dev/null 2>&1
      logger -t BACKUP "INFO: sync started $USER@$H:$D to $DEST/$H$D"
      if [ "$D" == "/" ]
      then
         rsync -e "$SSH" --exclude 'sys/*' --exclude 'proc/*' --exclude 'selinux/*' --delete -aq $USER@$H:/ $DEST/$H/root
	 D=/root
      else
         rsync -e "$SSH" --delete -aq $USER@$H:$D $DEST/$H$DS
      fi
      if [ $? -ne 0 ]
      then
         logger -t BACKUP "ERROR: could not sync $USER@$H:$D to $DEST/$H$D"
      else
              logger -t BACKUP "INFO: sync done $USER@$H:$D to $DEST/$H$D"
      fi
      # check if want to keep generations
      if [ $G -gt 1 ]
      then
         # check if want to keep sub generations
         if [ $S -gt 1 ]
	 then
	    #check if there is allready a valid sub generations backup
            ls -dr -1 $DEST/$H$D.* | head -n$G | grep -q '\-sg$' 
            if [ $? -ne 0 ]
	    then
	       cp -al $DEST/$H$D $DEST/$H$D.$DATE-sg
	       # remove old backup sub generations
               for REMOVE in $( ls -d -1 $DEST/$H$D.* | grep '\-sg$'| head -n-$S )
               do
                  rm -rf $REMOVE
               done
      	    fi
         else
            rm -rf $DEST/$H$D.*-sg
         fi
	 # if there was no sub generations rotation, do a normal one
	 ls -d -1 $DEST/$H$D $DEST/$H$D.$DATE-sg >/dev/null 2>&1
	 if [ $? -ne 0 ]
	 then
	    cp -al $DEST/$H$D $DEST/$H$D.$DATE
	 fi
	 # remove old backup generations
         for REMOVE in $( ls -d -1 $DEST/$H$D.* | grep -v '\-sg$'| head -n-$G )
         do
            rm -rf $REMOVE
         done
      else
         rm -rf $DEST/$H$D.*
      fi
   fi
done

# remove old backups after modified config
cd $DEST
for DIR in $(find $DEST -type d | egrep '.*\.[0-9]{14}$|.*\.[0-9]{14}-sg$' | rev | cut -d. -f2- | rev | sort -u)
do
   echo $DIR | grep -q /root && DIR=/
   echo $BKP | grep "$(echo $DIR | sed -e "s#^$DEST\/##" -e 's#\/#:\/#')"
   if [ $? -ne 0 ]
   then
      logger -t BACKUP "WARNING: $(echo $DIR | sed -e "s#^$DEST\/##" -e 's#\/#:\/#') not found in $CONF: rm -rf $DIR"
      rm -rf $DIR*
   fi
done

################################################################################
# $Log: backup-get-rsync.sh,v $
# Revision 1.3  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.2  2010/05/13 07:12:18  chris
# remove old backup fix, when backup dir = / (/root)
#
# Revision 1.1  2010/01/17 20:40:09  chris
# Initial revision
#
