#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

### INSTALL ###
# curl https://raw.githubusercontent.com/joe-speedboat/shell.scripts/master/vault-unlock.sh > $HOME/bin/vault-unlock.sh
# chmod 700 $HOME/bin/vault-unlock.sh
# sed -i "s#^.vault_password_file=.*#vault_password_file=$HOME/bin/vault-unlock.sh#" /etc/ansible/ansible.cfg
# add .bashrc snipped to ansible and ssh user
# grep '$HOME/bin/vault-unlock.sh' $HOME/.bashrc || echo '. $HOME/bin/vault-unlock.sh -b' >> $HOME/.bashrc

### DESCRIPTION ############################################################
# Due lot of ansible work, I needed a script who can handle:
# - ansible vault password handler , which is not persistent across reboots
# - ansible vault password must not go into filesystem backup
# - ssh-private-key passphrase is same as ansible vault password handlers secret
# - must get called on first login via .bashrc, then it persists until machine reboot
############################################################################
# without arg -> 1st ask, then print secret key until reboot
# arg: -b     -> .bashrc mode
# arg: -d     -> remove secret
# arg: -D     -> remove secret and ssh-agent
# arg: -r     -> read secret from stdin, only if not filled, do not print it

SCRIPT=$HOME/bin/vault-unlock.sh
SSH_PRIV_KEY_CRYPT=~/.ssh/id_rsa
NAME=vault

############ REMOVE SECRET FROM VAULT #########################################
if [ "$1" == "-d" ] 
then
   echo "INFO: removing secret for $NAME"
   keyctl purge user $NAME
   exit 0
fi
################ REMOVE SECRET FROM VAULT AND CLEAN SSH-AGENT SECRET ##########
if [ "$1" == "-D" ]
then
   echo "INFO: removing secret for $NAME"
   keyctl purge user $NAME
   echo "INFO: removing ssh-agent"
   ssh-add -D
   rm -f ~/.ssh/$HOSTNAME-agent.sh 2>/dev/null
   pkill -9 -f ssh-agent -u $USER
   unset SSH_AUTH_SOCK
   unset SSH_AGENT_PID
   exit 0
fi
################### READ VAULT SECRET, IF NOT EXIST ###########################
if [ "$1" == "-r" -a $(keyctl search @u user $NAME 2>/dev/null | wc -l) -lt 1 ]
then
   read -s -p "Feed vault password: " PASS
   keyctl add user $NAME  "$PASS" @u &>/dev/null
   echo
fi
################### BASHRC MODE ###############################################
if [ "$1" == "-b" ]
then
   ### ASK FOR SECRET IF NEEDED
   if [ $(keyctl search @u user $NAME 2>/dev/null | wc -l) -lt 1 ]
   then
      read -s -p "Feed vault password: " PASS
      keyctl add user $NAME  "$PASS" @u &>/dev/null
      echo
   fi

  # RESTORE SSH-AGENT SETTINGS
  if [ -f ~/.ssh/$HOSTNAME-agent.sh ]
  then
    # recover existing ssh-agent settings
    . ~/.ssh/$HOSTNAME-agent.sh

    ps $SSH_AGENT_PID >/dev/null 2>&1
    if [ $? -ne 0 ] 
    then
      echo "INFO: removing existing ssh-agent due invalid config"
      ssh-add -D
      rm -fv ~/.ssh/$HOSTNAME-agent.sh
      pkill -9 -f ssh-agent -u $USER
      unset SSH_AUTH_SOCK
      unset SSH_AGENT_PID
    fi
  fi

  ###  START SSH-AGENT IF NEEDED
  if [ ! -f ~/.ssh/$HOSTNAME-agent.sh ]
  then
     echo "INFO: Initializing ssh-agent"
     ssh-agent | grep -v 'Agent pid' > ~/.ssh/$HOSTNAME-agent.sh
     . ~/.ssh/$HOSTNAME-agent.sh
  fi

  ssh-add -l > /dev/null 
  if [ $? -ne 0 ] 
  then
    ### ADD SSH-KEY TO AGENT
    $SCRIPT | SSH_ASKPASS=cat setsid -w ssh-add $SSH_PRIV_KEY_CRYPT
    ssh-add -l > /dev/null || echo "ERROR: could not add ssh-agent key, maybe passphrase is invalid?"
  fi
fi
####################### NO ARGS, READ/PRINT SECRET ############################
if [ $# -eq 0 ] ### ARG COUNT IS 0
then
   if [ $(keyctl search @u user $NAME 2>/dev/null | wc -l) -gt 0 ]
   then
      keyctl print $(keyctl search @u user $NAME 2>/dev/null)
   else
      read -s -p "Feed secret for $NAME: " PASS
      keyctl add user $NAME  "$PASS" @u &>/dev/null
      echo
   fi
fi
################################################################################
