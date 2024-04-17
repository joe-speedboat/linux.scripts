#!/bin/sh
###############################################################################################################
# DESC: execution helper for esxi which log output into script itself
# WHO: chris
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


echo '
# place all your comands line by line below
date
esxcli storage vmfs unmap -l SATA
# end of comands to execute
' | egrep -v '^$|^#' | while read cmd
do
   echo "++++++++++ CMD: $cmd / $(date) / $(uname -n)" | tee -a $0
   $cmd 2>&1 | tee -a $0
done

exit
######### ALL CMD OUTPUT WILL SHOW UP HERE AS WELL AS ON STDOUT #########
