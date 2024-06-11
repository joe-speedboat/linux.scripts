#!/bin/bash
# DESC: collect connections to specific ports into files with last access
#       this way, we can trace who is accessing services without touching config

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#!/bin/bash

# File to store the connection states
LOG_FILE="/var/log/connectionstate.log"

# Ports to monitor
PORTS="25,465,587"

# Debug mode (set to 1 for debug output, 0 to disable)
DEBUG=0

# IP address to ignore (by default, the local host's IP address)
IP_IGNORE=$(hostname -i)

# Function to get current connections
get_connections() {
  ss -tnp | awk -v ports="$PORTS" -v ip_ignore="$IP_IGNORE" '
  BEGIN {
    split(ports, port_array, ",");
    for (i in port_array) port_list[port_array[i]] = 1;
  }
  $4 ~ /:[0-9]+$/ {
    split($4, addr_port, ":");
    port = addr_port[2];
    split($5, client_addr, ":");
    ip = client_addr[1];
    if (port_list[port] && ip !~ /^127\.0\.0\.1/ && ip !~ /^::1/ && ip !~ ip_ignore && ip ~ /^10\.|^192\.168\./) {
      print ip ":" port;
    }
  }'
}

# Function to log connections with timestamp
log_connections() {
  local timestamp=$(date +"%Y-%m-%d_%H%M%S")
  local connections=$(get_connections)
  local temp_file=$(mktemp)

  # Read the existing log file into an associative array
  declare -A log_entries
  if [[ -f "$LOG_FILE" ]]; then
    while IFS=: read -r ip port old_timestamp; do
      log_entries["$ip:$port"]=$old_timestamp
    done < "$LOG_FILE"
  fi

  # Update log entries with current connections
  if [[ ! -z "$connections" ]]; then
    while read -r connection; do
      if [[ -n ${log_entries[$connection]} ]]; then
        # Update the timestamp for existing connection
        if [[ $DEBUG -eq 1 ]]; then
          echo "Updating timestamp for existing connection: ${connection}"
        fi
        log_entries["$connection"]=$timestamp
      else
        # Add new connection
        if [[ $DEBUG -eq 1 ]]; then
          echo "Inserting new connection: ${connection}"
        fi
        log_entries["$connection"]=$timestamp
      fi
    done <<< "$connections"
  fi

  # Write the updated log entries back to the log file
  for entry in "${!log_entries[@]}"; do
    echo "${entry}:${log_entries[$entry]}" >> "$temp_file"
  done

  mv "$temp_file" "$LOG_FILE"
}

# Main loop to run every minute
while true; do
  log_connections
  sleep 1
done

