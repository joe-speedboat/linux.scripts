#!/bin/bash
# DESC: script to manage a crypred password file for each user on system
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: password-file-crypt.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PW="$HOME/.pw"

clear
echo

check(){
chmod 600 $PW*
if [ -f $PW ]
then
   ls -l $PW
   ps -ef | grep -q "^vi $PW"
   if [ $? = 0 ]
   then
      echo "file is already open"
      ps -ef | grep -v grep | grep "vi.*$PW"
      exit 1
   fi
echo "uncrypted tmp file was not removed, I will clean up now"
sleep 3
rm -f $PW
fi
}


open-file(){
echo "going to open crypted file..."
gpg -q -d $PW.gpg > $PW
if [ $? = 0 ]
then
   DUMMY=
else
   echo "could not decrypt file ..."
   echo "i will exit now"
   exit 1
fi
MD5ORIG=$(cat $PW | md5sum)
chmod 600 $PW
vi $PW
MD5NEW=$(cat $PW | md5sum)
if [ "$MD5NEW" == "$MD5ORIG" ]
then
   DUMMY=
else
   rm -f $PW.gpg.10 >/dev/null 2>&1
   mv $PW.gpg.9 $PW.gpg.10 >/dev/null 2>&1
   mv $PW.gpg.8 $PW.gpg.9 >/dev/null 2>&1
   mv $PW.gpg.7 $PW.gpg.8 >/dev/null 2>&1
   mv $PW.gpg.6 $PW.gpg.7 >/dev/null 2>&1
   mv $PW.gpg.5 $PW.gpg.6 >/dev/null 2>&1
   mv $PW.gpg.4 $PW.gpg.5 >/dev/null 2>&1
   mv $PW.gpg.3 $PW.gpg.4 >/dev/null 2>&1
   mv $PW.gpg.2 $PW.gpg.3 >/dev/null 2>&1
   mv $PW.gpg.1 $PW.gpg.2 >/dev/null 2>&1
   mv $PW.gpg   $PW.gpg.1 >/dev/null 2>&1
   echo
   echo "you have changed the file, please give password to encrypt with ..."
   ENC=1
   until [ $ENC = 0 ]
   do
      gpg -q -c $PW 
   if [ $? = 0 ]
   then
      ENC=0
   else
      echo "probably you did not enter the same password twice, please try again ..."
   fi
   done
fi
if [ $? = 0 ]
then
   rm -f $PW
   echo "bye ..."
   exit 0
else
   echo "something went wrong, please inspect following files:"
   ls -l $PW*
fi
}

if [ ! -f $PW.gpg ]
then
   echo you have no crypt file, i will create one, please give password
   echo "new file" > $PW
   gpg -q -c $PW
   chmod 600 $PW*
   rm -f $PW
   check
   open-file
fi


check
open-file

################################################################################
# $Log: password-file-crypt.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:16  chris
# Initial revision
#
