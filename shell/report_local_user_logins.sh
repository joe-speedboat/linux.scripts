#!/bin/bash
# DESC: lookup local user in /etc/passwd and report successful logins 25h back
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# print debug statements
DEBUG=0

# Define a variable for excluded logins
EXCLUDE_LOGINS='hostname1:user1:1.2.3.4
hostname2:user2:1.2.3..*'

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
    [ $DEBUG -ne 0 ] && echo "------ Checking user logins for user: $user"
    logins_found=0
    # Determine if the system uses journalctl (systemd) or /var/log/auth.log (syslog)
    if command -v journalctl &> /dev/null; then
        # RHEL-ish systems with journalctl
        [ $DEBUG -ne 0 ] && echo "------ Using journalctl to check logins for user: $user"
        logins=$(journalctl --since "25 hours ago" | grep -E "sshd.*Accepted .* for $user ")
    elif [ -f /var/log/auth.log ]; then
        # Ubuntu systems with /var/log/auth.log
        [ $DEBUG -ne 0 ] && echo "------ Using /var/log/auth.log to check logins for user: $user"
        logins=$(grep -E "sshd.*Accepted .* for $user " /var/log/auth.log --since="25 hours ago")
    else
        echo "Unsupported logging system."
        exit 2
    fi


    if [ -n "$logins" ]; then
        echo "$logins" | while read -r login; do
            local src_ip=$(echo "$login" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            [ $DEBUG -ne 0 ] && echo "Checking if login for user: $user from IP: $src_ip is excluded"
            if ! is_excluded_login "$user" "$src_ip"; then
                [ $DEBUG -ne 0 ] && echo "Login for user: $user from IP: $src_ip is not excluded"
                echo "Login detected for user: $user from IP: $src_ip"
                ((logins_found++))
                logins_found=1
                [ $DEBUG -ne 0 ] && echo "Value of logins_found after setting: $logins_found"
            else
                echo "Excluded login detected for user: $user from IP: $src_ip"
            fi
        done
    fi
    if [[ $logins_found -gt 0 ]]; then
        logins_found=1
        [ $DEBUG -ne 0 ] && echo "Value of logins_found after setting: $logins_found"
    else
        [ $DEBUG -ne 0 ] && echo "------ No login found for user: $user"
    fi
}

# Function to check if a login should be excluded
is_excluded_login() {
    local user=$1
    local src_ip=$2
    local hostname=$(hostname)
    [ $DEBUG -ne 0 ] && echo "Checking exclusions for user: $user, hostname: $hostname, source IP: $src_ip"
    while IFS=: read -r ex_hostname ex_user ex_ip; do 
        [ $DEBUG -ne 0 ] && echo "Comparing with ex_hostname: $ex_hostname, ex_user: $ex_user, ex_ip: $ex_ip"
        if [[ "$hostname" == "$ex_hostname" || "$ex_hostname" == "*" ]] && \
           [[ "$user" == "$ex_user" || "$ex_user" == "*" ]] && \
           [[ "$src_ip" == "$ex_ip" || "$ex_ip" == "*" ]]; then
           [ $DEBUG -ne 0 ] && echo "Match found. Excluding login for user: $user from IP: $src_ip"
            return 0 # Excluded login
        fi
    done <<< "$EXCLUDE_LOGINS"

    [ $DEBUG -ne 0 ] && echo "No match found. Not excluding login for user: $user from IP: $src_ip"
    return 1 # Not an excluded login
}

# MAIN PROGRAM IS STARTING HERE
declare -g logins_found=0
declare -g logins_found_at_all=0
login_users=$(extract_login_users)

for user in $login_users; do
    [ $DEBUG -ne 0 ] && echo "--- function check_user_logins $user / logins_found_at_all=$logins_found_at_all"
    if check_user_logins "$user"; then
        logins_found_at_all=1
    fi
    [ $DEBUG -ne 0 ] && echo "Value of logins_found_at_all after checking user $user: $logins_found_at_all"
done

[ $DEBUG -ne 0 ] && echo "Final value of logins_found_at_all: $logins_found_at_all"

if [ $logins_found_at_all -eq 1 ]; then
    echo "Logins found for one or more users in the last 25 hours."
    exit 1
else
    echo "No logins found for the checked users in the last 25 hours. All good."
    exit 0
fi

