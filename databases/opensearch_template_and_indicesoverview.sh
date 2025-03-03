#!/bin/bash
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#!/bin/bash

ES_HOST="localhost:9200"

# Print header
printf "%-30s %15s %-25s %-30s\n" "INDEX_NAME" "MSG_COUNT" "LAST_WRITTEN" "TEMPLATE"
echo "----------------------------------------------------------------------------------------------------------------------"

# Get all index templates
declare -A template_map
while read -r template pattern; do
    pattern_clean=$(echo "$pattern" | tr -d '[]')
    template_map["$pattern_clean"]="$template"
done < <(curl -s "$ES_HOST/_cat/templates?h=name,index_patterns" | awk '{print $1, $2}')

# Get all indices
indices=$(curl -s "$ES_HOST/_cat/indices?h=index" | sort)

declare -A index_data

# Iterate over each index
for index in $indices; do
    # Get document count
    msg_count=$(curl -s "$ES_HOST/$index/_count" | jq -r '.count')

    # Get last written timestamp, trying multiple fields
    last_written=$(curl -s -XGET "$ES_HOST/$index/_search" -H 'Content-Type: application/json' -d'
    {
      "size": 1,
      "sort": [ { "@timestamp": { "order": "desc" } } ]
    }' | jq -r '.hits.hits[0].sort[0]')

    if [[ "$last_written" == "null" || -z "$last_written" ]]; then
        last_written=$(curl -s -XGET "$ES_HOST/$index/_search" -H 'Content-Type: application/json' -d'
        {
          "size": 1,
          "sort": [ { "timestamp": { "order": "desc" } } ]
        }' | jq -r '.hits.hits[0].sort[0]')
    fi

    # Convert timestamp from milliseconds to human-readable date
    if [[ "$last_written" != "null" && "$last_written" != "N/A" && -n "$last_written" ]]; then
        last_written_human=$(date -d @"$(($last_written / 1000))" +"%Y-%m-%d_%H:%M:%S")
    else
        last_written_human="N/A"
    fi

    # Determine matching template (if any)
    matched_template="NONE"
    for pattern in "${!template_map[@]}"; do
        if [[ "$index" =~ ^${pattern/\*/.*}$ ]]; then
            matched_template="${template_map[$pattern]}"
            break
        fi
    done

    # Store data for sorting
    index_data["$index"]="$msg_count $last_written $last_written_human $matched_template"
done

# Sort by last written timestamp (newest first)
for index in "${!index_data[@]}"; do
    echo "$index ${index_data[$index]}"
done | sort -k3 -nr | while read -r index msg_count last_written last_written_human matched_template; do
    printf "%-30s %15s %-25s %-30s\n" "$index" "$msg_count" "$last_written_human" "$matched_template"
done
