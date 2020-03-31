#!/bin/bash
#########################################################################################
# DESC: reset TOTP enrollment for guacamole 1.1 user
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

DB=guacamole

USR="$1"

# search for username in database schema
mysql $DB -N -B -e "SELECT name FROM guacamole_entity WHERE name = '$USR';" | egrep -q "^$USR$"
if [ $? -ne 0 ]
then
   echo "   ERROR, USER:$USR does not exist in TOTP user database, so I do nothing"
   echo
   echo "   USAGE: $(basename $0) <username>      # reset TOTP for this guacamole user"
   exit 1
else
   echo "   CHECK, user $USR found in $DB database ..."
fi

# fetch IDs for user
USR_ENTITY=$(mysql $DB -N -B -e "SELECT entity_id FROM guacamole_entity WHERE name = '$USR' AND type = 'USER' ORDER BY entity_id LIMIT 1;")
USR_ID=$(mysql $DB -N -B -e "SELECT affected_user_id FROM guacamole_user_permission WHERE entity_id = '$USR_ENTITY' ORDER BY affected_user_id LIMIT 1;")

echo "   CHECK, reading current TOTP enrollment flag for user $USR ..."
USR_ENROLLED=$(mysql $DB -N -B -e "SELECT attribute_value FROM guacamole_user_attribute WHERE user_id = '$USR_ID' AND attribute_name = 'guac-totp-key-confirmed';")
echo "      DEBUG, USR=$USR / USR_ENTITY=$USR_ENTITY / USR_ID=$USR_ID / USR_ENROLLED=$USR_ENROLLED"

if [ "$USR_ENROLLED" != 'true' ]
then
   echo "   ERROR, user $USR is curently not enrolled, so I do nothing"
   exit 1
fi

echo "   TASK, resetting TOTP enrollment flag for user $USR ..."
mysql $DB -N -B -e "UPDATE guacamole_user_attribute SET attribute_value = 'false' WHERE ( user_id = '$USR_ID' AND attribute_name = 'guac-totp-key-confirmed' );"

echo "   TASK, resetting TOTP secret for user $USR ..."
mysql $DB -N -B -e "DELETE FROM guacamole_user_attribute WHERE user_id = '$USR_ID' AND attribute_name = 'guac-totp-key-secret';"

mysql $DB -N -B -e "SELECT attribute_value FROM guacamole_user_attribute WHERE user_id = '$USR_ID' AND attribute_name = 'guac-totp-key-confirmed';" | grep -q false
if [ $? -ne 0 ]
then
   echo "   ERROR, could not reset TOTP settings for user $USR, please contact support@uniqconsulting.ch"
   exit 1
else
   echo "   INFO, TOTP settings for user $USR are now reseted and ready for re-enrollment, bye"
   exit 0
fi


