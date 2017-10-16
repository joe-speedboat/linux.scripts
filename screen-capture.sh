#!/bin/bash
# DESC: really handy scren shot tool
# $Author: chris $
# $Revision: 1.3 $
# $RCSfile: screen-capture.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

DIR=$HOME/shot
TMP=/tmp/$(basename $0).tmp
test -d $DIR || mkdir $DIR
test -f $TMP && TEXT="$(cat $TMP)"
yad --title "Screen Shot Name" --entry --entry-text="$TEXT" --text "Enter Name of PNG Image:" > $TMP 2>/dev/null
FILE="$(cat $TMP)_$(date '+%Y%m%d-%H%M%S')"
scrot -s "$DIR/$FILE.png"
exit 0

################################################################################
# $Log: screen-capture.sh,v $
# Revision 1.3  2017/10/08 18:55:02  chris
# changed dialog to yad, make it remembering last value
#
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:18  chris
# Initial revision
#
