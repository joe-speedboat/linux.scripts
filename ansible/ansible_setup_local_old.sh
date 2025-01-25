#!/bin/bash
#DESC: Setup and configure Ansible control node
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

if [ "$USER" != "root" ]
then
  echo ERROR: User is not root, we setup as root
  exit 1
fi

test -f /etc/os-release
if [ $? -ne 0 ]
then
  echo "ERROR: /etc/os-release missing"
  exit 1
fi

source /etc/os-release
echo "INFO: determine OS type now"
case "$ID" in 
  centos|almalinux|rocky)
    os_type="rel_clone"
    ;;
  rhel)
    os_type="rel"
    ;;
esac

echo "INFO: determine OS version now"
case "$VERSION_ID" in 
  7*)
    os_ver=7
    ;;
  8*)
    os_ver=8
    ;;
  9*)
    os_ver=9
    ;;
esac

echo "DEBUG: os_type=$os_type os_ver=$os_ver"

if [ "$os_type$os_ver" == "rel_clone7"  ] #########################################################
then
  for PKG in epel-release git wget curl ansible
  do
     rpm -q $PKG >/dev/null 2>&1 && echo $PKG is already installed || yum -y install $PKG
  done
  ansibleconfigfile="/etc/ansible/ansible.cfg"
  sed -i 's|^#inventory .*|inventory      = /etc/ansible/hosts|g' $ANSIBLE_CONFIG
  sed -i 's|^#roles_path .*|roles_path    = /etc/ansible/roles|g' $ANSIBLE_CONFIG
  sed -i 's|^#remote_user .*|remote_user = root|g' $ANSIBLE_CONFIG
  sed -i 's|^#nocows .*|nocows = 1|g' $ANSIBLE_CONFIG
  sed -i "/^roles_path/a\ \n#additional paths to search for collections in, colon separated\ncollections_paths = /etc/ansible/collections" $ANSIBLE_CONFIG
  test -d /etc/ansible/projects || mkdir /etc/ansible/projects ; chmod 700 /etc/ansible/projects
  test -d /etc/ansible/collections || mkdir /etc/ansible/collections ; chmod 755 /etc/ansible/collections
  ansible-galaxy search joe-speedboat | cat

elif [ "$os_type$os_ver" == "rel_clone8"  ] #########################################################
then
  dnf -y config-manager --set-enabled powertools
  for PKG in epel-release git wget curl ansible
  do
     rpm -q $PKG >/dev/null 2>&1 && echo $PKG is already installed || dnf -y install $PKG
  done
  ansibleconfigfile="/etc/ansible/ansible.cfg"
  sed -i 's|^#inventory .*|inventory      = /etc/ansible/hosts|g' $ANSIBLE_CONFIG
  sed -i 's|^#roles_path .*|roles_path    = /etc/ansible/roles|g' $ANSIBLE_CONFIG
  sed -i 's|^#remote_user .*|remote_user = root|g' $ANSIBLE_CONFIG
  sed -i 's|^#nocows .*|nocows = 1|g' $ANSIBLE_CONFIG
  sed -i "/^roles_path/a\ \n#additional paths to search for collections in, colon separated\ncollections_paths = /etc/ansible/collections" $ANSIBLE_CONFIG

  test -d /etc/ansible/projects || mkdir /etc/ansible/projects ; chmod 700 /etc/ansible/projects
  test -d /etc/ansible/playbooks || mkdir /etc/ansible/playbooks ; chmod 700 /etc/ansible/playbooks
  test -d /etc/ansible/collections || mkdir /etc/ansible/collections ; chmod 755 /etc/ansible/collections
  ansible-galaxy search joe-speedboat | cat

elif [ "$os_type$os_ver" == "rel8"  ] #########################################################
then
  yes | subscription-manager register | grep -q 'system is already registered'
  if [ $? -ne 0 ]
  then
    echo "ERROR: System is not registered in RHN"
    exit 1
  fi
  subscription-manager repos --enable ansible-2.8-for-rhel-8-x86_64-rpms
  for PKG in git wget curl ansible
  do
     rpm -q $PKG >/dev/null 2>&1 && echo $PKG is already installed || dnf -y install $PKG
  done
  ansibleconfigfile="/etc/ansible/ansible.cfg"
  sed -i 's|^#inventory .*|inventory      = /etc/ansible/hosts|g' $ANSIBLE_CONFIG
  sed -i 's|^#roles_path .*|roles_path    = /etc/ansible/roles|g' $ANSIBLE_CONFIG
  sed -i 's|^#remote_user .*|remote_user = root|g' $ANSIBLE_CONFIG
  sed -i 's|^#nocows .*|nocows = 1|g' $ANSIBLE_CONFIG
  sed -i "/^roles_path/a\ \n#additional paths to search for collections in, colon separated\ncollections_paths = /etc/ansible/collections" $ANSIBLE_CONFIG

  test -d /etc/ansible/projects || mkdir /etc/ansible/projects ; chmod 700 /etc/ansible/projects
  test -d /etc/ansible/playbooks || mkdir /etc/ansible/playbooks ; chmod 700 /etc/ansible/playbooks
  test -d /etc/ansible/collections || mkdir /etc/ansible/collections ; chmod 755 /etc/ansible/collections
  ansible-galaxy search joe-speedboat | cat

