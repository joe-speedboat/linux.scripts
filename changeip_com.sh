#!/bin/bash
# DESC: script to change dyn IP at changeip.com
# $Revision: 1.5 $
# $RCSfile: changeip_com.sh,v $
# $Author: chris $
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#------------------ Variables -------------------------------------
CIPUSER=user199                       # ChangeIP.com Username
CIPPASS=xyz123                        # ChangeIP.com Password
CIPHOST=myhost.compress.to            # Single Hostname to update
CSET=1                                # Dynamic Set #remember to define it!
#------------------------------------------------------------------

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# get current IP
CURRENTIP=$(wget -q -O - ip.changeip.com | grep ^[0-9])

# get ip from changeIP
LASTIP=$( ping -c1 -w1 $CIPHOST 2>/dev/null | grep PING | cut -d'(' -f2 | cut -d')' -f1 )


# compare 
if [ "$CURRENTIP" != "$LASTIP" ]
then
   wget -nv --http-user=$CIPUSER --http-password=$CIPPASS -O - "http://nic.ChangeIP.com/nic/update?hostname=$CIPHOST&myip=$CURRENTIP&system=dyndns" 2>&1 | egrep -v '200 Successful Update| URL:'
fi


################################################################################
# $Log: changeip_com.sh,v $
# Revision 1.5  2015/03/26 17:19:33  chris
# fix ippaht var
#
# Revision 1.4  2014/11/11 20:31:28  chris
# changed registration url
#
# Revision 1.3  2014/05/09 06:20:23  chris
# now compare IPs from dns-request against wan IP
#
# Revision 1.2  2014/04/12 19:54:30  chris
# protect credentials
#
# Revision 1.1  2014/04/12 19:50:20  chris
# Initial revision
#
