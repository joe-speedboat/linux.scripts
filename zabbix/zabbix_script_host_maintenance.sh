#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#################################################################################################################
### Place this script in a directory on your zabbix server and make sure it is accessible by the zabbix user. ###
### Make sure there is an API user present and update the variable below                                      ###
###                                                                                                           ###
### Usage: python <dir>/<scriptname> MODE(create/delete) "{HOST.HOST}" <period> (in seconds) "{USER.ALIAS}"   ###
### Example: Script is placed in /frontend scripts. we create maintenance for 1 day:                          ###
### bash /path/.../zabbix_script_host_maintenance.sh create "{HOST.HOST}" 86400 "{USER.ALIAS}"                ###
###                                                                                                           ###
### The script creates or deletes a maintenance period for the specified host.                                ###
### In 'create' mode, if a maintenance period already exists, it updates the period and the user alias.       ###
### In 'delete' mode, it deletes the maintenance period if it exists.                                         ###
###                                                                                                           ###
#################################################################################################################
# Read Zabbix scripts documentation for more info:
# https://www.zabbix.com/documentation/5.2/en/manual/web_interface/frontend_sections/administration/scripts

# Get the command line arguments
MODE=$1
HOSTNAME=$2
PERIOD=$3
USER_ALIAS=$4

# Define the URL and token
URL='https://example.com/zabbix/api_jsonrpc.php?'
TOKEN="PUT_YOUR_TOKEN_HERE"

# Define the headers
HEADERS='Content-Type: application/json'

# No replacement needed

# Define the functions
function hostid_get() {
    # Get the host ID
    PAYLOAD='{
        "jsonrpc": "2.0",
        "method": "host.get",
        "params": {
            "output": ["hostid"],
            "filter": {
                "host": "'$HOSTNAME'"
            }
        },
        "auth": "'$TOKEN'",
        "id": 1
    }'

    HOSTID=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL | jq -r '.result[0].hostid')

    echo $HOSTID
}

function maintenance_get() {
    # Get the maintenance ID
    PAYLOAD='{
        "jsonrpc": "2.0",
        "method": "maintenance.get",
        "params": {
            "output": "extend",
            "hostids": ['$(hostid_get)'],
            "selectTimeperiods": "timeperiodid"
        },
        "auth": "'$TOKEN'",
        "id": 1
    }'

    RESPONSE=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL)
    echo "Maintenance period for: $HOSTNAME has been deleted."
    MAINTENANCEID=$(echo $RESPONSE | jq -r '.result[0].maintenanceid')

    echo $MAINTENANCEID
}

function maintenance_delete() {
    # Delete the maintenance
    MAINTENANCEID=$(maintenance_exists)
    PAYLOAD='{
        "jsonrpc": "2.0",
        "method": "maintenance.delete",
        "params": ['"$MAINTENANCEID"'],
        "auth": "'$TOKEN'",
        "id": 1
    }'

    RESPONSE=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL)
    echo "Maintenance period for: $HOSTNAME has been deleted."
}

function maintenance_set() {
    # Set the maintenance
    DESCRIPTION="This maintenance period is updated by $USER_ALIAS"
    if [ -z "$MAINTENANCEID" ]; then
        DESCRIPTION="This maintenance period is created by $USER_ALIAS"
    fi

    PAYLOAD='{
        "jsonrpc": "2.0",
        "method": "maintenance.create",
        "params": {
            "name": "Maintenance period for: '$HOSTNAME'",
            "active_since": '$(date +%s)',
            "active_till": '$(( $(date +%s) + PERIOD ))',
            "hosts": [{"hostid": '$(hostid_get)'}],
            "description": "'$DESCRIPTION'",
            "timeperiods": [{"timeperiod_type": 0, "period": '$PERIOD'}]
        },
        "auth": "'$TOKEN'",
        "id": 1
    }'

    RESPONSE=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL)
    echo "Maintenance period for: $HOSTNAME has been created."
}

# Check if a maintenance period with the same name already exists and return its ID
function maintenance_exists() {
    PAYLOAD='{
        "jsonrpc": "2.0",
        "method": "maintenance.get",
        "params": {
            "output": "extend",
            "filter": {
                "name": "Maintenance period for: '$HOSTNAME'"
            }
        },
        "auth": "'$TOKEN'",
        "id": 1
    }'

    RESPONSE=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL)
    RESULT=$(echo $RESPONSE | jq -r '.result')
    if [ "$RESULT" != "[]" ]; then
        MAINTENANCEID=$(echo $RESPONSE | jq -r '.result[0].maintenanceid')
    else
        MAINTENANCEID=""
    fi

    echo $MAINTENANCEID
}

# Main function
function main() {
    if [ "$MODE" == "create" ]; then
        MAINTENANCEID=$(maintenance_exists)
        if [ -n "$MAINTENANCEID" ]; then
            echo "Maintenance period for: $HOSTNAME already exists. Overwriting..."
            PAYLOAD='{
                "jsonrpc": "2.0",
                "method": "maintenance.delete",
                "params": ['"$MAINTENANCEID"'],
                "auth": "'$TOKEN'",
                "id": 1
            }'
            RESPONSE=$(curl -s -X POST -H "$HEADERS" -d "$PAYLOAD" $URL)
        fi
        maintenance_set
    elif [ "$MODE" == "delete" ]; then
        MAINTENANCEID=$(maintenance_exists)
        if [ -n "$MAINTENANCEID" ]; then
            maintenance_delete
        else
            echo "No maintenance period defined for: $HOSTNAME"
        fi
    fi
}


# Call the main function
main
