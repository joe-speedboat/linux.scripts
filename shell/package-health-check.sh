#!/bin/bash
# DESC: Package Health Report for Debian and Red Hat based System
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


# Ensure script is run as root
if [ "$EUID" -ne 0 ]
then 
  echo "You must run this script as root user"
  exit 1
fi

# Variables
uptime_max_d=90
uptime_report=ERROR
pkg_install_max_d=90
pkg_install_report=ERROR
repo_error_report=ERROR
package_without_repos_report=ERROR
public_repos_report=WARNING
reboot_required_report=WARNING
do_debug=0

# Log function
log(){
   LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   DATE=$(date +%Y.%m.%d_%H:%M)
   UNAME=$(uname -n | cut -d. -f1)
   #SCRIPT=$(basename $0)
   SCRIPT=package-health-check.sh
   if [ "$LEVEL" = "DEBUG" -a "$do_debug" -eq 1 ] ; then
      echo "$DATE $UNAME $SCRIPT:$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] ; then
      echo "$DATE $UNAME $SCRIPT:$LEVEL: $*"
      logger -t $SCRIPT "$LEVEL: $*"
   fi
   if [ "$LEVEL" = "ERROR" ]
   then
      exit 1
   fi
}

# Determine OS
myos(){
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ $ID_LIKE == *"debian"* ]]; then
      OS="Debian"
    elif [[ $ID_LIKE == *"rhel"* ]]; then
      OS="RHEL"
    elif [[ $ID == *"rhel"* ]]; then
      OS="RHEL"
    else
      OS=$NAME
    fi
  else
    OS=$(uname -s)
  fi
  echo $OS
}

log debug myos=$(myos)

# Ensure OS is either Debian or RHEL
OS=$(myos)
if [ "$OS" != "Debian" ] && [ "$OS" != "RHEL" ]
then 
  echo "This script can only be run on Debian or RHEL"
  exit 1
fi


# Check uptime
check_uptime(){
  log debug exec: check_uptime
  uptime_has_d=$(awk '{print int($1/86400)}' /proc/uptime)
  if [ $uptime_has_d -lt $uptime_max_d ]; then
    uptime_report=INFO
  fi
  log $uptime_report uptime_has_d=$uptime_has_d uptime_max_d=$uptime_max_d
}

# Check package install
check_pkg_install(){
  log debug exec: check_pkg_install
  if [ "$(myos)" == "Debian" ]; then
    pkg_install_last=$(date -d "$(stat -c %y /var/lib/dpkg/info/*.list 2> /dev/null | sort | tail -n1)" +%s)
  else
    pkg_install_last=$(date -d "$(rpm -qa --last | head -n1 | awk '{print $3,$4,$5,$6}')" +%s)
  fi
  pkg_install_last_d=$(( ( $(date +%s) - $pkg_install_last ) / 86400 ))
  if [ $pkg_install_last_d -lt $pkg_install_max_d ]; then
    pkg_install_report=INFO
  fi
  log $pkg_install_report pkg_install_last_d=$pkg_install_last_d pkg_install_max_d=$pkg_install_max_d pkg_install_last=$(date -d @$pkg_install_last "+%Y.%m.%d")
}

# Check repo error
check_repo_error(){
  log debug exec: check_repo_error
  if [ "$(myos)" == "Debian" ]; then
    apt-get clean >/dev/null 2>&1
      apt-get update 2>&1 | grep -e ^E: -e ^W: -e ^Err: -e ^Warn: && ERR=1 || ERR=0
  else
      yum clean all 2>&1 >/dev/null && yum makecache 2>&1 >/dev/null
    ERR=$?
  fi
  if [ $ERR -eq 0 ]; then
    repo_error_report=INFO
    log $repo_error_report all repos are reachable
  else
    log $repo_error_report some repos have errors
  fi
}

# Check package without repos
check_package_without_repos(){
  log debug exec: check_package_without_repos
  if [ "$(myos)" == "Debian" ]; then
    if ! dpkg -l | awk '{print $2}' | xargs apt-cache madison 2>&1 | grep -q 'No available version'; then
      package_without_repos_report=INFO
      log $package_without_repos_report all packages are depending on repos
    else
      log $package_without_repos_report some packages have no repos behind
    fi
  else
    if ! yum list $(rpm -qa --qf '%{NAME}\n' | grep -v gpg-pubkey | tr '\n' ' ') | grep '@System'; then
      package_without_repos_report=INFO
      log $package_without_repos_report all packages are depending on repos
    else
      log $package_without_repos_report some packages have no repos behind
    fi
  fi
}

check_public_repos() {
    log debug exec: check_public_repos
    local repo_urls
    local ip
    local public_ip_found=0

    if [ "$(myos)" == "Debian" ]; then
        repo_urls=$(cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list | grep -Eo "http[s]?://[^/]+")
    else
        repo_urls=$(cat /etc/yum.repos.d/*.repo | grep -Eo "http[s]?://[^/]+")
    fi

    for url in $repo_urls; do
        fqdn=$(echo $url | sed -e 's|^[^/]*//||' -e 's|/.*$||')
        ip=$(getent hosts $fqdn 2>&1 | cut -d' ' -f1 | head -n1)
        # log debug "Checking repo FQDN: $fqdn, resolved IP: $ip"
        if [ "x$ip" != "x" ] ; then
            if ! [[ $ip =~ ^(10|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168)\. ]]; then
                log debug "Public IP detected in repo: $url ($ip)"
                public_ip_found=1
            else
                log debug  "Private IP detected in repo: $url ($ip)"
            fi
        else
            log debug "Repo: $url has no ip, skipping"
        fi
    done

    if [ $public_ip_found -eq 0 ]; then
        public_repos_report=INFO
        log $public_repos_report "No public IPs detected in repos"
    else
        log $public_repos_report "Public IPs detected in repos"
    fi
}

check_reboot_required(){
  log debug exec: check_reboot_required
  if [ "$(myos)" == "Debian" ]; then
    if [ -f /var/run/reboot-required ]; then
      log $reboot_required_report system needs a reboot
    else
      reboot_required_report=INFO
      log $reboot_required_report system does not need a reboot
    fi
  elif [ "$(myos)" == "RHEL" ]; then
    if needs-restarting -r 2>&1 | grep 'Reboot is required' ; then
      log $reboot_required_report system needs a reboot
    else
      reboot_required_report=INFO
      log $reboot_required_report system does not need a reboot
    fi
  fi
}


# Run checks
check_uptime
check_pkg_install
check_repo_error
check_package_without_repos
check_public_repos
check_reboot_required
