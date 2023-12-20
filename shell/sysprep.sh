#!/bin/bash
# DESC: cleanup system before cloning
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Function to clean common directories and files
function clean_common {
    echo "Cleaning common directories and files..."

    # Remove log files
    find /var/log -type f -delete

    # Remove ssh keys
    rm -rf /etc/ssh/ssh_host_*

    # Remove bash histories
    rm -f /home/*/.bash_history
    rm -f /root/.bash_history

    # Remove Users Config
    rm -f /home/*/{.ssh,.local,.config}
    rm -f /root/{.ssh,.local,.config}

    # Clean up /tmp and /var/tmp directories
    rm -rf /tmp/*
    rm -rf /var/tmp/*

    # Remove all lines from /etc/hosts that do not contain 'localhost'
    sed -i '/localhost/!d' /etc/hosts
}

# Function to clean Ubuntu systems
function clean_ubuntu {
    echo "Cleaning Ubuntu system..."

    # Clean cache directories
    apt clean
}

# Function to clean RHEL-like systems
function clean_rhel {
    echo "Cleaning RHEL-like system..."

    # Clean cache directories
    dnf clean all

    # Remove packages that match the pattern 'iwl*'
    dnf -y remove iwl*

    # Touch /.autorelabel
    touch /.autorelabel
}

# Call the function to clean common directories and files
clean_common

# Detect the package manager and call the appropriate function
if command -v apt &> /dev/null; then
    clean_ubuntu
elif command -v dnf &> /dev/null; then
    clean_rhel
else
    echo "Unsupported package manager"
fi

