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
   echo "   INFO, user $USR found in $DB database ..."
fi


# check if user has enrolled totp before resetting the value
mysql $DB -N -B -e "SELECT attribute_value FROM guacamole_user_attribute WHERE user_id IN (SELECT entity_id FROM guacamole_entity WHERE ( name = '$USR' AND type = 'USER') AND attribute_name = 'guac-totp-key-confirmed' );" | grep -q true
if [ $? -ne 0 ]
then
   echo "   ERROR, USER:$USR has no activated TOTP settings, so I do nothing"
   exit 1
fi

echo "   INFO, resetting TOTP enrollment flag for user $USR ..."
mysql $DB -N -B -e "UPDATE guacamole_user_attribute SET attribute_value = 'false' WHERE ( user_id IN (SELECT entity_id FROM guacamole_entity WHERE name = '$USR' AND type = 'USER') AND attribute_name = 'guac-totp-key-confirmed' );"

echo "   INFO, resetting TOTP secret for user $USR ..."
mysql $DB -N -B -e "DELETE FROM guacamole_user_attribute WHERE user_id IN (SELECT entity_id FROM guacamole_entity WHERE ( name = '$USR' AND type = 'USER') AND attribute_name = 'guac-totp-key-secret' );"

mysql $DB -N -B -e "SELECT attribute_value FROM guacamole_user_attribute WHERE ( user_id IN (SELECT entity_id FROM guacamole_entity WHERE name = '$USR' AND type = 'USER') AND attribute_name = 'guac-totp-key-confirmed' );" | grep -q false
if [ $? -ne 0 ]
then
   echo "   ERROR, could not reset TOTP settings for user $USR, please contact support@uniqconsulting.ch"
   exit 1
else
   echo "   INFO, TOTP settings for user $USR are now reseted and ready for re-enrollment, bye"
   exit 0
fi

