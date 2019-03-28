#!/bin/bash
###############################################################################################################
# DESC: tool wich grep directory for text files containing search pattern and open files (documentation tool)
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: vdoc.sh,v $
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# CHANGELOG:
###############################################################################################################
# 20181209 -> changed default vdoc filename to $TOPIC.txt
#             convert: find vdoc/ -type f -not -name '*.txt' -exec mv "{}" "{}.txt" \;

DOC="$HOME/vdoc"
FIND="$*"
EDIT=vim
HEAD="#########################################################################################################
# PROJEKT: $(echo $FIND | cut -d\  -f2)
# OWNER: $(who | awk '{print $1}')
# VERSION: $(date +%Y%m%d) 
#########################################################################################################
DESCRIPTION:
------------

NODE NAMES:
-----------

HEALTH CHECK:
-------------

IMPORTANT NOTES:
----------------
"

help()
{
   echo
   echo "   Usage:"
   echo "   $(basename $0)    [search pattern]  search project files, archive path excluded"
   echo "   $(basename $0) -a [search pattern]  search project files, archive path included"
   echo "   $(basename $0) -l                   list group folders"
   echo "   $(basename $0) -c [grp/name]        create new project"
   echo
   exit 0
}

echo "$FIND" | egrep -q '^-h|--help|--usage|^$' && help

echo "$FIND" | egrep -q '^-c'
if [ "$?" == "0" ]
then
   mkdir -p $(dirname $DOC/$(echo $FIND | cut -d" "  -f2))
   echo "$HEAD" >> $DOC/$(echo $FIND | cut -d" "  -f2).txt
   $EDIT $DOC/$(echo $FIND | cut -d" "  -f2).txt
   exit 0
fi

echo "$FIND" | egrep -q '^-l'
if [ "$?" == "0" ]
then
   echo
   find "$DOC/" -type d | sed "s#$DOC/#   #g" 
   echo
   exit 0
fi


echo "$FIND" | egrep -q '^-a'
if [ "$?" == "0" ]
then
shift
FIND="$*"
do-search()
{
   SEARCHED=
   FILES=$(fgrep -lir "$FIND" "$DOC/" | sort)
   COUNT=$(echo $FILES | wc -w)
   if [ "$COUNT" == "0" ] 
   then
      echo nothing found ...
      exit 0
   fi
   if [ "$COUNT" == "1" ] 
   then
      SELECT=1
      view-file
      exit 0
   fi
   SEARCHED=true
}
else
do-search()
{
   SEARCHED=
   FILES=$(fgrep -lir "$FIND" "$DOC/" |grep -iv /archiv/ | sort)
   COUNT=$(echo $FILES | wc -w)
   if [ "$COUNT" == "0" ] 
   then
      echo nothing found ...
      exit 0
   fi
   if [ "$COUNT" == "1" ] 
   then
      SELECT=1
      view-file
      exit 0
   fi
   SEARCHED=true
}
fi

select-file()
{
   clear
   echo
   echo "WHICH DOC DO YOU WANT TO SEE ?"
   echo "------------------------------"
   echo "Search: $FIND"
   echo
   for NR in $(seq 1 $COUNT)
   do
      echo -n "   "
      [ $COUNT -ge 10 ] &&  [ $NR -le 9 ] && echo -n ' '
      echo -n "$NR) " 
      echo $FILES | cut -d\  -f$NR | sed "s#$DOC/##g;s/.txt$//"
      NR=$(( $NR + 1 ))
   done
   echo "   q) QUIT"
   echo
   echo -n "Please select (q=quit): "
   read SELECT
   if [ "$SELECT" == "q" ] 
   then
      exit 0
   fi
}

view-file() 
{
   VIEW=true
   echo "$SELECT" | grep -q [0123456789]
    if [ "$?" == "0" ]
   then
   for NR in $(seq 1 $COUNT)
   do
      if [ "$SELECT" == "$NR" ]
      then
         $NOEDIT $EDIT +"set ic|/$FIND" $(echo $FILES | cut -d' '  -f $SELECT)
      fi
   done
   fi
}

while true
do
   if [ -n "$SEARCHED"]
   then
      do-search
   fi
   select-file
   view-file
done

################################################################################
# $Log: vdoc.sh,v $
# Revision 1.2  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:21  chris
# Initial revision
#
