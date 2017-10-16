#!/bin/bash
# DESC: check oracle table space usage
# $Revision: 1.2 $
# $RCSfile: oracle-check-tablespace.sh,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

i=0

while [ $i -le 240 ]; do

sqlplus -S -L "/ as sysdba" << EOF
  set linesize 150;
  set feedback off;
  select
    to_char (sysdate, 'YYYY-MM-DD HH24:MI:SS') "Date",
   name "Tablespace",
    round(total/1024/1024) "Total (MB)",
    round(used/1024/1024) "Used (MB)",
    round((total-used)/1024/1024) "Free (MB)",
    round(used/total*100) "Usage (%)"
  from (
    select
      a.name,
      sum(b.file_size * a.blocksize) total,
      sum(b.allocated_space * a.blocksize) used
    from
      ts$ a,
      v\$filespace_usage b
    where
      a.ts# = b.tablespace_id(+)
      and a.contents$ = 0 -- exclude temp tablespaces
      and a.online$ < 3 -- exclude dropped tablespaces
    group by
      a.name
    union all
    select
      sh.tablespace_name,
      sum(sh.bytes_used + sh.bytes_free) total_mb,
      sum(sh.bytes_used) used_mb
    from
      v\$temp_space_header sh
    group by
      tablespace_name
  )
  order by 1;
EOF

i=$(expr $i + 1)
sleep 5

done

################################################################################
# $Log: oracle-check-tablespace.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:16  chris
# Initial revision
#
