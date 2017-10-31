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

ping -c1 -w1 -- "$1" 2>&1 | grep -q "Name or service not known"
if [ $? -eq 0 ]
then
   echo "------ WARN: can not resolve host $1"
   exit 1
fi

# cert fqdn
HOST="$1"
# cert root dir
BASE_DIR="/etc/MySsl/$HOST"
# certificate details
CA_SUBJ='/C=CH/O=Bitbull-CA/CN=LabAuthority'
CERT_SUBJ='/C=CH/ST=SG/L=Flawil/O=Bitbull'
# cert validity days
DAYS=3650
# ca keylen
CA_KEYLEN=4096
# cert keylen
PRIV_KEYLEN=2048

KEY_COPY="/etc/nginx/${HOST}_privkey.pem"
CERT_COPY="/etc/nginx/${HOST}_cert.pem"
CA_CHAIN_COPY="/etc/nginx/${HOST}_ca_chain.pem"
COPY_OWNER="root:nginx"

mkdir -p ${BASE_DIR}/{ca,servers,tmp}
cd "${BASE_DIR}" || exit 1
if [ -f "ca/root.key.pem" ]
then
   echo "------ Skip creation of ca/root.key.pem, it is already present"
else
   echo "------ create root key"
   openssl genrsa -out "ca/root.key.pem" $CA_KEYLEN
fi
if [ -f "ca/root.crt.pem" ]
then
   echo "------ Skip creation of ca/root.crt.pem, it is already present"
else
   echo "------ create intermediate cert"
   openssl req -x509 -new -nodes -key "ca/root.key.pem" -days $DAYS -out "ca/root.crt.pem" -subj "$CA_SUBJ"
fi
if [ -f "servers/${HOST}_privkey.pem" ]
then
   echo "------ ERROR: servers/${HOST}_privkey.pem this file should not exist, remove this files first:"
   ls -l servers/${HOST}_*
else
   echo "------ create server private key"
   openssl genrsa -out "servers/${HOST}_privkey.pem" $PRIV_KEYLEN -key "servers/${HOST}_privkey.pem"
   echo "------ create server csr"
   openssl req -key "servers/${HOST}_privkey.pem" -new -sha256 -out "tmp/${HOST}.csr.pem" -subj "$CERT_SUBJ/CN=${HOST}"
   echo "sign csr"
   openssl x509 -req -in "tmp/${HOST}.csr.pem" -CA "ca/root.crt.pem" -CAkey "ca/root.key.pem" -CAcreateserial -out "servers/${HOST}_cert.pem" -days $DAYS
   echo "------ prepare cert chain"
   cat "ca/root.crt.pem" > "servers/${HOST}_ca_chain.pem"
   echo " ------ SHOW RESULTS"
   find "$BASE_DIR"
   echo "------ copy cert in place"
   cp -v "servers/${HOST}_privkey.pem" "$KEY_COPY" ; chmod 640 "$KEY_COPY"
   cp -v "servers/${HOST}_cert.pem" "$CERT_COPY" ; chmod 644 "$CERT_COPY" 
   cp -v "servers/${HOST}_ca_chain.pem" "$CA_CHAIN_COPY" ; chmod 644 "$CA_CHAIN_COPY"
   chown $COPY_OWNER "$KEY_COPY" "$CERT_COPY" "$CA_CHAIN_COPY"
   echo "--- done"
fi
