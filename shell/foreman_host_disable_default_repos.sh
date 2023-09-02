#!/bin/bash
# DESC: disable all dnf repos that are not owned by subscription-manager
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

disable_repos() {
    for repo_file in /etc/yum.repos.d/*.repo; do
        if [ -f "$repo_file" ]; then
            package_name=$(rpm -qf "$repo_file")
            
            if [ -z "$package_name" ]; then
                mv "$repo_file" "$repo_file.disabled"
            elif ! rpm -q "$package_name" >/dev/null; then
                mv "$repo_file" "$repo_file.disabled"
            else
                while read -r line; do
                    if [[ $line =~ ^\[.*\]$ ]]; then
                        repo_name=${line:1:-1}
                        grep -q "^\[$repo_name\]" "$repo_file" && sed -i "/^\[$repo_name\]/,/^\[/ s/^enabled=.*/enabled=0/" "$repo_file"
                    fi
                done < "$repo_file"
            fi
        fi
    done
}

disable_repos

