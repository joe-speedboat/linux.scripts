#!/bin/bash
#########################################################################################
# DESC: create self signed tls cert
# $Revision: 1.1 $
# $RCSfile: cert-create.sh,v $
# $Author: chris $
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export $PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
umask 077

CDIR=/tmp/cert
CNAME=`hostname -s`
FQDN=`hostname`
CDAYS=3650

test -d $CDIR/private || mkdir -p $CDIR/private
test -d $CDIR/certs || mkdir -p $CDIR/certs

if [ -f $CDIR/private/$CNAME.key -o -f $CDIR/certs/$CNAME.crt ]; then
   exit 0
fi

openssl genrsa -rand /proc/apm:/proc/cpuinfo:/proc/dma:/proc/filesystems:/proc/interrupts:/proc/ioports:/proc/pci:/proc/rtc:/proc/uptime 2048 > $CDIR/private/$CNAME.key 2> /dev/null

if [ "x${FQDN}" = "x" ]; then
   FQDN=localhost.localdomain
fi

cat << EOF | openssl req -new -key $CDIR/private/$CNAME.key \
         -x509 -sha256 -days $CDAYS -set_serial $RANDOM -extensions v3_req \
         -out $CDIR/certs/$CNAME.crt 2>/dev/null
--
SomeState
SomeCity
SomeOrganization
SomeOrganizationalUnit
${FQDN}
root@${FQDN}
EOF


################################################################################
# $Log: cert-create.sh,v $
# Revision 1.1  2016/12/25 19:59:09  chris
# Initial revision
#
