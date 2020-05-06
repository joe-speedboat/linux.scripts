#!/bin/bash
#########################################################################################
# DESC: read files and create wiki like syntax
#########################################################################################
# Copyright (c) Chris Ruettimann <chris.ruettimann@uniqconsulting.ch>
#
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

file2wiki(){
if [ $# -gt 1 ] ; then
   for f in $*
   do
      test -f $f && file2wiki $f
   done
fi

f=$1
echo "<div class=\"toccolours mw-collapsible mw-collapsed\" style=\"width:60%\">
File: <b>$1</b>     Modified: <b>$( stat -c '%y' $1 | cut -d. -f1)</b>
<div class=\"mw-collapsible-content\">
<pre>"
cat $1
echo "</pre>
</div>
</div>
"
}

file2wiki $*
