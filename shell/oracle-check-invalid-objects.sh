#!/bin/bash
# DESC: search for invalid objects
# $Revision: 1.2 $
# $RCSfile: oracle-check-invalid-objects.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


SUBJ="INVALID OBJECTS for $ORACLE_SID on $(uname -n)"
TO='joe@bitbull.ch'

sqlplus -S -L "/ as sysdba" << EOF | egrep -v 'PUBLIC|OLAPSYS'
  set linesize 300;
  set pagesize 300;
  set feedback off;
  column object_name format a30 
  spool invalid_object.alert          
  SELECT  OWNER, OBJECT_NAME, OBJECT_TYPE, STATUS 
  FROM    DBA_OBJECTS 
  WHERE   STATUS = 'INVALID' 
  ORDER BY OWNER, OBJECT_TYPE, OBJECT_NAME; 
  spool off          
EOF

if [ `cat invalid_object.alert | egrep -v 'PUBLIC|OLAPSYS' | wc -l` -gt 3 ]
then
    cat invalid_object.alert | egrep -v 'PUBLIC|OLAPSYS' | mail -s "$SUBJ" $TO
fi
rm -f invalid_object.alert

################################################################################
# $Log: oracle-check-invalid-objects.sh,v $
# Revision 1.2  2012/06/10 19:18:48  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:15  chris
# Initial revision
#
