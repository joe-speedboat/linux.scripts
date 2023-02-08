#!/bin/bash
# DESC: script to extract virtualmin web domain dumps
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: virtualmin-extractor.sh,v $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


for PKG in *.tar.gz
do
  SDIR=$(pwd)
  DOM=$(echo $PKG | rev | cut -d. -f3- | rev)
  mkdir $DOM
  cd $DOM
  tar xfz ../$PKG
  mv .backup tmp
  rm -rf html/stats
  DOC=README
  ### CREATE DOCUMENTATION FILE ###
  touch $DOC
  echo "#DESC: DOMAIN DUMP VIA VIRTUALMIN" >> $DOC
  echo "#DATE: $(date '+%Y%m%d%H%M')" >> $DOC
  echo >> $DOC
  echo "--- MYSQL DATEN ---" >> $DOC
  grep '^db_mysql=' tmp/*_virtualmin >> $DOC
  grep '^mysql_user=' tmp/*_virtualmin >> $DOC
  grep '^pass=' tmp/*_virtualmin >> $DOC
  echo "" >> $DOC
  echo "--- DOMAIN DATEN ---" >> $DOC
  grep '^dom=' tmp/*_virtualmin >> $DOC
  grep '^user=' tmp/*_virtualmin >> $DOC
  grep '^pass=' tmp/*_virtualmin >> $DOC
  echo "" >> $DOC
  echo "--- MAIL DATEN ---" >> $DOC
  echo "MAIL USER:" >> $DOC
  echo "LOGIN:CRYPT_PW;NAME;MAIL" >> $DOC
  cat tmp/*_mail_users | cut -d: -f1,2,5,8 | grep -v '^$' | grep -v ':$' >> $DOC
  echo "MAIL ALIASES:" >> $DOC
  cat tmp/*_mail_aliases >> $DOC
  cp tmp/*_web apache.conf
  mkdir mail
  cd mail
  tar xf ../tmp/*_mail_files
  cd ..
  rm -f mail/$DOM
  cp tmp/*_mysql_*.gz ./
  gunzip *_mysql_*.gz
  mv *_mysql_* $(ls *_mysql_* | sed 's/.*_mysql_//g').mysql
  rm -rf tmp
  rm -rf cgi-bin
  rm -rf logs
  rm -rf homes
  cd $SDIR
done

################################################################################
# $Log: virtualmin-extractor.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:21  chris
# Initial revision
#
