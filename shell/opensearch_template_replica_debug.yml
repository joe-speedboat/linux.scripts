#!/bin/bash
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Function to process and display template information
process_template() {
  local name=$1
  local settings=$2
  local replicas

  # Extract number_of_replicas; default to 'Not Set' if not present
  replicas=$(echo "$settings" | jq -r '.index.number_of_replicas // "Not Set"')

  # Print template name and number of replicas
  echo "Template Name: $name, Number of Replicas: $replicas"
}

# Fetch and process legacy index templates
legacy_templates=$(curl -s -X GET "localhost:9200/_cat/templates?format=json")

echo "Legacy Index Templates:"
echo "$legacy_templates" | jq -c '.[]' | while IFS= read -r template; do
  name=$(echo "$template" | jq -r '.name')
  # Fetch the full template to get settings
  settings=$(curl -s -X GET "localhost:9200/_template/$name" | jq -c ".[\"$name\"].settings")
  process_template "$name" "$settings"
done

# Fetch and process composable index templates
composable_templates=$(curl -s -X GET "localhost:9200/_index_template" | jq -c '.index_templates[]')

echo -e "\nComposable Index Templates:"
echo "$composable_templates" | while IFS= read -r template; do
  name=$(echo "$template" | jq -r '.name')
  settings=$(echo "$template" | jq -c '.index_template.template.settings')
  process_template "$name" "$settings"
done

