#!/bin/bash
###############################################################################################################
# DESC: tool wich grep directory for text files containing search pattern and open files (documentation tool)
# WHO: chris
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
# 20191201 -> rewrite and deduped functions

EDIT=vim
SCRIPT="$(basename $0)"
ARCHIV_DIR='archiv' # if you move files into this dir, they get ignored unless -a is given
DOC="$HOME/vdoc"

### CHECK FOR OPTIONS AND ARGS
echo "$1" | egrep -q '^-' 
if [ $? -eq 0 ] ; then # search for option
   OPT="$1" 
   shift 
   ARG="$*"
   echo "$OPT" | egrep -q '^-a' 
   if [ $? -eq 0 ] ; then # if -a, then fake dummy pattern
      ARCHIV_DIR='xDontIgnoreArchiveDirsX'
   fi
else # if no option is given, we assume it is a search
   OPT='-s' 
   ARG="$*"
   if [ "x" == "x$ARG" ] ; then OPT='--help' ; fi
fi

HEAD="#########################################################################################################
# PROJEKT: $(echo $ARG | cut -d\  -f2)
# OWNER: $(logname)
# VERSION: $(date +%Y%m%d) 
#########################################################################################################
DESCRIPTION:
------------

NOTES:
------------
"
### FUNCTIONS #################################################################
help(){
   echo
   echo "   Usage:"
   echo "   $SCRIPT    [search pattern]  search project files, dirs with /$ARCHIV_DIR/ excluded"
   echo "   $SCRIPT -s [search pattern]  search project files, dirs with /$ARCHIV_DIR/ excluded"
   echo "   $SCRIPT -a [search pattern]  search project files"
   echo "   $SCRIPT -l                   list group folders"
   echo "   $SCRIPT -c [grp/name]        create new project"
   echo
   exit 0
}

do-search(){
   FILES="$(fgrep -lir $ARG $DOC/ | grep -v /$ARCHIV_DIR/ | sort )"
   COUNT=$(echo "$FILES" | wc -w)
   if [ $COUNT -eq 0 ] ; then
      echo nothing found ...
      exit 0
   elif [ "$COUNT" == "1" ] ;  then
      SELECT=1
      view-file
      exit 0
   fi
   SEARCHED=1
}

select-file(){
   clear
   echo
   echo "WHICH DOC DO YOU WANT TO SEE ?"
   echo "------------------------------"
   echo "Search: $ARG"
   echo
   for NR in $(seq 1 $COUNT) ; do
      echo -n "   "
      [ $COUNT -ge 10 ] && [ $NR -le 9 ] && echo -n ' '
      echo -n "$NR) " 
      echo $FILES | cut -d\  -f$NR | sed "s#$DOC/##g;s/.txt$//"
      NR=$(( $NR + 1 ))
   done
   echo "   q) QUIT"
   echo
   echo -n "Please select: "
   read SELECT
   if [ "$SELECT" == "q" ] ; then
      exit 0
   fi
}

view-file() 
{
   VIEW=true
   echo "$SELECT" | grep -q [0123456789]
   if [ $? -eq 0 ] ; then
      for NR in $(seq 1 $COUNT) ; do
         if [ "$SELECT" == "$NR" ] ; then
            $EDIT +"set ic|/$ARG" $(echo $FILES | cut -d' '  -f $SELECT)
         fi
      done
   fi
}

create-file(){
   VDIR="$(dirname $DOC/$ARG)"
   VFILE="$DOC/$ARG.txt"
   test -d "$VDIR" || mkdir -p "$VDIR"
   if [ ! -f "$VFILE" ]
   then
      echo "$HEAD" > "$VFILE"
      $EDIT "$VFILE"
      exit 0
   else
      echo "ERROR, FILE EXISTS: $VFILE"
      exit 1
   fi
}

###############################################################################

### DO HELP
echo "$OPT" | egrep -q '^-h|^--help|^--usage|^$' && help

### CREATE NEW FILE
echo "$OPT" | egrep -q '^-c'
if [ $? -eq 0 ]
then
   create-file "$ARG"
fi

### LIST DIRs
echo "$OPT" | egrep -q '^-l'
if [ $? -eq 0 ]
then
   echo
   find "$DOC/" -type d | sed "s#$DOC/#   #g" 
   echo
   exit 0
fi

### SEARCH NORMAL
while true
do
   if [ "x" == "x$SEARCHED" ] ;  then
      do-search "$ARG" 
   fi
   select-file "$FILES" 
   view-file "$FILE"
done

