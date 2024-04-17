#!/bin/bash
# DESC: change ORACLE_SID for DB administration tasks and generate a nice PS1 prompt
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: orasid.sh,v $
# NOTE: to get it running, insert this line into .bashrc
# alias orasid=". bin/orasid.sh" 

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

COUNT=$(grep -v '^#' /etc/oratab | grep -v '^$' | sort | cut -d: -f1|wc -l)

echo
echo "reading /etc/oratab..."
for NR in $(seq 1 $COUNT)
do
   echo -n "   $NR) " ; echo "$( grep -v '^#' /etc/oratab | grep -v '^$' | sort -r | cut -d: -f1 | tail -n$NR | head -n1 )"
   #NR=$(( $NR + 1 ))
done
echo
echo -n "Please select: "
read SELECT
echo $SELECT | grep -q [0123456789]
if [ $? -eq 0 ]
then
   ORACLE_SID=$(grep -v '^#' /etc/oratab | grep -v '^$' | sort -r | cut -d: -f1 | tail -n$SELECT | head -n1)
   export ORACLE_SID
else
   echo sorry ... wrong choice
   exit 1
fi

PS1="${ORACLE_SID}:\h \w\$ "
export PS1

################################################################################
# $Log: orasid.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:16  chris
# Initial revision
#
