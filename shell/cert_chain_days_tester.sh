#!/bin/bash
# DESC: test entire cert chain for days left


# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#!/bin/bash

# Check if correct number of arguments is passed
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <hostname> <port>"
    exit 1
fi

HOST=$1
PORT=$2

# Fetch the certificate chain
CERT_CHAIN=$(echo | openssl s_client -connect $HOST:$PORT -showcerts 2>/dev/null)

# Split the certificate chain into individual certificates and save them to temporary files
CERT_INDEX=0
CERT_FILE=""
EXPIRATION_DATES=()

echo "$CERT_CHAIN" | while read -r line; do
    if [[ $line == "-----BEGIN CERTIFICATE-----" ]]; then
        CERT_INDEX=$((CERT_INDEX + 1))
        CERT_FILE="cert${CERT_INDEX}.pem"
        echo "$line" > "$CERT_FILE"
    elif [[ $line == "-----END CERTIFICATE-----" ]]; then
        echo "$line" >> "$CERT_FILE"
        CERT_FILE=""
    elif [[ -n $CERT_FILE ]]; then
        echo "$line" >> "$CERT_FILE"
    fi
done

# Loop through each certificate file and get details
for CERT_FILE in cert*.pem; do
    if [ -s "$CERT_FILE" ]; then
        echo "Certificate $CERT_FILE:"
        openssl x509 -in "$CERT_FILE" -noout -startdate -enddate -issuer
        END_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRATION_DATES+=("$END_DATE")
        echo ""
    else
        echo "Skipping empty certificate file: $CERT_FILE"
    fi
    # Clean up the certificate file
    rm "$CERT_FILE"
done

# Function to convert date to a format suitable for comparison
convert_date() {
    date -d "$1" +%Y%m%d%H%M%S
}

# Find the earliest expiration date
EARLIEST_DATE=${EXPIRATION_DATES[0]}
for date in "${EXPIRATION_DATES[@]}"; do
    if [[ $(convert_date "$date") -lt $(convert_date "$EARLIEST_DATE") ]]; then
        EARLIEST_DATE=$date
    fi
done

# Output the earliest expiration date with a comment
echo "The earliest expiration date in the certificate chain is: $EARLIEST_DATE"
echo "The client will not be able to access the website after this date unless the certificate is renewed."

