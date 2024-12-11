#!/bin/bash

# Variables
log_file_pattern="/var/log/named/rpz.log*"
look_back_hours=24
subject="RPZ Mail report for $(hostname -f)"
mail_to="ticket@domain.tld"
mail_from="sender@domain.tld"
smtp_host="smtp://localhost:25"  # Local SMTP server without authentication

mail_report=1  # If 0, ignore sending the report, just print matches
fail_on_found=0  # Fail with exit 1 if records are found, just print if not found

# Date range for filtering logs
end_time=$(date '+%Y-%m-%d %H:%M:%S')
start_time=$(date --date="$look_back_hours hours ago" '+%Y-%m-%d %H:%M:%S')

# Temporary files
temp_log=$(mktemp)
output_temp=$(mktemp)

# Extract logs within the time range
zgrep -h "rpz" $log_file_pattern | awk -v start="$start_time" -v end="$end_time" '
BEGIN {
    # Convert start and end time to epoch seconds
    cmd = "date --date=\"" start "\" +%s";
    cmd | getline start_epoch;
    close(cmd);
    cmd = "date --date=\"" end "\" +%s";
    cmd | getline end_epoch;
    close(cmd);
}
{
    # Extract and reformat the log timestamp
    match($0, /^[0-9]+-[A-Za-z]+-[0-9]+ [0-9:.]+/, match_arr);
    timestamp = match_arr[0];
    gsub("-", " ", timestamp);
    cmd = "date --date=\"" timestamp "\" +%s";
    cmd | getline log_epoch;
    close(cmd);

    # Filter log lines within the time range
    if (log_epoch >= start_epoch && log_epoch <= end_epoch) {
        print $0;
    }
}' > "$temp_log"

# Check if there are any logs to process
if [[ ! -s "$temp_log" ]]; then
    echo "RPZ Log Overview (Time Range: $start_time - $end_time)"
    echo "No RPZ hits found."
    rm -f "$temp_log" "$output_temp"
    exit 0
fi

# Process logs and generate overview
echo "RPZ Log Overview (Time Range: $start_time - $end_time)" > "$output_temp"
echo -e "COUNT      CLIENT          TARGET\n--------------------------------" >> "$output_temp"

awk '/rpz/ {
    match($0, /client [^ ]+ ([^ ]+)#/, client);
    match($0, /\(([^\)]+)\)/, target);
    if (client[1] && target[1]) {
        combo[client[1] "|" target[1]]++
    }
} END {
    for (i in combo) {
        split(i, arr, "|");
        printf "%-10s %-15s %s\n", combo[i], arr[1], arr[2];
    }
}' "$temp_log" | sort -rn >> "$output_temp"

# Display report on console
cat "$output_temp"

# Exit with failure if records are found and fail_on_found is set
if [[ "$fail_on_found" -eq 1 ]]; then
    echo "Records found, exiting with status 1."
    rm -f "$temp_log" "$output_temp"
    exit 1
fi

# Send email if mail_report is set
if [[ "$mail_report" -eq 1 ]]; then
    s-nail -v \
        -r "$mail_from" \
        -S mta="$smtp_host" \
        -S smtp-auth=none \
        -s "$subject" \
        "$mail_to" < "$output_temp"
fi

# Cleanup
rm -f "$temp_log" "$output_temp"

