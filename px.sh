#!/bin/bash
# DESC: handy and informative ps comand with integrated search function
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: px.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

PAT=$1
[ -z $PAT ] && PAT='.*'
ps  -eo ruser,ppid,pid,rss,vsz,pcpu,tty,args | head -n1
ps  -eo ruser,ppid,pid,rss,vsz,pcpu,tty,args | grep -i "$PAT" | egrep -v "RUSER.*COMMAND|grep -i $PAT|$$.*$(basename $0)|ps -eo ruser.*args"

################################################################################
# $Log: px.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:17  chris
# Initial revision
#
