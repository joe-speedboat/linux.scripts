#!/bin/bash
#########################################################################################
# DESC: extract ansible doc for fast/easy search and create alias for daily work
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

rpm -q ansible || (echo install ansible first ; exit 1)
cd
rm -f .ansible_all_doc.txt

for  t in cache callback connection inventory lookup module strategy vars
do
   ansible-doc -t $t -l | awk '{print $1}' | while read d
   do
     echo =============================== $t = $d =============================== >> .ansible_all_doc.txt
     ansible-doc -t $t $d >> .ansible_all_doc.txt
   done
done

grep .ansible_all_doc.txt .bashrc || echo 'alias adoc="less $HOME/.ansible_all_doc.txt"' >> .bashrc
