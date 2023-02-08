#!/bin/bash
# DESC: Export Bitwarden Org Vault and send it as encrypted PDF to owner
# User needs to be a Bitwarden Org Admin
# Just for desaster recovery export, to get around the chicken-egg problem
# Sure it could be done much nicer, but i did not find an other way to get an autmated export
##########################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

BW_PASS='bitwarden_user_password'
BW_EMAIL='bitwarden_user_login'
PDF_PASS='password_for_pdf_encr'
URL="https://vault.domain.local"


DEBUG=0

log(){
   [ "$1" = "err" ] && LEVEL=ERROR
   [ "$1" = "warn" ] && LEVEL=WARNING
   [ "$1" = "info" ]&& LEVEL=INFO
   [ "$1" = "debug" ]&& LEVEL=DEBUG
   shift
   [ "$LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] && echo "$LEVEL: $*"
   [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] && echo "$LEVEL: $*"
   logger -t $(basename $0) "$LEVEL: $*"
   if [ "$LEVEL" = "ERROR" ]
   then
      kill -s TERM $$
      kill -s KILL $$
   fi
}


EXPORT_DIR=/opt/bitwarden/ex
export PATH=$PATH:/opt/bitwarden

log info config bitwarden server
bw config server $URL

test -d $EXPORT_DIR && rm -rf $ED
mkdir $EXPORT_DIR
chmod 700 $EXPORT_DIR
chown root.root $EXPORT_DIR
cd
log info bitwarden logout
bw logout
unset BW_SESSION

log info bitwarden login 
bw login "$BW_EMAIL" "$BW_PASS" 2>&1 | grep 'export BW_SESSION' | sed 's/.*export/export/' > .$$.tmp
. .$$.tmp
rm -f .$$.tmp

log info get bitwarden organizationId
ORG=$(bw list organizations | jq .[] | jq -r ."id")
echo ORG=$ORG

log info export bitwarden vault 
bw export --organizationid $ORG --output $EXPORT_DIR/ --format json
cd $EXPORT_DIR

log info configure json2yaml function 
echo '
def yamlify2:
    (objects | to_entries | (map(.key | length) | max + 2) as $w |
        .[] | (.value | type) as $type |
        if $type == "array" then
            "\(.key):", (.value | yamlify2)
        elif $type == "object" then
            "\(.key):", "    \(.value | yamlify2)"
        else
            "\(.key):\(" " * (.key | $w - length))\(.value)"
        end
    )
    // (arrays | select(length > 0)[] | [yamlify2] |
        "  - \(.[0])", "    \(.[1:][])"
    )
    // .
    ;
' > ~/.jq

log info convert json export to yaml
cat *.json | jq '.items' | jq 'del(.. | .collectionIds?)' | jq 'del(.. | .id?)' | jq 'del(.. | .organizationId?)'  | jq -r yamlify2 | sed 's/.*- folderId: .*/\r---------------------------\r/g' > export.yml
rm -f *.json

log info create ps file 
enscript -p export.ps export.yml
rm -f export.yml

log info create pdf file
ps2pdf -sUserPassword="$PDF_PASS" -sOwnerPassword="$PDF_PASS" export.ps export.pdf
rm -f export.ps
mv export.pdf $(date +%Y%m%d)_vault.pdf

log info mail pdf file
date | mailx -s vault_export -a $(date +%Y%m%d)_vault.pdf  $BW_EMAIL
rm -f $(date +%Y%m%d)_vault.pdf
cd

log info bitwarden logout and cleanup
rm -rf $EXPORT_DIR
bw logout
unset BW_SESSION

