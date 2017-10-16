#!/bin/sh
# DESC: view certificate details by hostname and tcp port
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: openssl_cert_check.sh,v $
# usage: openssl_cert_check.sh remote.host.name [port]
#
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

REMHOST=$1
REMPORT=${2:-443}

echo '############## openssl x509 -noout -subject -dates #####################################'
echo |\
openssl s_client -connect ${REMHOST}:${REMPORT} 2>/dev/null |\
sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' |\
openssl x509 -noout -subject -serial -dates

echo '############## openssl s_client -connect ${REMHOST}:${REMPORT} ##########################'
echo |\
openssl s_client -connect ${REMHOST}:${REMPORT} 2>&1 |\
sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'

echo '############## openssl x509 -noout #######################################################'
echo |\
openssl s_client -connect ${REMHOST}:${REMPORT} 2>/dev/null |\
sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' |\
openssl x509 -noout -text

################################################################################
# $Log: openssl_cert_check.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:14  chris
# Initial revision
#
