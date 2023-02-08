#!/bin/bash
#########################################################################################
# DESC: SSH Reverse Port Forwarder to jump into NATed Network
# $Revision: 1.3 $
# $RCSfile: ssh-reverse-port-forwarder.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# start via cron on DST(2): @reboot * * * * $HOME/bin/ssh-reverse-port-forwarder.sh
# connect from SRC(1)
# NET: DST(2) --> Router(NAT) --> WWW --> SRC(SSH Host)
# connect to NATed network behind the Router (2) from Home (1):
# ssh -p2222 dst-user@localhost


ID=remote_usr
HOST=remote.domain.com

#AUTOSSH_POLL=600
#AUTOSSH_PORT=20000
#AUTOSSH_GATETIME=30
#AUTOSSH_LOGFILE=$HOST.log
#AUTOSSH_DEBUG=yes 
#AUTOSSH_PATH=/usr/local/bin/ssh
export AUTOSSH_POLL AUTOSSH_LOGFILE AUTOSSH_DEBUG AUTOSSH_PATH AUTOSSH_GATETIME AUTOSSH_PORT

autossh -2 -fN -M 20000 -R 2222:127.0.0.1:22 -L 143:imap_host:143 ${ID}@${HOST}

################################################################################
# $Log: ssh-reverse-port-forwarder.sh,v $
# Revision 1.3  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.2  2010/05/10 07:21:15  chris
# complete rewritten to run with autossh
#
# Revision 1.1  2010/01/17 20:40:19  chris
# Initial revision
#
