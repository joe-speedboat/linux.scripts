#!/bin/sh
# DESC: Restore filesystem permissions from RPM database.
# DEPS: Bash, GNU utils, rpm
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: rpm-perm-restore.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

case "$#" in 1) pkg="$1";; *) echo "Usage: $(basename $0) <rpm>" ; exit 127;; esac
rpm -q --dump ${pkg}|while read t; do
 t=( ${t} ); for i in 3 4; do case "${#t[$i]}" in 7)
 echo "chmod ${t[$i]:3:4} ${t[0]}"
 echo "chown ${t[5]}.${t[6]} ${t[0]}";;
esac; done; done; exit 0

################################################################################
# $Log: rpm-perm-restore.sh,v $
# Revision 1.2  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:17  chris
# Initial revision
#
