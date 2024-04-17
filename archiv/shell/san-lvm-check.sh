#!/bin/bash
# DESC: san-lvm check to view disk assigning from WWID to lvm and do some checks
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: san-lvm-check.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

HOST=$(hostname -s)

multipath -l > /tmp/$$.tmp.mp

# pick up all san disks and pick pv-data, WWID
for DEV in /dev/mpath/*
do
   pvdisplay $DEV 2>/dev/null | egrep 'PV Name|PV UUID' >> /tmp/$$.tmp
   grep "$(basename $DEV) " /tmp/$$.tmp.mp >> /tmp/$$.tmp
done

echo "HOST;VG;PV DEV;PV UUID;;WWID;PE TOT;PE FREE;VG CHECK;PV CHECK"

# pick up all VGs and extract all the needed inf for the checks
for VG in $(vgs 2>/dev/null  | awk '{print $1}' | egrep -v '^VG|^rhvg|_local')
do
   vgck $VG 2>/dev/null
   if [ $? -eq 0 ]
   then
      VGCK=OK
   else
      VGCK=FAIL
   fi
   for PVINFO in $(vgdisplay -v $VG 2>/dev/null | egrep 'PV UUID|Total PE / Free PE' | \
                   sed 's#Total PE / Free PE#PE INFO#g' | sed 's#/##g'| awk '{print $3":"$4}' | \
                   tr '\n' ' ' | sed 's/: /:/g')
   do
      PVUUID=$(echo $PVINFO | cut -d: -f1)
      PE=$(echo $PVINFO | cut -d: -f2)
      PEFREE=$(echo $PVINFO | cut -d: -f3)
      PVDEV=$(grep -B1 $PVUUID /tmp/$$.tmp | grep 'PV Name' | awk '{ print $3}' )
      echo $PVDEV | grep -q /dev/ || PVDEV=Missing
      if [ "$PVDEV" == "Missing" ]
      then
         PVCK=Missing
         WWID=Missing
      else
         WWID=$(grep -A2 "PV Name .* $PVDEV$" /tmp/$$.tmp | grep 'HSV300' | cut -d'(' -f2 | cut -d')' -f1)
         if [ $(pvck $PVDEV 2>/dev/null | egrep 'Found label|Found text metadata area' | wc -l) -eq 2 ]
         then
            PVCK=OK
         else
            PVCK=FAIL
         fi
      fi
      echo "$HOST;$VG;$PVDEV;$PVUUID;$WWID;$PE;$PEFREE;$VGCK;$PVCK"
   done
done

rm -f /tmp/$$.tmp*

################################################################################
# $Log: san-lvm-check.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:18  chris
# Initial revision
#
