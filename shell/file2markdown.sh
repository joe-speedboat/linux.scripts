#!/bin/bash

# Check if at least one argument (file) is provided
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file1> [file2] [file3] ..."
  exit 1
fi

# Iterate over all the provided files
for i in "$@"
do
  # Check if the file exists
  if [ -f "$i" ]; then
    # Generate the Markdown documentation
    echo "<details><summary>$(ls -l "$i" | awk '{print $9" "$1" "$3"."$4}')</summary>"
    echo
    echo '```'
    cat "$i"
    echo '```'
    echo '</details>'
  else
    echo "File not found: $i"
  fi
done

