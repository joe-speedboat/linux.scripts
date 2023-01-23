#!/bin/bash
#########################################################################################
# DESC: create some modified cloud images for my needs
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

IDIR=/srv/cloudomat
PASSWORD=Never.Eat.Yellow.Snow.
MEM=2048

RURL=https://cloud.centos.org/centos/8/x86_64/images
RIMG=CentOS-8-GenericCloud-8.3.2011-20201204.2.x86_64.qcow2
LIMG=thinlinc-$RIMG
HNAME=$(echo $LIMG | rev | cut -d- -f2- | rev)
DISK_SIZE=40g

test -f $IDIR/$LIMG
if [ $? -ne 0 ]
then
  wget -q $RURL/$RIMG -O $IDIR/$LIMG 

  qemu-img resize $IDIR/$LIMG $DISK_SIZE

  virt-customize -m $MEM -a $IDIR/$LIMG \
   --root-password password:"$PASSWORD" \
   --install git,nfs-utils,tmux,vim,wget,rsync,epel-release,lvm2,container-selinux,firewalld \
   --run-command \
     "dnf -y install rdesktop chromium firefox terminator ;\
     dnf -y install nmap nmap-ncat whois bind-utils vim-enhanced ;\
     dnf -y group install "Xfce" "base-x" ;\
     curl -L https://www.cendio.com/downloads/server/download.py --output /root/tl-server.zip ;\
     unzip /root/tl-server.zip ;\
     rm -f /root/tl-server.zip ;\
     rpm --import https://packages.microsoft.com/keys/microsoft.asc ;\
     echo -e '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc' > /etc/yum.repos.d/vscode.repo ;\
     dnf -y install code ;\
     echo $VM_NAME > /etc/hostname ;\
     curl https://raw.githubusercontent.com/joe-speedboat/shell.scripts/master/grow_cloud_rootfs_xfs.sh > /usr/local/sbin/grow_cloud_rootfs_xfs.sh ;\
     chmod 700 /usr/local/sbin/grow_cloud_rootfs_xfs.sh ;\
    echo '@reboot root /usr/local/sbin/grow_cloud_rootfs_xfs.sh' > /etc/cron.d/1growfs ;\
     sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config ;\
     dnf -y remove cloud-init* cockpit* ;\
     rm -rfv /etc/cloud" \
   --selinux-relabel

fi