#!/bin/bash
#########################################################################################
# DESC: create self signed tls cert with CA chain and optional san entries
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
   echo "   usage: $(basename $0) <fqdn> [san1] [..] [san5]"
   exit 1
fi

ping -c1 -w1 -- "$1" 2>&1 | grep -q "Name or service not known"
if [ $? -eq 0 ]
then
   echo "------ WARN: can not resolve host $1"
   exit 1
fi

# cert fqdn
HOST="$1"
# ca dir
CA_DIR="$HOME/MySsl"
# cert dir
BASE_DIR="$CA_DIR/$HOST"
# certificate details
CA_SUBJ='/C=CH/O=Bitbull-CA-2/CN=LabAuthority-2'
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
fi
if [ -f "${CA_DIR}/ca/root.crt.pem" ]
then
   echo "------ Skip creation of ${CA_DIR}/ca/root.crt.pem, it is already present"
else
   echo "------ create intermediate cert"
   openssl req -x509 -new -nodes -key "${CA_DIR}/ca/root.key.pem" -days $DAYS -out "${CA_DIR}/ca/root.crt.pem" -subj "$CA_SUBJ"
fi
if [ -f "${BASE_DIR}/servers/${HOST}_privkey.pem" ]
then
   echo "------ ERROR: ${BASE_DIR}/servers/${HOST}_privkey.pem this file should not exist, remove this files first:"
   ls -l ${BASE_DIR}/servers/${HOST}_*
else
   echo "------ create server private key"
   openssl genrsa -out "${BASE_DIR}/servers/${HOST}_privkey.pem" $PRIV_KEYLEN -key "${BASE_DIR}/servers/${HOST}_privkey.pem"
   if [ $# -gt 1 ]
   then
     echo "------ create server csr with CN and SAN"
     [ "$2" != '' ] && SAN="subjectAltName=DNS:$2"
     [ "$3" != '' ] && SAN="${SAN},DNS:$3"
     [ "$4" != '' ] && SAN="${SAN},DNS:$4"
     [ "$5" != '' ] && SAN="${SAN},DNS:$5"
     [ "$6" != '' ] && SAN="${SAN},DNS:$6"
     openssl req -key "${BASE_DIR}/servers/${HOST}_privkey.pem" -new -sha256 -out "tmp/${HOST}.csr.pem" -subj "$CERT_SUBJ/CN=${HOST}/${SAN}"
   else
     echo "------ create server csr with CN"
     openssl req -key "${BASE_DIR}/servers/${HOST}_privkey.pem" -new -sha256 -out "tmp/${HOST}.csr.pem" -subj "$CERT_SUBJ/CN=${HOST}"
   fi
   echo "sign csr"
   openssl x509 -req -in "tmp/${HOST}.csr.pem" -CA "${CA_DIR}/ca/root.crt.pem" -CAkey "${CA_DIR}/ca/root.key.pem" -CAcreateserial -out "${BASE_DIR}/servers/${HOST}_cert.pem" -days $DAYS
   echo "------ prepare cert chain"
   cat "${CA_DIR}/ca/root.crt.pem" > "${BASE_DIR}/servers/${HOST}_ca_chain.pem"
   echo " ------ SHOW RESULTS"
   find "$BASE_DIR"
   echo "--- done"
fi
