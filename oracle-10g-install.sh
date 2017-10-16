#!/bin/bash
# DESC: prepare EL5 Server for oracle 10g installation and guides trough install process
# $Author: chris $
# $Revision: 1.3 $
# $RCSfile: oracle-10g-install.sh,v $
#

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# installation base dir
IBASE=/opt/u00/setup/10.2.0EE

ROOT=/opt
SID=TCT

ORACLE_SID=$SID
# oracle base dir
OBASE=$ROOT/u00/app/oracle
# oracle home
OHOME=$OBASE/product/10.2.0/db1
# dbfiles, redolog1, controlfile1
DATA1=$ROOT/u01/oradata
# redolog2, controlfile2
DATA2=$ROOT/u02/oradata
# archive logs
ARCH=$ROOT/u03/arch
# controlfile3, redolog3
DATA3=$ROOT/u03/oradata
# backup dest
BKP=$ROOT/u04/flash

#######################################################################
# create user and group
#######################################################################
mkdir -p $ROOT/u00/home
groupadd -g 400 dba
useradd -u 400 -g 400 -d $ROOT/u00/home/oracle -s /bin/bash -c "Oracle Owner" oracle

#######################################################################
# create directory structure based on oracle OFA standard
#######################################################################
#oracle home
mkdir -p $OHOME
mkdir -p $DATA1/$SID $DATA2/$SID $DATA3/$SID $ARCH $BKP

chown -R oracle:dba $ROOT/u*
chown -R oracle:dba $ROOT/u*

#######################################################################
# set and activate kernel configuration
#######################################################################
echo '
# Kernel Parameters for Oracle 10.2.0
kernel.shmall = 2097152
kernel.shmmax = 2147483648
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 65536
net.ipv4.ip_local_port_range = 1024 65000
net.core.rmem_default = 1048576
net.core.rmem_max = 1048576
net.core.wmem_default = 262144
net.core.wmem_max = 262144
' >> /etc/sysctl.conf

sysctl -p

#######################################################################
# change system limitation settings for user oracle
#######################################################################
echo '
# To increase the shell limits for Oracle 10
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
' >> /etc/security/limits.conf

#######################################################################
# install needed sw deps
#######################################################################
yum -y install libaio compat-db libXtst.i386 xauth libXp glibc-devel.i386 vnc-server compat-libstdc++-33 make gcc openmotif

#######################################################################
# create base env for oracle user
#######################################################################
echo "# .bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Oracle specific aliases and functions
export ORACLE_SID=$SID
export LISTENER_NAME=\$ORACLE_SID
export ORACLE_BASE=$OBASE
export ORACLE_HOME=$OHOME
export ORACLE_DOC=\$ORACLE_HOME/doc
export PATH=\$ORACLE_HOME/bin:\$HOME/bin:\$PATH
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export LANG=en_US.UTF-8
export TMPDIR=/tmp
export EDITOR=vi
export ORACLE_TERM=xterm
ulimit -u 16384 -n 63536
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export PATH=\$ORACLE_HOME/bin:\$PATH
export NLS_LANG=american_america.al32utf8
export ORA_NLS10=\$ORACLE_HOME/nls/data
" > ~oracle/.bashrc

#######################################################################
# install oracle base
#######################################################################


echo "
ssh -X oracle@localhost

### Install Oracle (dont create database) ###
cd $IBASE/database
$IBASE/database/runInstaller 
#MyNote: $IBASE/database/runInstaller -responseFile $IBASE/database/runInstaller.rsp [-silent]

### Patch Installation ###
cd $IBASE/patches/Disk1
#MyNote: $IBASE/patches/Disk1/runInstaller -responseFile $IBASE/patches/Disk1/patchOra10.rsp [-silent]
$IBASE/patches/Disk1/runInstaller

for p in 5945647  8340387  8467996
do 
   cd $IBASE/patches/\$p
   $OHOME/OPatch/opatch apply
done

### Create Database ###
dbca

Example Config:
---
DATAFILE
  '$ROOT/u01/oradata/$SID/system01.dbf',
  '$ROOT/u01/oradata/$SID/undotbs01.dbf',
  '$ROOT/u01/oradata/$SID/sysaux01.dbf',
  '$ROOT/u01/oradata/$SID/users01.dbf'

LOGFILE
  GROUP 1 (
    '$ROOT/u01/oradata/$SID/redog1m1.rdo',
    '$ROOT/u02/oradata/$SID/redog1m2.rdo'
  ) SIZE 50M,
  GROUP 2 (
    '$ROOT/u02/oradata/$SID/redog2m1.rdo',
    '$ROOT/u03/oradata/$SID/redog2m2.rdo'
  ) SIZE 50M,
  GROUP 3 (
    '$ROOT/u03/oradata/$SID/redog3m1.rdo',
    '$ROOT/u01/oradata/$SID/redog3m2.rdo'
  ) SIZE 50M

LOG_ARCHIVE_DEST = LOCATION=$ROOT/u03/arch/$SID

CHARACTER SET AL32UTF8
---

### install start/stop script ###
curl http://www.bitbull.ch/dl/scripts/orainit.sh > /etc/init.d/orainit
vi /etc/init.d/orainit
chmod 755 /etc/init.d/orainit
chkconfig orainit --add

### install oracle full backup ###
cd ~oracle/bin
wget http://www.bitbull.ch/dl/scripts/ora-backup.sh
chmod 755 ora-backup.sh
crontab -e 
   # ORACLE DAILY BACKUP #
   1 4 * * * /home/oracle/bin/ora-backup.sh

### Dump and Review Database Configuration ###
SQL> alter database backup controlfile to trace as '/tmp/db-info.trc';

$> vi /tmp/db-info.trc

"
# HOWTO REMOVE COMPLETE ORACLE INSTALLATION
# pkill -9 -u oracle
# userdel -r oracle
# groupdel dba
# rm -rf $ROOT/u0?/{home,app,oracle,oradata,arch,flash} /etc/ora* /usr/local/bin/*ora* /usr/local/bin/dbhome
# vi /etc/sysctl.conf
# vi /etc/security/limits.conf
#
################################################################################
# $Log: oracle-10g-install.sh,v $
# Revision 1.3  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.2  2010/04/20 08:41:52  chris
# minor bugfixing for $ROOT var
#
# Revision 1.1  2010/01/17 20:40:15  chris
# Initial revision
#
