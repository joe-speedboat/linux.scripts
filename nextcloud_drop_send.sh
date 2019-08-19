#!/bin/bash
#########################################################################################
# DESC: script to upload multiple files into nextcoud drop folder
# tested with vRA 7.3 / CloudClient 4.4
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
#
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# SETUP INSTRUCTIONS
#########################################################################################
# 1) create shared folder with no password protection 
# 2) set upload only (drop folder)
# 3) copy link url
# 4) insert vars, extracted from link above
# 5) have fun

NC_URL='https://nc.domain.org'
TOKEN='aU2S6PgptNz4bNc'

test -f "$1" || (echo "Usage: $(basename $0) <file1> [file2] ..." ; exit 0)

for f in $*
do
   echo "Uploading: $f"
   curl -u $TOKEN: -H "X-Requested-With: XMLHttpRequest" "$NC_URL/public.php/webdav/" -T "$f"
done
