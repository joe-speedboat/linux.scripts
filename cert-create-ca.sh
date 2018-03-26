#!/bin/bash
#########################################################################################
# DESC: create self signed tls cert with CA chain
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
umask 077

if [ "x" == "x$1"  -o "$1" == "-h" -o "$1" == "--help" ] 
then
   echo "   usage: $(basename $0) <fqdn>"
   exit 1
fi

# cert fqdn
HOST="$1"
# file for fqdn which is wildcard aware
HOSTF="$(echo $1 | sed 's/*/star/g')"
# ca dir
CA_DIR="$HOME/MySsl"
# cert dir
BASE_DIR="$CA_DIR/$HOSTF"
# certificate details
CA_SUBJ='/C=CH/O=Bitbull-CA/CN=LAB-Auth'
CERT_SUBJ='/C=CH/ST=SG/L=Flawil/O=Bitbull'
# cert validity days
DAYS=3650
# ca keylen
CA_KEYLEN=4096
# cert keylen
PRIV_KEYLEN=2048

mkdir -p ${CA_DIR}/ca
mkdir -p ${BASE_DIR}/{servers,tmp}
cd "${BASE_DIR}" || exit 1
if [ -f "${CA_DIR}/ca/root.key.pem" ]
then
   echo "------ Skip creation of ${CA_DIR}/ca/root.key.pem, it is already present"
else
   echo "------ create root key"
   openssl genrsa -out "${CA_DIR}/ca/root.key.pem" $CA_KEYLEN
   find "${CA_DIR}/ca/root.key.pem"
fi
if [ -f "${CA_DIR}/ca/root.crt.pem" ]
then
   echo "------ Skip creation of ${CA_DIR}/ca/root.crt.pem, it is already present"
else
   echo "------ create intermediate cert"
   openssl req -x509 -new -nodes -key "${CA_DIR}/ca/root.key.pem" -days $DAYS -out "${CA_DIR}/ca/root.crt.pem" -subj "$CA_SUBJ"
   find  "${CA_DIR}/ca/root.crt.pem"
fi
if [ -f "${BASE_DIR}/servers/${HOSTF}_privkey.pem" ]
then
   echo "------ ERROR: ${BASE_DIR}/servers/${HOSTF}_privkey.pem this file should not exist, remove this files first:"
   ls -l ${BASE_DIR}/servers/${HOSTF}_*
else
   echo "------ create server private key"
   openssl genrsa -out "${BASE_DIR}/servers/${HOSTF}_privkey.pem" $PRIV_KEYLEN -key "${BASE_DIR}/servers/${HOSTF}_privkey.pem"
   echo "------ create server csr"
   openssl req -key "${BASE_DIR}/servers/${HOSTF}_privkey.pem" -new -sha256 -out "tmp/${HOSTF}.csr.pem" -subj "$CERT_SUBJ/CN=${HOST}"
   echo "sign csr"
   openssl x509 -req -in "tmp/${HOSTF}.csr.pem" -CA "${CA_DIR}/ca/root.crt.pem" -CAkey "${CA_DIR}/ca/root.key.pem" -CAcreateserial -out "${BASE_DIR}/servers/${HOSTF}_cert.pem" -days $DAYS
   echo "------ prepare cert chain"
   cat "${CA_DIR}/ca/root.crt.pem" > "${BASE_DIR}/servers/${HOSTF}_ca_chain.pem"
   echo " ------ SHOW RESULTS"
   find "$BASE_DIR"
   echo "--- done"
fi
