#!/bin/bash
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Example output
# TEMPLATE                       INDEX PATTERN             ACTIVE_INDEX                    MSG_COUNT LAST_WRITTEN             
# ----------------------------------------------------------------------------------------------------------------------
# rundeck-template               [rundeck_*]               rundeck_2                               0 N/A                      
# wlan-controller-template       [wlan-controller_*]       wlan-controller_2                    8062 2025-03-03 14:13:55      
# graylog-internal               [graylog_*]               graylog_122                          1464 2025-03-03 14:13:44      
# userscripts-template           [userscripts_*]           userscripts_2                         110 2025-03-03 14:11:18  


ES_HOST="localhost:9200"

# Print header
printf "%-30s %-25s %-25s %15s %-25s\n" "TEMPLATE" "INDEX PATTERN" "ACTIVE_INDEX" "MSG_COUNT" "LAST_WRITTEN"
echo "----------------------------------------------------------------------------------------------------------------------"

# Get all index templates
templates=$(curl -s "$ES_HOST/_cat/templates?h=name,index_patterns" | awk '{print $1, $2}')

while read -r template index_pattern; do
    # Remove brackets from index pattern
    index_pattern_clean=$(echo "$index_pattern" | tr -d '[]')

    # Find an active index matching the pattern
    active_index=$(curl -s "$ES_HOST/_cat/indices?h=index" | grep -E "^${index_pattern_clean/\*/.*}$" | head -n 1)

    if [[ -z "$active_index" ]]; then
        active_index="N/A"
        msg_count="0"
        last_written="N/A"
    else
        # Get document count for active index
        msg_count=$(curl -s "$ES_HOST/$active_index/_count" | jq -r '.count')

        # Fetch last written timestamp, trying multiple fields
        last_written=$(curl -s -XGET "$ES_HOST/$active_index/_search" -H 'Content-Type: application/json' -d'
        {
          "size": 1,
          "sort": [ { "@timestamp": { "order": "desc" } } ]
        }' | jq -r '.hits.hits[0].sort[0]')

        if [[ "$last_written" == "null" || -z "$last_written" ]]; then
            last_written=$(curl -s -XGET "$ES_HOST/$active_index/_search" -H 'Content-Type: application/json' -d'
            {
              "size": 1,
              "sort": [ { "timestamp": { "order": "desc" } } ]
            }' | jq -r '.hits.hits[0].sort[0]')
        fi

        # Convert timestamp from milliseconds to human-readable date
        if [[ "$last_written" != "null" && "$last_written" != "N/A" && -n "$last_written" ]]; then
            last_written=$(date -d @"$(($last_written / 1000))" +"%Y-%m-%d %H:%M:%S")
        else
            last_written="N/A"
        fi
    fi

    # Print result in formatted table
    printf "%-30s %-25s %-25s %15s %-25s\n" "$template" "$index_pattern" "$active_index" "$msg_count" "$last_written"
done <<< "$templates"
