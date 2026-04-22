#!/bin/bash
# DESC: script to rename freeipa/idm userid and re-attach its totp tokens
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

set -euo pipefail

DB="/etc/ipa/nssdb"
CERTDB="$DB/cert9.db"

declare -A HEX_MAP
declare -A EXP_MAP

# --- build lookup safely ---
while read -r hex; do

    # skip empty rows (critical fix)
    [[ -z "$hex" ]] && continue

    der=$(mktemp)

    echo "$hex" | xxd -r -p > "$der"

    serial_hex=$(openssl x509 -in "$der" -inform DER -noout -serial 2>/dev/null | cut -d= -f2)

    # skip invalid DER blobs
    if [[ -z "$serial_hex" ]]; then
        rm -f "$der"
        continue
    fi

    expire=$(openssl x509 -in "$der" -inform DER -noout -enddate | cut -d= -f2)

    dec=$(python3 -c "print(int('$serial_hex',16))")

    hex_fmt=$(echo "$serial_hex" | sed 's/../&:/g; s/:$//' | tr 'A-F' 'a-f')

    HEX_MAP["$dec"]="$hex_fmt"
    EXP_MAP["$dec"]="$expire"

    rm -f "$der"

done < <(
    sqlite3 -readonly "$CERTDB" \
    "SELECT hex(a11) FROM nssPublic WHERE a11 IS NOT NULL;"
)

# --- output ---
echo "================ IPA CERTIFICATE AUDIT ================"
echo

ipa-cacert-manage list 2>/dev/null | sed '$d' | while read -r line; do

    nick=$(echo "$line" | sed 's/[[:space:]]\{2,\}.*$//')
    dec=$(echo "$line" | awk '{print $NF}')

    echo "------------------------------------------------------"
    echo "Nick        : $nick"
    echo "HEX Serial  : ${HEX_MAP[$dec]:-NOT_FOUND}"
    echo "DEC Serial  : $dec"
    echo "Expire Date : ${EXP_MAP[$dec]:-NOT_FOUND}"
    echo

done

echo "================ END OF REPORT ========================"

