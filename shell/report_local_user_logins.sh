#!/bin/bash
# DESC: lookup local user in /etc/passwd and report successful logins 25h back
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
# Define a function to extract users with login shells from /etc/passwd

id | grep -q 'uid=0' || echo "ERROR: This script must run with root user"
id | grep -q 'uid=0' || exit 1

extract_login_users() {
    awk -F':' '$7~/bash|sh$/ {print $1}' /etc/passwd
}

# Function to check for user logins via SSH in the last 25 hours
check_user_logins() {
    local user=$1
    # Determine if the system uses journalctl (systemd) or /var/log/auth.log (syslog)
    if command -v journalctl &> /dev/null; then
        # RHEL-ish systems with journalctl
        if journalctl --since "25 hours ago" | grep -E "sshd.*Accepted .* for $user "; then
            return 0 # Login found
        fi
    elif [ -f /var/log/auth.log ]; then
        # Ubuntu systems with /var/log/auth.log
        if grep -E "sshd.*Accepted .* for $user " /var/log/auth.log --since="25 hours ago"; then
            return 0 # Login found
        fi
    else
        echo "Unsupported logging system."
        exit 2
    fi
    return 1 # No login found
}

# Main script logic
login_users=$(extract_login_users)
logins_found=0

for user in $login_users; do
    if check_user_logins "$user"; then
        echo "Login detected for user: $user"
        logins_found=1
    fi
done

if [ "$logins_found" -eq 1 ]; then
    echo "Logins found for one or more users in the last 25 hours."
    exit 1
else
    echo "No logins found for the checked users in the last 25 hours. All good."
    exit 0
fi

