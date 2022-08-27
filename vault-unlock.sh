#!/bin/bash
# DESC: ansible-vault password handler which is runtime persistent

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


### INSTALL###
# curl https://raw.githubusercontent.com/joe-speedboat/shell.scripts/master/vault-unlock.sh > /usr/local/bin/vault-unlock.sh
# chmod 755 /usr/local/bin/vault-unlock.sh
# sed -i 's#^.vault_password_file=.*#vault_password_file=/usr/local/bin/vault-unlock.sh#' /etc/ansible/ansible.cfg
# add .bashrc snipped to ansible and ssh user
# logout, login to ansible user

#!/bin/bash
### DESCRIPTION ############################################################
# Due lot of ansible work, I needed a script who can handle:
# - ansible vault password handler , which is not persistent across reboots
# - ansible vault password must not go into filesystem backup
# - ssh-private-key passphrase is same as ansible vault password handlers secret
# - must get called on first login via .bashrc, then it persists until machine reboot
############################################################################
# without arg -> ask/print secret key
# arg: -r     -> read secret from stdin, only if not filled, do not print it
# arg: -d     -> remove secret
# arg: -D     -> remove secret key and ssh-agent

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
if [ "$1" == "-D" ]
then
   echo "INFO: removing key"
   keyctl purge user $NAME
   echo "INFO: removing ssh-agent"
   ssh-add -D
   test -f ~/.ssh/ssh_auth_sock && rm -f ~/.ssh/ssh_auth_sock
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

################################################################################
