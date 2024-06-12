#!/bin/bash
# DESC: lookup local user in /etc/passwd and report successful logins 25h back
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Define a variable for excluded logins as regex
EXCLUDE_LOGINS='^hostname1:^user1$:^1.2.3.4$
^hostname2:^user2$:^1.2.3.4$'

id | grep -q 'uid=0' || echo "ERROR: This script must run with root user"
id | grep -q 'uid=0' || exit 1

# Define a function to extract users with login shells from /etc/passwd
extract_login_users() {
    awk -F':' '$7~/bash|sh$/ {print $1}' /etc/passwd
    return $logins_found
}

# Function to check for user logins via SSH in the last 25 hours and extract source IP
check_user_logins() {
    local user=$1
    local logins=()
    logins_found=0
    # Determine if the system uses journalctl (systemd) or /var/log/auth.log (syslog)
    if command -v journalctl &> /dev/null; then
        # RHEL-ish systems with journalctl
        logins=$(journalctl --since "25 hours ago" | grep -E "sshd.*Accepted .* for $user ")
    elif [ -f /var/log/auth.log ]; then
        # Ubuntu systems with /var/log/auth.log
        logins=$(grep -E "sshd.*Accepted .* for $user " /var/log/auth.log --since="25 hours ago")
    else
        echo "Unsupported logging system."
        exit 2
    fi


    if [ -n "$logins" ]; then
        echo "$logins" | while read -r login; do
            local src_ip=$(echo "$login" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if ! is_excluded_login "$user" "$src_ip"; then
                echo "Login detected for user: $user from IP: $src_ip"
                return 1
            else
                echo "Excluded login detected for user: $user from IP: $src_ip"
                return 0
            fi
        done
    fi
}

# Function to check if a login should be excluded
is_excluded_login() {
    local user=$1
    local src_ip=$2
    local hostname=$(hostname)
    while IFS=: read -r ex_hostname ex_user ex_ip; do 
        if [[ "$hostname" =~ $ex_hostname ]] && \
           [[ "$user" =~ $ex_user ]] && \
           [[ "$src_ip" =~ $ex_ip ]]; then
            return 0 # Excluded login
        fi
    done <<< "$EXCLUDE_LOGINS"

    return 1 # Not an excluded login
}

# MAIN PROGRAM IS STARTING HERE
declare -g logins_found=0
declare -g logins_found_at_all=0
login_users=$(extract_login_users)

for user in $login_users; do
    if ! check_user_logins "$user"; then
        logins_found_at_all=1
    fi
    echo -n
done


if [ $logins_found_at_all -gt 0 ]; then
    echo "Logins found for one or more users in the last 25 hours."
    exit 1
else
    echo "No unwanted logins found for the checked users in the last 25 hours. All good."
    exit 0
fi

