#!/bin/bash
# DESC: VCSA 6.7 scp backup
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
# INSPIRED BY: https://pubs.vmware.com/vsphere-6-5/index.jsp?topic=%2Fcom.vmware.vsphere.vcsapg-rest.doc%2FGUID-222400F3-678E-4028-874F-1F83036D2E85.html 

# YOU CAN ADD THIS TO CRON IF YOU WANT TO RUN SCHEDULED ######################################
# curl https://raw.githubusercontent.com/joe-speedboat/scripts/master/vcsa_67_status.sh > /usr/local/bin/vcsa_67_status.sh
# chmod 0700 /usr/local/bin/vcsa_67_status.sh
# crontab -e -u root
# 1 3 * * * /usr/local/bin/vcsa_67_status.sh > /storage/log/vcsa_67_status-week-$(date '+%V').log

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/java/jre-vmware/bin:/opt/vmware/bin:/opt/vmware/bin

echo "Date: $(date --utc)"
echo "---------- Service Control Status ----------"
service-control --status | sed '/^$/d;s/ /\n/g;s/\(\w.*:$\)/\n\1\n-----------/g' | sed 's/^/     /'
echo
echo

echo "---------- Show all Services Status ----------"
systemctl list-unit-files | grep enabled | grep service | awk '{print $1}' | while read svc
do
   systemctl status $svc >/dev/null 2>&1 && echo "OK $svc" || echo "FAIL $svc"
done | sort | sed 's/^/     /'

echo "---------- Show all Services ----------"
systemctl list-unit-files --type=service | cat | sed 's/^/     /'

echo "---------- lsblk ----------"
lsblk | sed 's/^/     /'

echo "---------- Disk usage ----------"
df -kP | sed 's/^/     /'
echo "----------"
df -iP | sed 's/^/     /'

echo "---------- RPM configfiles md5sum ----------"
rpm -qa --configfiles | xargs md5sum 2>/dev/null | sed 's/^/     /'

echo "---------- pstree ----------"
pstree --vt100 -l -u -U | sed 's/^/     /'

echo "---------- lsof - listen ports ----------"
lsof -i -P -n | grep LISTEN | sed 's/^/     /'

