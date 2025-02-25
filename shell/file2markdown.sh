#!/bin/bash
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


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

