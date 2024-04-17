#!/bin/bash
# DESC: prepare EL5 Server for oracle 11g installation and guides trough install process
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: oracle-11g-install.sh,v $
#
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# unzip installer cds here before you start:
# cd $IBASE
# unzip linux_11gR2_database_1of2.zip
# unzip linux_11gR2_database_1of2.zip

# installation base dir
IBASE=/opt/u00/setup/11.2.0EE

ROOT=/opt
SID=TST01

ORACLE_SID=$SID
# oracle base dir
OBASE=$ROOT/u00/app/oracle
# oracle home
OHOME=$OBASE/product/11.2.0/db1
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
mkdir -p $ROOT/u00/home/oracle/admin/sqlnet

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
# Kernel Parameters for Oracle 11
kernel.shmall = 2097152
kernel.shmmax = 536870912
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
' >> /etc/sysctl.conf

sysctl -p

#######################################################################
# change system limitation settings for user oracle
#######################################################################
echo '
# To increase the shell limits for Oracle 11g
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
' >> /etc/security/limits.conf

#######################################################################
# install needed sw deps
#######################################################################
yum -y install libaio compat-db libXtst.i386 xauth libXp glibc-devel.i386 vnc-server compat-libstdc++-33 make gcc openmotif pdksh gcc-c++ libaio-devel libstdc++-devel compat-libstdc++-33 sysstat unixODBC unixODBC-devel elfutils-libelf-devel

#######################################################################
# create base env for oracle user
#######################################################################
echo "# .bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Oracle specific aliases and functions
export ORACLE_HOSTNAME=$(hostname -s)
export ORACLE_SID=$SID
export LISTENER_NAME=\$ORACLE_SID
export ORACLE_BASE=$OBASE
export ORACLE_HOME=$OHOME
export ORACLE_DOC=\$ORACLE_HOME/doc
export ORACLE_ADMIN=\$ORACLE_HOME/network/admin
export TNS_ADMIN=\$ORACLE_HOME/network/admin/sqlnet
export PATH=\$ORACLE_HOME/bin:\$HOME/bin:\$PATH
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export LANG=en_US.UTF-8
export TEMP=/tmp
export TMPDIR=/tmp
export EDITOR=vi
export ORACLE_TERM=xterm
export PATH=\$ORACLE_HOME/bin:\$PATH
export NLS_LANG=american_america.al32utf8
export ORA_NLS10=\$ORACLE_HOME/nls/data
ulimit -u 16384 -n 63536
" > ~oracle/.bashrc

#######################################################################
# install oracle
#######################################################################

echo "
ssh -X oracle@$(hostname -s)

### Install Oracle Application ###
cd $IBASE/database
$IBASE/database/runInstaller 
#MyNote: $IBASE/database/runInstaller -responseFile $IBASE/database/runInstaller.rsp [-silent]
# run as root:
#   $ROOT/u00/app/oraInventory/orainstRoot.sh
#   $ROOT/u00/app/oracle/product/11.2.0/db1/root.sh

### Create Database ###
dbca

Example Config:
---------------
DATAFILES
  $ROOT/u01/oradata/$SID/

LOGFILES (50MB)
  GROUP 1
    $ROOT/u01/oradata/$SID/redog1m1.rdo
    $ROOT/u02/oradata/$SID/redog1m2.rdo
  GROUP 2
    $ROOT/u02/oradata/$SID/redog2m1.rdo
    $ROOT/u03/oradata/$SID/redog2m2.rdo
  GROUP 3
    $ROOT/u03/oradata/$SID/redog3m1.rdo
    $ROOT/u01/oradata/$SID/redog3m2.rdo

CONTROL FILES
    $ROOT/u01/oradata/$SID/control01.ctl
    $ROOT/u02/oradata/$SID/control02.ctl
    $ROOT/u03/oradata/$SID/control03.ctl

LOG_ARCHIVE_DEST 
   $ROOT/u03/arch/$SID/*.arc

FLASH_DEST 
   $BKP/$SID

CHARACTER SET AL32UTF8
---------------
"
# HOWTO REMOVE COMPLETE ORACLE INSTALLATION
# pkill -9 -u oracle
# userdel -r oracle
# groupdel dba
# rm -rf $ROOT/u0?/{home,app,oracle,oradata,arch,flash} /etc/ora* /usr/local/bin/*ora* /usr/local/bin/dbhome
#
################################################################################
# $Log: oracle-11g-install.sh,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/04/20 08:38:42  chris
# Initial revision
#
