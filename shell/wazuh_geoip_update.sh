#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#########################################################################
# Update Maxmind DB for Wazuh on Rocky9

# Check if required commands are installed
commands=("wget")
for cmd in "${commands[@]}"; do
    if ! command -v $cmd &> /dev/null
    then
        echo "$cmd could not be found. Please install $cmd and try again."
        exit
    fi
done

# Variables
WORK_DIR="/tmp/geoip_update"
LOG_FILE="/var/log/geoip_update.log"
DEST_DIR="/usr/share/wazuh-indexer/modules/ingest-geoip"
BACKUP_DIR="/var/backups/geoip"
LICENSE_KEY="your_license_key_here"

# source licence file if it exist
test -r /etc/maxmind.key
if [ $? -eq 0 ]
then
   LICENSE_KEY="$(cat /etc/maxmind.key | grep ... | tr ' ' -d)"
   echo "Licence file /etc/maxmind.key sourced"
fi

# Create a working directory
mkdir -v -p ${WORK_DIR} || { echo "Failed to create working directory"; exit 1; }
cd ${WORK_DIR} || { echo "Failed to change to working directory"; exit 1; }

# Check if DEST_DIR exists
if [ ! -d "${DEST_DIR}" ]; then
    echo "Destination directory does not exist"
    exit 1
fi

# Backup current databases
mkdir -v -p ${BACKUP_DIR} || { echo "Failed to create backup directory"; exit 1; }
for db_file in ${DEST_DIR}/GeoLite2-*; do
    if [ -f "$db_file" ]; then
        cp -v "$db_file" ${BACKUP_DIR}/ || { echo "Failed to backup current databases"; exit 1; }
    else
        echo "No existing databases to backup"
        exit 1
    fi
done

# Download new databases
wget -O GeoLite2-City.mmdb.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${LICENSE_KEY}&suffix=tar.gz" || { echo "Failed to download GeoLite2-City database"; exit 1; }
wget -O GeoLite2-Country.mmdb.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${LICENSE_KEY}&suffix=tar.gz" || { echo "Failed to download GeoLite2-Country database"; exit 1; }
wget -O GeoLite2-ASN.mmdb.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-ASN&license_key=${LICENSE_KEY}&suffix=tar.gz" || { echo "Failed to download GeoLite2-ASN database"; exit 1; }

# Extract and move to the destination
gzip -v -d *.gz || { echo "Failed to extract databases"; exit 1; }
cp -v -f GeoLite2-* ${DEST_DIR}/ || { echo "Failed to move new databases to destination"; exit 1; }

# Set permissions
echo "Listing files in the destination directory:"
ls -l ${DEST_DIR}/
chown -v wazuh-indexer:wazuh-indexer ${DEST_DIR}/GeoLite2-*
chmod -v 640 ${DEST_DIR}/GeoLite2-*

# Cleanup
rm -v -rf ${WORK_DIR}

# Log update
echo "$(date "+%Y-%m-%d %H:%M:%S") - GeoIP databases updated." >> ${LOG_FILE}

