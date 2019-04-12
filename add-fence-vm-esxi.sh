#!/bin/bash
#########################################################################################
# DESC: emulate ilo_ssh device on VMware esxi host to emulate real iLo fencing on nested VMs
# Tested with Alpine on esxi 6.5
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
#
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
# 
# ......................................
# .                esxi                .
# ......................................
# .  ||                      ^         .
# .  ||                      |         .
# .  || .-------.            |         .
# .  |'>| node2 |            |         .
# .  |  '-------'            |         .
# .  |                 .-----------.   .
# .  |  .-------.      | helper-vm |   .
# .  '->| node1 |      '-----------'   .
# .     '-------'            ^         .
# .                          |         .
# .     .--------------.     |         .
# .     | oVirt engine |-----'         .
# .     '--------------'               .
# .                                    .
# ......................................

# HOWTO INSTALL #######################################
### INSTALL SSH KEYS
# ssh -lroot helper-vm
#    ssh-keygen
#    ssh-copy-id root@esxi
#    test -d /home/fence/ || mkdir -p /home/fence/
#    addgroup fence
#    chown root.fence /home/fence/           
#    chmod 770 /home/fence/          
#    mv .ssh /home/fence/
#    ssh root@esxi -i /home/fence/.ssh/id_rsa
#       cat .ssh/authorized_keys >> /etc/ssh/keys-root/authorized_keys
#       rm -f .ssh/authorized_keys
#
### CONFIGURE FENCING FOR VMS
# add-fence-vm.sh <esxi-name> <compute-node-name> <password>
#    eg: add-fence-vm.sh esxi node1 redhat

export LANG=en
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin

if [ $# -ne 3 ]
then
   echo "desc: emulate ilo_ssh device on VMware esxi host to emulate real iLo fencing on nested VMs (nested vm tests)"
   echo "usage: $(basename $0) <esxi-name> <vm-name> <fence-password>"
   exit 1
else
   ESX="$1"
   VM="$2"
   PW="$3"

   ssh root@$ESX -i /home/fence/.ssh/id_rsa vim-cmd vmsvc/getallvms | grep  -q " $VM "
   if [ $? -ne 0 ]
   then
      echo ERROR: VM $VM does not exist
      exit 1
   fi

   id $VM >/dev/null 2>&1
   if [ $? -eq 0 ]
   then
      echo ERROR: Fence user $VM does exist, nothing to do
      exit 1
   fi
fi

adduser -D -G fence -h /home/fence/$VM $VM
echo -e "$PW\n$PW" | passwd $VM

test -d /home/fence/$VM/bin || mkdir -p /home/fence/$VM/bin
cp -av /home/fence/.ssh /home/fence/$VM/
chmod -R o-rwX,g-rwX,u=rwX /home/fence/$VM/.ssh 
chown -R $VM.fence /home/fence/$VM/

# ---------------------------- START VM ----------------------
echo '#!/bin/sh
. /home/fence/$USER/.profile
export LANG=en

ssh $ESX "vim-cmd vmsvc/getallvms | grep \" $USER \" | cut -d\  -f1 | xargs vim-cmd vmsvc/power.on 2>/dev/null" | grep -q "Powering on VM:"
if [ $? -eq 0 ]
then
   echo EnabledState=enabled
   logger -t fence-vm "vm $USER has power state on"
else
   echo EnabledState=disabled
   logger -t fence-vm "vm $USER has power state off"
fi
' > /home/fence/$VM/bin/start

# ----------------------------- STATUS VM ---------------------
echo ' #!/bin/sh
. /home/fence/$USER/.profile
export LANG=en

ssh $ESX "vim-cmd vmsvc/getallvms | grep \" $USER \" | cut -d\  -f1 | xargs vim-cmd vmsvc/power.getstate" | grep -q "Powered off"
if [ $? -ne 0 ]
then
   echo EnabledState=enabled
   logger -t fence-vm "vm $USER has power state on"
else
   echo EnabledState=disabled
   logger -t fence-vm "vm $USER has power state off"
fi
' > /home/fence/$VM/bin/show

# ---------------------------- STOP VM -----------------------
echo '#!/bin/sh
. /home/fence/$USER/.profile                                                                                                                                                                                         
export LANG=en

ssh $ESX "vim-cmd vmsvc/getallvms | grep \" $USER \" | cut -d\  -f1 | xargs vim-cmd vmsvc/power.off 2>/dev/null" | grep -q "Powering off VM"
if [ $? -ne 0 ]
then
   echo EnabledState=enabled
   logger -t fence-vm "vm $USER has power state on"
else
   echo EnabledState=disabled
   logger -t fence-vm "vm $USER has power state off"
fi' > /home/fence/$VM/bin/power

# ------------------------- dummy ----------------------------
echo '#!/bin/bash
exit 0
' > /home/fence/$VM/bin/SMCLP

echo "# .profile
PS1='MP> '
export LANG=en_US.UTF-8
export PATH=$PATH:\$HOME/bin
export ESX='root@$ESX'
"  > /home/fence/$VM/.profile

chown $VM.fence /home/fence/$VM/.bashrc /home/fence/$VM/bin/*
chmod 750 /home/fence/$VM/bin/* /home/fence/$VM/.???*

IF=$(ip r | grep default | awk '{print $5}')
IP=$(ip addr show $IF | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

echo "
FENCE USER CREATED, CONFGURE ILO FENCING WITH THIS CREDENTIALS
---------------------------------------------------------------
Fence Type: ilo_ssh
IP: $IP
User: $VM
Password: $PW

finished
"

##########################################################################################################
