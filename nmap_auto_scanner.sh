#!/bin/bash
# DESC: nmap multi thread and clan output script for mass scanning
# $Revision: 1.2 $
# $RCSfile: nmap_auto_scanner.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

DHOSTS=$(cat domain.com.ip)

for DHOST in $DHOSTS; do
   NMAP=$(pgrep -f nmap | wc -l)
   while [ $NMAP -gt 12 ]
   do
      sleep 30
      NMAP=$(pgrep -f nmap | wc -l)
   done
   echo ------------- $DHOST --------------- > nmap_$DHOST.txt
   nmap -PN -T1 -sA -sV -O -sU --host-timeout 60m $DHOST >> nmap_$DHOST.txt &
   clear
   echo -------------------- Now Im Scanning this targets --------------------
   ps -ef | grep nmap | grep -v grep
done


################################################################################
# $Log: nmap_auto_scanner.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/02/20 08:33:04  chris
# Initial revision
#
