#!/usr/bin/env python3
##############################################################################################################
# DESC: Pull ansible host and group inventory from freeipa via api
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

import os
import time
import json
import requests
import argparse

# Cache settings
cache_time_sec = 30
cache_file = os.path.expanduser("~/.ansible_freeipa.cache")

# FreeIPA settings are taken from system env vars
IPA_SERVER = os.getenv("freeipaserver")
USERNAME = os.getenv("freeipauser")
PASSWORD = os.getenv("freeipapassword")

if not IPA_SERVER or not USERNAME or not PASSWORD:
    print("Error: Please set the environment variables freeipaserver, freeipauser, and freeipapassword.")
    exit(1)

IPA_URL = f"https://{IPA_SERVER}/ipa/session/json"

# Disable SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings()


def get_session():
    """Authenticate with FreeIPA and return a session object."""
    session = requests.Session()
    login_url = f"https://{IPA_SERVER}/ipa/session/login_password"
    headers = {
        "Referer": f"https://{IPA_SERVER}/ipa",
        "Content-Type": "application/x-www-form-urlencoded",
    }
    data = {"user": USERNAME, "password": PASSWORD}

    response = session.post(login_url, headers=headers, data=data, verify=False)
    if response.status_code != 200:
        print("Failed to authenticate with FreeIPA. Check credentials.")
        exit(1)
    return session


def get_hostgroups(session):
    """Fetch all host groups from FreeIPA."""
    data = {"method": "hostgroup_find", "params": [[], {}]}
    headers = {"Content-Type": "application/json", "Referer": f"https://{IPA_SERVER}/ipa"}

    response = session.post(IPA_URL, json=data, headers=headers, verify=False)
    if response.status_code != 200:
        print("Failed to fetch host groups.")
        exit(1)

    return response.json().get("result", {}).get("result", [])


def get_hosts_in_group(session, group_name):
    """Fetch hosts associated with a specific host group, including nested groups."""
    data = {"method": "hostgroup_show", "params": [[group_name], {}]}
    headers = {"Content-Type": "application/json", "Referer": f"https://{IPA_SERVER}/ipa"}

    response = session.post(IPA_URL, json=data, headers=headers, verify=False)
    if response.status_code != 200:
        return []

    result = response.json().get("result", {}).get("result", {})
    hosts = result.get("member_host", [])
    nested_groups = result.get("member_hostgroup", [])

    # Recursively fetch hosts from nested groups
    for nested_group in nested_groups:
        hosts.extend(get_hosts_in_group(session, nested_group))

    return hosts


def get_all_hosts(session):
    """Fetch all hosts from FreeIPA."""
    data = {"method": "host_find", "params": [[], {}]}
    headers = {"Content-Type": "application/json", "Referer": f"https://{IPA_SERVER}/ipa"}

    response = session.post(IPA_URL, json=data, headers=headers, verify=False)
    if response.status_code != 200:
        print("Failed to fetch hosts.")
        exit(1)

    return response.json().get("result", {}).get("result", [])

def generate_ansible_inventory():
    """Generate an Ansible dynamic inventory from FreeIPA."""
    # Check if cache is valid
    if os.path.exists(cache_file):
        cache_mtime = os.path.getmtime(cache_file)
        if time.time() - cache_mtime < cache_time_sec:
            with open(cache_file, 'r') as f:
                print(f.read())
            return

    # Generate inventory and update cache
    session = get_session()
    all_hosts = get_all_hosts(session)
    hostgroups = get_hostgroups(session)

    inventory = {"_meta": {"hostvars": {}}}

    for group in hostgroups:
        group_name = group["cn"][0]
        hosts = get_hosts_in_group(session, group_name)

        inventory[group_name] = {"hosts": hosts}

    # Track hosts that are part of any group
    grouped_hosts = set()

    for group in hostgroups:
        group_name = group["cn"][0]
        hosts = get_hosts_in_group(session, group_name)

        if hosts:
            inventory[group_name] = {"hosts": hosts}
            grouped_hosts.update(hosts)

    # Add ungrouped hosts
    ungrouped_hosts = [host["fqdn"][0] for host in all_hosts if host["fqdn"][0] not in grouped_hosts]
    if ungrouped_hosts:
        inventory["ungrouped"] = {"hosts": ungrouped_hosts}

    inventory_json = json.dumps(inventory, indent=4)
    with open(cache_file, 'w') as f:
        f.write(inventory_json)
    print(inventory_json)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="Output inventory")
    args = parser.parse_args()

    if args.list:
        generate_ansible_inventory()
    else:
        print(json.dumps({}))

