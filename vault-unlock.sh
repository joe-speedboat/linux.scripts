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
# sed -i 's#^.vault_password_file=.*#vault_password_file=/usr/local/bin/vault-unlock.sh#' /etc/ansible/ansible.cfg

echo '#!/bin/bash
# without arg -> ask/print secret
# arg: -r     -> read secret from stdin, only if not filled, do not print it
# arg: -d     -> remove secret

###### $HOME/.bashrc ######
# /usr/local/bin/vault-unlock.sh -r
# if [ ! -S ~/.ssh/ssh_auth_sock ]; then
#   eval `ssh-agent`
#   ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
# fi
# export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
# ssh-add -l > /dev/null || cat ~/.ssh/id_rsa | SSH_ASKPASS=/usr/local/bin/vault-unlock.sh ssh-add -
###########################

NAME=vault

if [ "$1" == "-d" ]
then
   echo "INFO: removing key"
   keyctl purge user $NAME
   exit 0
fi

PW_CNT=$(keyctl search @u user $NAME 2>/dev/null | wc -l)
if [ $PW_CNT -lt 1 ]
then
   read -s -p "Feed vault password: " PASS
   keyctl add user $NAME  "$PASS" @u &>/dev/null
   echo
else
   [ "$1" == "-r" ] && exit 0
   keyctl print $(keyctl search @u user $NAME 2>/dev/null)
fi

' > /usr/local/bin/vault-unlock.sh

chmod 755 /usr/local/bin/vault-unlock.sh

/usr/local/bin/vault-unlock.sh
# Feed and remember the password for vault


################################################################################
