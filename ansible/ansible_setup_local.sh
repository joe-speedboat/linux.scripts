#!/bin/bash
#DESC: Setup and configure Ansible control node
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#!/bin/bash

# Define variables
ANSIBLE_HOME="/opt/ansible"
ANSIBLE_VERSION="11.1.0"
PYTHON_VERSION="3.12"
ANSIBLE_VENV_PATH="${ANSIBLE_HOME}/apps/${ANSIBLE_VERSION}"
PROFILE_SCRIPT="/etc/profile.d/ansible.sh"
UMASK="0007"

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

# Ensure its an rpm based system
grep -q 'platform:el9' /etc/os-release
if [[ $? -ne 0 ]]; then
   echo "This is only for RHEL9 like systems"
   exit 1
fi

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install required dependencies
echo "Installing required packages..."
dnf install -y curl wget vim git gnupg python3 python3-pip rsync sshpass unzip zip jq bash-completion

# Ensure ansible group exists
if ! getent group ansible > /dev/null; then
    echo "Creating ansible group..."
    groupadd ansible
fi

# Add specific users to ansible group if they exist
for user in root ansible rundeck semaphore; do
    if id "$user" &>/dev/null; then
        echo "Adding $user to ansible group..."
        usermod -aG ansible "$user"
    fi
done

# Ensure required directories exist
echo "Initializing Ansible home directory: $ANSIBLE_HOME"
mkdir -p "${ANSIBLE_HOME}/apps"
mkdir -p "${ANSIBLE_HOME}/inventory"
mkdir -p "${ANSIBLE_HOME}/logs"
mkdir -p "${ANSIBLE_HOME}/playbooks"
mkdir -p "${ANSIBLE_HOME}/projects"

# Install Python 3.12 if not available
echo "Checking and installing Python ${PYTHON_VERSION}..."
dnf install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip

# Set default Python for virtual environment
PYTHON_BIN="/usr/bin/python${PYTHON_VERSION}"

# Check Python installation
if ! command -v "$PYTHON_BIN" &> /dev/null; then
    echo "Python ${PYTHON_VERSION} installation failed!"
    exit 1
fi

# Create Python Virtual Environment
echo "Creating virtual environment for Ansible $ANSIBLE_VERSION at $ANSIBLE_VENV_PATH..."
python${PYTHON_VERSION} -m venv "$ANSIBLE_VENV_PATH"

# Activate Virtual Environment
echo "Activating virtual environment..."
source "$ANSIBLE_VENV_PATH/bin/activate"

# Upgrade pip and install Ansible
echo "Upgrading pip and installing Ansible $ANSIBLE_VERSION..."
pip install --upgrade pip
pip install ansible=="$ANSIBLE_VERSION" argcomplete

# Enable Ansible Autocomplete (official method)
echo "Setting up Ansible autocomplete..."
activate-global-python-argcomplete --dest /etc/bash_completion.d

# Generate ansible.cfg template with all options disabled
echo "Generating Ansible configuration template..."
ansible-config init --disabled -t all > ${ANSIBLE_HOME}/ansible.cfg

# Apply best practice modifications
echo "Applying best practices to ansible.cfg..."
sed -i 's|^;inventory=.*|inventory='"${ANSIBLE_HOME}/inventory"'|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;roles_path=.*|roles_path='"${ANSIBLE_HOME}/roles"'|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;log_path=.*|log_path='"${ANSIBLE_HOME}/logs/ansible.log"'|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;host_key_checking=.*|host_key_checking=False|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;retry_files_enabled=.*|retry_files_enabled=False|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;stdout_callback=.*|stdout_callback=yaml|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;deprecation_warnings=.*|deprecation_warnings=False|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;interpreter_python=.*|interpreter_python=auto_silent|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;pipelining=.*|pipelining=True|' ${ANSIBLE_HOME}/ansible.cfg
sed -i 's|^;forks=.*|forks = 20|' ${ANSIBLE_HOME}/ansible.cfg

# Set up inventory
echo "Setting up Ansible inventory..."
echo 'localhost ansible_connection=local ansible_become=False' > ${ANSIBLE_HOME}/inventory/localhost

# Set up auto-activation in /etc/profile.d/
echo "Setting up Ansible virtual environment auto-activation for all users..."
cat <<EOF > $PROFILE_SCRIPT
#!/bin/bash
# Ansible virtual ENV settings, configured by http://ansible.bitbull.ch
export ANSIBLE_VERSION="$ANSIBLE_VERSION" # taken from setup
export ANSIBLE_HOME="$ANSIBLE_HOME"

# Source user-defined settings, if available
if [[ -r "\$HOME/.ansible.sh" ]]; then
    source "\$HOME/.ansible.sh"
fi

# \$HOME/.ansible.sh # example to override as user
# -------------------------------------------------
# export ANSIBLE_VERSION="11.0.0"
# export ANSIBLE_HOME="/opt/ansible_old"
# -------------------------------------------------

export ANSIBLE_VENV_PATH="\${ANSIBLE_HOME}/apps/\${ANSIBLE_VERSION}"
export VIRTUAL_ENV=\$ANSIBLE_VENV_PATH
export VIRTUAL_ENV_DISABLE_PROMPT=1

# useful ansible aliases
alias cda='cd \$ANSIBLE_HOME'
alias via='ansible-vault edit'

# Activate virtual environment if it exists
if [ -d "\$ANSIBLE_VENV_PATH" ]; then
    test -r "\$ANSIBLE_VENV_PATH/bin/activate" && source "\$ANSIBLE_VENV_PATH/bin/activate"
fi

umask $UMASK

export PS1="(\$ANSIBLE_VERSION)[\u@\h \W]\\\$ "
EOF
chmod +x $PROFILE_SCRIPT

test -e /etc/vimrc.local
if [ $? -ne 0 ]
then
# Optimize VIM settings for ansible
echo "Optimizing VIM ansible settings in /etc/vimrc.local for all users..."
echo 'syntax on
set cursorline
set cursorcolumn
set title
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
autocmd fileType yaml setlocal ai
' > /etc/vimrc.local
chmod +r /etc/vimrc.local
fi

# Set ownership, permissions, and enforce group ownership
echo "Setting correct permissions on $ANSIBLE_HOME..."
chown -R root:ansible "$ANSIBLE_HOME"
chmod -R ug+rwX,o-rwx "$ANSIBLE_HOME"

# Apply group sticky bit recursively on directories
find "$ANSIBLE_HOME" -type d -exec chmod g+s {} +

# Create /etc/ansible symlink if it does not exist
if [ ! -e /etc/ansible ]; then
    echo "Creating symlink: /etc/ansible → $ANSIBLE_HOME"
    ln -s "$ANSIBLE_HOME" /etc/ansible
fi

# Deactivate Virtual Environment
deactivate

echo "
Installation completed successfully. Ansible is now set up and ready to use!

Aliases:
  via -> ansible-vault edit
  cda -> cd \$ANSIBLE_HOME

Profile (enable venv at startup): /etc/profile.d/ansible.sh
Note, you can override choosen env by creating user config in 
\$HOME/.ansible.sh
-----------------------------------
export ANSIBLE_VERSION="11.0.0"
export ANSIBLE_HOME="/opt/ansible"
-----------------------------------

VIM config: /etc/vimrc.local

Application base directory(venv): $ANSIBLE_HOME/apps/

Ansible home dir: $ANSIBLE_HOME
Ansible configured version: $ANSIBLE_VERSION

To start using Ansible, log out and log back in or run:
source /etc/profile.d/ansible.sh
"