elif [ "$os_type$os_ver" == "rel9"  ] #########################################################
then
  subscription-manager repos --enable=$(dnf repolist --all | awk '{print $1}' | grep -i codeready | grep $(echo $VERSION |cut -d. -f1)-$(arch)-rpms | tail -1)
  for PKG in git wget curl ansible-core
  do
     rpm -q $PKG >/dev/null 2>&1 && echo $PKG is already installed || dnf -y install $PKG
  done
  ansibleconfigfile="/etc/ansible/ansible.cfg"
  test -d /etc/ansible || mkdir /etc/ansible ; chmod 755 /etc/ansible
  test -d /etc/ansible/projects || mkdir /etc/ansible/projects ; chmod 700 /etc/ansible/projects
  test -d /etc/ansible/playbooks || mkdir /etc/ansible/playbooks ; chmod 700 /etc/ansible/playbooks
  test -d /etc/ansible/collections || mkdir /etc/ansible/collections ; chmod 755 /etc/ansible/collections
  test -f $ANSIBLE_CONFIG && cp -anv $ANSIBLE_CONFIG $ANSIBLE_CONFIG.bak
  ansible-config init --disabled -t all | sed -e 's|{{ ANSIBLE_HOME ~ "/|/etc/ansible/|g' -e 's|" }}||g' > $ANSIBLE_CONFIG
  sed -i 's|^;inventory=|inventory=|' $ANSIBLE_CONFIG
  sed -i 's|^;roles_path=|roles_path=|' $ANSIBLE_CONFIG
  sed -i 's|^;collections_path=|collections_path=|' $ANSIBLE_CONFIG
  sed -i 's|^;nocows=.*|nocows=True|' $ANSIBLE_CONFIG
  test -f /etc/ansible/hosts || echo localhost > /etc/ansible/hosts
  ansible-galaxy search joe-speedboat | cat

elif [ "$os_type$os_ver" == "rel_clone9"  ] #########################################################
then
  if getent passwd rundeck >/dev/null 2>&1 
  then
    export ANSIBLE_USER=rundeck
    echo "INFO: found user $ANSIBLE_USER, I will use this user for ansible setup"
  elif getent passwd ansible >/dev/null 2>&1
  then
    export ANSIBLE_USER=ansible
    echo "INFO: found user $ANSIBLE_USER, I will use this user for ansible setup"
  else
    export ANSIBLE_USER=root
    echo 
    echo "WARNING: no valid ansible user, will install as root into system binaries"
    echo "         User rundeck or ansible would be best practice, you have 15s to quit with CTRL-C before setup is starting"
    echo 
    sleep 15
  fi
  
  AV=2.18 # ansible version
  PV=3.12 # python version
  PKG="git wget curl python${PV} python${PV}-pip"
  echo INFO: Installing $PKG
  dnf -y install $PKG || exit 1

  echo INFO: Installing Ansible as user $ANSIBLE_USER
  su -s /bin/bash -c "python${PV} -m pip install --user ansible-core==$AV" $ANSIBLE_USER

  echo INFO: Test Ansible as user $ANSIBLE_USER
  su -s /bin/bash -c "~/.local/bin/ansible --version" $ANSIBLE_USER

  # write ansible config and prepare dev env
  ANSIBLE_CONFIG=/etc/ansible/ansible.cfg
  ANSIBLE_HOME=$(dirname $ANSIBLE_CONFIG)
  ANSIBLE_USER_HOME=$(getent passwd "$ANSIBLE_USER" | cut -d: -f6)
  grep -q ANSIBLE_HOME $ANSIBLE_USER_HOME/.bashrc || echo "export ANSIBLE_HOME=$ANSIBLE_HOME" >> $ANSIBLE_USER_HOME/.bashrc
  grep -q ANSIBLE_CONFIG $ANSIBLE_USER_HOME/.bashrc || echo "export ANSIBLE_CONFIG=$ANSIBLE_CONFIG" >> $ANSIBLE_USER_HOME/.bashrc

  # create project dirs
  for d in $ANSIBLE_HOME $ANSIBLE_HOME/{inventory,projects,playbooks,tmp}
  do
    test -d $d || ( mkdir -p $d ; chmod 770 $d ; chown root:$ANSIBLE_USER $d )
  done

  # backup config, if exist
  test -f $ANSIBLE_CONFIG && cp -anv $ANSIBLE_CONFIG $ANSIBLE_CONFIG.$(date +%Y%m%d%H%M)

  # create fresh config
  su -s /bin/bash -c "~/.local/bin/ansible-config init --disabled -t all" $ANSIBLE_USER > $ANSIBLE_CONFIG

  # comment in all $ANSIBLE_HOME relevant values
  sed -i 's|^;\(.*=.*/etc/.*\)|\1|' $ANSIBLE_CONFIG

  # clean up roles_path
  sed -i "s|^roles_path=.*|roles_path=$ANSIBLE_HOME/roles:/usr/share/ansible/roles|" $ANSIBLE_CONFIG

  # comment in and configure inventory
  sed -i 's|^;inventory=|inventory=|' $ANSIBLE_CONFIG
  sed -i 's|^inventory=.*|inventory=/etc/ansible/inventory|' $ANSIBLE_CONFIG
  test -f /etc/ansible/inventory/localhost || echo echo 'localhost ansible_connection=local ansible_become=False' > /etc/ansible/inventory/localhost

  # check that are no more dupes
  grep '/etc/ansible/.*/etc/ansible/' $ANSIBLE_CONFIG && echo "ERROR: remove this dupes first in $ANSIBLE_CONFIG"
  grep '/etc/ansible/.*/etc/ansible/' $ANSIBLE_CONFIG && exit 1

  su -s /bin/bash -c "~/.local/bin/ansible-galaxy search joe-speedboat | cat" $ANSIBLE_USER 
  su -s /bin/bash -c "~/.local/bin/ansible-galaxy install joe-speedboat.os_update" $ANSIBLE_USER 

  # move perms to $ANSIBLE_USER
  chown -R $ANSIBLE_USER $ANSIBLE_HOME

else
  echo "WARNING: No supported operating system found: os_type=$os_type os_ver=$os_ver"
fi
echo done
