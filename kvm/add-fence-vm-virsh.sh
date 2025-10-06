#!/bin/bash
#########################################################################################
# DESC: emulate ilo_ssh device on /usr/bin/virsh kvm host to emulate real iLo fencing on nested VMs
# tested with CentOS 7.5 on oVirt 4.2
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
#
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# HOWTO INSTALL #######################################
# add-fence-vm.sh [ov-node] [password]
#    eg: add-fence-vm.sh ov-compute1 redhat

export LANG=en
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

if [ $# -ne 2 ]
then
   echo "desc: create vm user for ilo fence emulation on /usr/bin/virsh (nested vm tests)"
   echo "usage: $(basename $0) <vm-name> <fence-password>"
   exit 1
else
   VM="$1"
   PW="$2"

   /usr/bin/virsh dominfo $1 >/dev/null 2>&1 
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

getent group fence >/dev/null 2>&1 
if [ $? -ne 0 ]
then
   echo INFO create fencing group: fence
   groupadd fence
fi

useradd -m -c "ILO FENCE USER" -g fence $VM
echo -e "$PW\n$PW" | passwd $VM

test -d /home/$VM/bin || mkdir -p /home/$VM/bin

# ---------------------------- START VM ----------------------
echo '#!/bin/bash
export LANG=en

sudo /usr/bin/virsh start $USER 2>/dev/null
logger -t fence-vm "vm $USER is powered on"
' > /home/$VM/bin/start

# ----------------------------- STATUS VM ---------------------
echo ' #!/bin/bash

sudo /usr/bin/virsh dominfo $USER 2>/dev/null | grep State: | grep -q running
if [ $? -eq 0 ]
then
   echo EnabledState=enabled
   logger -t fence-vm "vm $USER has power state on"
else
   echo EnabledState=disabled
   logger -t fence-vm "vm $USER has power state off"
fi
' > /home/$VM/bin/show

# ---------------------------- STOP VM -----------------------
echo '#!/bin/bash
export LANG=en

sudo /usr/bin/virsh destroy $USER
logger -t fence-vm "vm $USER is powered off"
' > /home/$VM/bin/power

# ------------------------- dummy ----------------------------
echo '#!/bin/bash
exit 0
' > /home/$VM/bin/SMCLP

# ------------------------- sudoers ----------------------------
#echo "$VM        ALL=       NOPASSWD: /usr/bin/virsh" >> /etc/sudoers
echo "# sudoers file for fencing simulation
$VM ALL=(ALL) NOPASSWD: /usr/bin/virsh destroy $VM, /usr/bin/virsh dominfo $VM, /usr/bin/virsh start $VM
"

echo '# .bashrc
PS1="MP> "
export LANG=en_US.UTF-8
export PATH=$PATH:$HOME/bin
'  > /home/$VM/.bashrc

chown $VM.fence /home/$VM/.bashrc /home/$VM/bin/*
chmod 755 /home/$VM/bin/*


IF=$(ip r | grep default | awk '{print $5}')
IP=$(ip addr show $IF | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

restorecon -FR /etc/ /home/ /usr/local

echo "
FENCE USER CREATED, CONFGURE ILO FENCING WITH THIS CREDENTIALS
---------------------------------------------------------------
Fence Type: ilo_ssh
IP: $IP
User: $VM
Password: $PW

You can add it to pacemaker cluster with:
pcs stonith create stonith-nfs1a fence_ilo_ssh ip="$IP" username="$VM" password="$PW" pcmk_host_map="$VM.domain.tld:$VM.domain.tld" ssh=true

finished
"


