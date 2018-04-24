#!/bin/bash
# DESC: change screen resolution to custom screen sizes, not only for VNC
##########################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'
##########################################################################################################
SCREEN=$(xrandr  | grep ' connected ' | cut -d' ' -f1 | head -1)
X=$(xdpyinfo | grep dimensions: | awk '{print $2}' | cut -dx -f1)
Y=$(xdpyinfo | grep dimensions: | awk '{print $2}' | cut -dx -f2)

export MAIN_DIALOG="
 <window title=\"Change VNC resolution\">
 <hbox>
  <text>
    <label>X:</label>
  </text>
  <entry>
    <default>$X</default>
    <variable>X</variable>
  </entry>
  <text>
    <label>Y:</label>
  </text>
  <entry>
    <default>$Y</default>
    <variable>Y</variable>
  </entry>
   <button ok></button>
   <button cancel></button>
  </hbox>
  </window>
"

I=$IFS; IFS=""
for STATEMENTS in  $(gtkdialog --program=MAIN_DIALOG); do
  eval $STATEMENTS
done
IFS=$I

if [ "$EXIT" = "OK" ]; then
  RES="${X}x${Y}"
  echo $RES
  xrandr --newmode $RES $(cvt $(echo $RES | tr 'x' ' ') | grep Modeline | cut -d ' ' -f3-)
  xrandr --addmode $SCREEN $RES
  xrandr --output $SCREEN --mode $RES
fi

