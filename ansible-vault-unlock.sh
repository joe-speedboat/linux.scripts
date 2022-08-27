#!/bin/bash
# DESC: ansible-vault password handler which is runtime persistent

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


# INSTALL:
# sed -i 's#^.vault_password_file=.*#vault_password_file=/etc/ansible/ansible-vault-unlock.sh#' /etc/ansible/ansible.cfg

echo '#!/bin/bash
# without arg -> ask/print secret
# arg: -d     -> remove secret

NAME=vault
PW_CNT=$(keyctl search @u user $NAME 2>/dev/null | wc -l)
if [ $PW_CNT -lt 1 ]
then
   read -s -p "Feed vault password: " PASS
   keyctl add user $NAME  "$PASS" @u 2>/dev/null
else
   keyctl print $(keyctl search @u user $NAME 2>/dev/null)
fi

if [ "$1" == "-d" ]
then
   echo "INFO: removing key"
   keyctl purge user $NAME
fi' > /etc/ansible/ansible-vault-unlock.sh

chmod 700 /etc/ansible/ansible-vault-unlock.sh

/etc/ansible/ansible-vault-unlock.sh
# Feed and remember the password for vault

echo '
#FEED ANSIBLE VAULT PASSWORD after reboot
   cmd: sudo -u rundeck --login /etc/ansible/ansible-vault-unlock.sh
' >> /etc/motd

################################################################################
